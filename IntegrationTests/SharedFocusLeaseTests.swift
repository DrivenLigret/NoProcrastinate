import Foundation
import XCTest

final class SharedFocusLeaseTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testFocusLeaseSurvivesOpeningAnotherSharedStore() throws {
        let lease = FocusLease(sessionID: UUID(), startedAt: Date(timeIntervalSince1970: 1800000000), endsAt: Date(timeIntervalSince1970: 1800001500), selection: Data([1, 2, 3]))
        try SharedFocusLeaseStore(directory: directory).update { $0 = lease }
        let reopened = SharedFocusLeaseStore(directory: directory)
        XCTAssertEqual(try reopened.update { $0 }, lease)
    }

    func testAnOldSessionCannotRemoveANewerFocusLease() throws {
        let store = SharedFocusLeaseStore(directory: directory)
        let oldID = UUID()
        let current = FocusLease(sessionID: UUID(), startedAt: Date(), endsAt: Date().addingTimeInterval(1500), selection: Data())
        try store.update { $0 = current }
        try store.update { lease in if lease?.sessionID == oldID { lease = nil } }
        XCTAssertEqual(try store.update { $0?.sessionID }, current.sessionID)
    }

    func testReleasingFocusRemovesTheSharedLease() throws {
        let store = SharedFocusLeaseStore(directory: directory)
        try store.update { $0 = FocusLease(sessionID: UUID(), startedAt: Date(), endsAt: Date().addingTimeInterval(1500), selection: Data()) }
        try store.update { $0 = nil }
        XCTAssertNil(try store.update { $0 })
    }
}
