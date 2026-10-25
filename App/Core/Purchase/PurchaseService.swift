import Foundation
import Combine
import StoreKit

enum PurchaseEvent { case begin, pending, cancelled, failed, unverified, entitlement(Bool), restored, notFound }
struct PurchaseState: Equatable {
    var unlocked = false
    var busy = false
    var messageKey: String?
    mutating func apply(_ event: PurchaseEvent) {
        busy = false
        switch event {
        case .begin: busy = true; messageKey = nil
        case .pending: messageKey = "purchase.pending"
        case .cancelled: messageKey = "purchase.cancelled"
        case .failed, .unverified: messageKey = "purchase.failed"
        case .entitlement(let active): unlocked = active
        case .restored: messageKey = "purchase.restored"
        case .notFound: messageKey = "purchase.notFound"
        }
    }
}

@MainActor final class PurchaseService: ObservableObject {
    @Published private(set) var state = PurchaseState()
    @Published private(set) var product: Product?
    @Published private(set) var loading = false
    private var updates: Task<Void, Never>?
    var unlocked: Bool { state.unlocked }
    var busy: Bool { state.busy }
    var message: String? { state.messageKey.map { NSLocalizedString($0, comment: "Purchase status") } }

    nonisolated static func isActive(id: String, nonConsumable: Bool, revoked: Bool) -> Bool {
        id == AppConfiguration.productID && nonConsumable && !revoked
    }
    private static func active(_ transaction: Transaction) -> Bool {
        isActive(id: transaction.productID, nonConsumable: transaction.productType == .nonConsumable,
                 revoked: transaction.revocationDate != nil || transaction.isUpgraded)
    }
    func start() async {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                if case .verified(let transaction) = result, transaction.productID == AppConfiguration.productID {
                    self?.state.unlocked = Self.active(transaction)
                    await transaction.finish()
                }
            }
        }
        await refreshEntitlements()
        await loadProduct()
    }
    func loadProduct() async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        do {
            product = try await Product.products(for: [AppConfiguration.productID]).first { $0.type == .nonConsumable }
            if product == nil { state.apply(.failed) }
        } catch { state.apply(.failed) }
    }
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, Self.active(transaction) { active = true }
        }
        // Preserve an operation's busy state while transactions update asynchronously.
        state.unlocked = active
    }
    /// The view supplies SwiftUI Environment.purchase to anchor StoreKit to its scene.
    /// Do not replace it with an unanchored Product.purchase() in UI code.
    func purchase(using action: @MainActor (Product) async throws -> Product.PurchaseResult) async {
        guard !busy else { return }
        state.apply(.begin)
        if product == nil { await loadProduct() }
        guard let product else { state.apply(.failed); return }
        do {
            switch try await action(product) {
            case .success(.verified(let transaction)):
                guard Self.active(transaction) else { state.apply(.failed); await refreshEntitlements(); return }
                state.apply(.entitlement(true))
                await transaction.finish()
            case .success(.unverified): state.apply(.unverified)
            case .pending: state.apply(.pending)
            case .userCancelled: state.apply(.cancelled)
            @unknown default: state.apply(.failed)
            }
        } catch {
            state.apply(Self.isCancellation(error) ? .cancelled : .failed)
        }
    }
    func restore() async {
        guard !busy else { return }
        state.apply(.begin)
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            state.apply(unlocked ? .restored : .notFound)
        } catch { state.apply(Self.isCancellation(error) ? .cancelled : .failed) }
    }
    private static func isCancellation(_ error: Error) -> Bool {
        var current: Error = error
        for _ in 0..<5 {
            if case StoreKitError.userCancelled = current { return true }
            if let sk = current as? SKError, sk.code == .paymentCancelled { return true }
            let ns = current as NSError
            if ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError { return true }
            if case StoreKitError.systemError(let underlying) = current { current = underlying }
            else if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error { current = underlying }
            else { return false }
        }
        return false
    }
    deinit { updates?.cancel() }
}
