import Foundation

enum SharedContainer {
    static let identifier = "group.com.drivenligret.NoProcrastinate"
    static func focusStore() throws -> SharedFocusLeaseStore {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else { throw SharedStudyStorageFailure.unavailable }
        return SharedFocusLeaseStore(directory: directory)
    }
}

enum SharedStudyStorageFailure: Error, LocalizedError {
    case unavailable
    var errorDescription: String? { "App limits unavailable. Reopen and retry." }
}

struct FocusLease: Codable, Equatable {
    static let activityName = "NoProcrastinateFocus"
    static let settingsName = "NoProcrastinateFocus"
    let sessionID: UUID
    let startedAt: Date
    let endsAt: Date
    let selection: Data
}

struct SharedFocusLeaseStore {
    let directory: URL

    func update<T>(_ operation: (inout FocusLease?) throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("focus-lease.json")
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationError: Error?
        var result: T?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { location in
            do {
                var lease: FocusLease?
                if FileManager.default.fileExists(atPath: location.path) {
                    lease = try JSONDecoder().decode(FocusLease.self, from: Data(contentsOf: location))
                }
                result = try operation(&lease)
                if let lease {
                    try JSONEncoder().encode(lease).write(to: location, options: .atomic)
                } else if FileManager.default.fileExists(atPath: location.path) {
                    try FileManager.default.removeItem(at: location)
                }
            } catch { operationError = error }
        }
        if let coordinationError { throw coordinationError }
        if let operationError { throw operationError }
        guard let result else { throw SharedStudyStorageFailure.unavailable }
        return result
    }
}
