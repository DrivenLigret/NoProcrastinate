import SwiftUI
import NoProcrastinateCore

@main
struct NoProcrastinateApp: App {
    @StateObject private var planner: StudyPlannerViewModel
    @StateObject private var focus: FocusViewModel
    @StateObject private var progress: StudyProgressViewModel

    init() {
        do {
            let repository = try CoreDataStudyRepository(storeURL: Self.testingStore())
            _planner = StateObject(wrappedValue: StudyPlannerViewModel(repository: repository))
            _focus = StateObject(wrappedValue: FocusViewModel(repository: repository))
            _progress = StateObject(wrappedValue: StudyProgressViewModel(repository: repository))
        } catch {
            _planner = StateObject(wrappedValue: StudyPlannerViewModel(repository: nil, initialError: StudyError.storageUnavailable.localizedDescription))
            _focus = StateObject(wrappedValue: FocusViewModel(repository: nil))
            _progress = StateObject(wrappedValue: StudyProgressViewModel(repository: nil))
        }
    }

    var body: some Scene {
        WindowGroup {
            StudyRootView(planner: planner, focus: focus, progress: progress)
                .tint(Color(red: 0.08, green: 0.43, blue: 0.39))
                .environment(\.locale, Locale(identifier: "en"))
        }
    }

    private static func testingStore() throws -> URL? {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing") else { return nil }
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("StudyUITests", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = directory.appendingPathComponent("StudyUITests.sqlite")
        if ProcessInfo.processInfo.arguments.contains("-reset-study-records") {
            for suffix in ["", "-wal", "-shm"] {
                let file = directory.appendingPathComponent("StudyUITests.sqlite" + suffix)
                if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            }
        }
        return store
    }
}
