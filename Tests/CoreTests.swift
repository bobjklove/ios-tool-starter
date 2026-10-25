import XCTest
import PDFKit
import UIKit
@testable import ToolStarter

final class GeometryTests: XCTestCase {
    func testPhysicalUnitsAndPaper() throws {
        XCTAssertEqual(Length.points(2540), 72, accuracy: 0.000001)
        XCTAssertEqual(Length.units(points: 72), 2540)
        for paper in Paper.allCases {
            let project = SampleProject(imagePNG: SampleFixture.png(), paper: paper)
            let data = try PDFExporter.data(project)
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
            attachment.name = "geometry-" + paper.rawValue
            attachment.lifetime = .keepAlways
            add(attachment)
            let document = try XCTUnwrap(PDFDocument(data: data))
            XCTAssertEqual(document.pageCount, 1)
            let bounds = try XCTUnwrap(document.page(at: 0)).bounds(for: .mediaBox)
            XCTAssertEqual(bounds.width, Length.points(paper.width), accuracy: 0.01)
            XCTAssertEqual(bounds.height, Length.points(paper.height), accuracy: 0.01)
            let rect = try PDFExporter.contentRect(project)
            XCTAssertEqual(rect.width, Length.points(5000), accuracy: 0.000001)
            XCTAssertEqual(rect.height, Length.points(7000), accuracy: 0.000001)
        }
    }
    func testInvalidDimensionsRejected() {
        for size in [0, -1, 30000] {
            let project = SampleProject(imagePNG: SampleFixture.png(), width: size)
            XCTAssertThrowsError(try PDFExporter.data(project))
        }
        XCTAssertThrowsError(try PDFExporter.data(SampleProject(imagePNG: Data())))
    }
    func testFingerprintIncludesOnlyRenderingInputs() throws {
        var a = SampleProject(imagePNG: SampleFixture.png())
        var b = a; b.id = UUID()
        XCTAssertEqual(try ExportFingerprint.make(a), try ExportFingerprint.make(b))
        b.width += 1
        XCTAssertNotEqual(try ExportFingerprint.make(a), try ExportFingerprint.make(b))
        b = a; b.paper = .letter
        XCTAssertNotEqual(try ExportFingerprint.make(a), try ExportFingerprint.make(b))
        a.imagePNG.append(0)
        XCTAssertNotEqual(try ExportFingerprint.make(a), try ExportFingerprint.make(b))
    }
}

@MainActor final class FreeTierTests: XCTestCase {
    func testDuplicatesUnlockedAndPersistence() async throws {
        let suite = "test-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FreeTierStore(defaults: defaults)
        for key in ["a", "b", "c"] { try store.recordCompleted(key, unlocked: false) }
        XCTAssertEqual(store.remaining, 0)
        XCTAssertTrue(store.allows("a", unlocked: false))
        XCTAssertFalse(store.allows("d", unlocked: false))
        try store.recordCompleted("a", unlocked: false)
        try store.recordCompleted("d", unlocked: true)
        XCTAssertEqual(FreeTierStore(defaults: defaults).remaining, 0)
        XCTAssertThrowsError(try store.recordCompleted("d", unlocked: false))
    }
    func testCorruptHistoryDoesNotResetQuota() async throws {
        let suite = "test-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("bad".utf8), forKey: FreeTierStore.key)
        let store = FreeTierStore(defaults: defaults)
        XCTAssertFalse(store.allows("new", unlocked: false))
        XCTAssertTrue(store.allows("new", unlocked: true))
        XCTAssertNotNil(store.error)
    }
}

final class StorageTests: XCTestCase {
    func testRoundTripLegacyAndFutureVersion() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ProjectStore(directory: root)
        let project = SampleProject(imagePNG: SampleFixture.png())
        try store.save(project)
        XCTAssertEqual(try store.load(), project)
        let future = ProjectEnvelope(version: 999, project: project)
        try JSONEncoder().encode(future).write(to: store.file)
        XCTAssertThrowsError(try store.load())
        // Version 1 is the initial documented schema; absent version is deliberately unsupported.
        try Data("{}".utf8).write(to: store.file)
        XCTAssertThrowsError(try store.load())
    }
    func testExportLeaseCleanupOnSuccessCancellationAndFailure() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = TemporaryExports(root: root)
        let project = SampleProject(imagePNG: SampleFixture.png())
        let lease = try manager.create(project)
        XCTAssertTrue(FileManager.default.fileExists(atPath: lease.url.path))
        manager.remove(lease)
        XCTAssertFalse(FileManager.default.fileExists(atPath: lease.directory.path))
        XCTAssertThrowsError(try manager.create(SampleProject(imagePNG: Data())))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
        let stale = try manager.create(project)
        try manager.clearStale()
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.url.path))
    }
}

final class PurchaseStateTests: XCTestCase {
    func testPendingCancellationFailureNeverUnlock() {
        for event in [PurchaseEvent.pending, .cancelled, .failed, .unverified] {
            var state = PurchaseState()
            state.apply(.begin); state.apply(event)
            XCTAssertFalse(state.unlocked)
            XCTAssertFalse(state.busy)
        }
    }
    func testVerifiedRestoreAndRevocation() {
        var state = PurchaseState()
        state.apply(.entitlement(true)); XCTAssertTrue(state.unlocked)
        state.apply(.begin); state.apply(.cancelled)
        XCTAssertTrue(state.unlocked)
        state.apply(.entitlement(false)); XCTAssertFalse(state.unlocked)
    }
    func testEntitlementValidation() {
        XCTAssertTrue(PurchaseService.isActive(id: AppConfiguration.productID, nonConsumable: true, revoked: false))
        XCTAssertFalse(PurchaseService.isActive(id: "unrelated", nonConsumable: true, revoked: false))
        XCTAssertFalse(PurchaseService.isActive(id: AppConfiguration.productID, nonConsumable: false, revoked: false))
        XCTAssertFalse(PurchaseService.isActive(id: AppConfiguration.productID, nonConsumable: true, revoked: true))
    }
}
