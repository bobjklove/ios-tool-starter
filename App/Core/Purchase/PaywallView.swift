import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var purchases: PurchaseService
    @Environment(\.purchase) private var purchaseAction
    @Environment(\.dismiss) private var dismiss
    let onUnlocked: () -> Void
    private var messageKind: StatusBanner.Kind {
        switch purchases.state.messageKey {
        case "purchase.pending": .warning
        case "purchase.restored": .success
        case "purchase.failed", "purchase.cancelled", "purchase.notFound": .error
        default: .info
        }
    }
    var body: some View {
        NavigationStack {
            ScreenContainer {
                VStack(spacing: Tokens.spacing) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Tokens.accent)
                        .frame(width: 72, height: 72)
                        .background(Tokens.accentSoft, in: Circle())
                    Text("purchase.title").font(Tokens.largeTitle).multilineTextAlignment(.center)
                    Text("purchase.description").font(Tokens.body).foregroundStyle(Tokens.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Card {
                    BenefitRow(symbol: "infinity", text: "purchase.benefit.unlimited")
                    BenefitRow(symbol: "checkmark.seal", text: "purchase.benefit.oneTime")
                    BenefitRow(symbol: "lock.shield", text: "purchase.benefit.private")
                }

                if let price = purchases.product?.displayPrice {
                    Text(verbatim: price).font(Tokens.number).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                }
                if let message = purchases.message {
                    StatusBanner(text: message, kind: messageKind)
                }
                Button(purchases.product == nil ? "purchase.retry" : "purchase.buy") {
                    Task {
                        if purchases.product == nil { await purchases.loadProduct() }
                        else { await purchases.purchase(using: { try await purchaseAction($0) }) }
                    }
                }
                .buttonStyle(.primary)
                .disabled(purchases.busy || purchases.loading)
                .accessibilityIdentifier("paywall-buy")
                Button("purchase.restore") { Task { await purchases.restore() } }
                    .buttonStyle(.textLink)
                    .disabled(purchases.busy)
                    .frame(maxWidth: .infinity)
                Text("purchase.terms")
                    .font(Tokens.caption)
                    .foregroundStyle(Tokens.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(Tokens.foreground)
            .tint(Tokens.accent)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("action.close") { dismiss() }
                    .disabled(purchases.busy)
                    .accessibilityIdentifier("paywall-close")
            } }
        }
        .interactiveDismissDisabled(purchases.busy)
        .task { if purchases.product == nil { await purchases.loadProduct() } }
        .onChange(of: purchases.unlocked) { _, value in if value { dismiss(); onUnlocked() } }
    }
}
