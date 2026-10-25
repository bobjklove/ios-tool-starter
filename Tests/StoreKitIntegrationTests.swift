import XCTest
import StoreKit
import StoreKitTest
@testable import ToolStarter

@MainActor final class StoreKitIntegrationTests: XCTestCase {
    func testOfflinePurchaseAndRevocation() async throws {
        // Internal simulator errors are reported as failures/environment blockers, never skipped as passes.
        let configuration = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "ToolStarter", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: configuration)
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let products = try await Product.products(for: [AppConfiguration.productID])
        XCTAssertEqual(products.count, 1)
        let service = PurchaseService()
        await service.start()
        XCTAssertEqual(service.product?.id, AppConfiguration.productID)
        await service.purchase(using: { try await $0.purchase() })
        XCTAssertTrue(service.unlocked)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        for _ in 0..<25 {
            if !service.unlocked { break }
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertFalse(service.unlocked)
    }
}
