import XCTest
import UniformTypeIdentifiers
@testable import NoProcrastinateCore

final class StudyResourceStorageTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testSeparateSharesSurviveReopeningWithoutOverwritingEachOther() throws {
        let store = SharedStudyResourceStore(directory: directory)
        let first = SharedStudyResource(id: UUID(), title: "Read chapter", content: "https://example.com/chapter", kind: .link, receivedAt: Date(timeIntervalSince1970: 100))
        let second = SharedStudyResource(id: UUID(), title: "Exercises", content: "Solve exercises 1–4", kind: .text, receivedAt: Date(timeIntervalSince1970: 200))
        try store.save(first)
        try store.save(second)
        let reopened = SharedStudyResourceStore(directory: directory)
        XCTAssertEqual(try reopened.resources(), [first, second])
        try reopened.remove(id: first.id)
        try reopened.remove(id: first.id)
        XCTAssertEqual(try reopened.resources(), [second])
    }

    func testMalformedInboxFileIsRetainedAndReported() throws {
        let file = directory.appendingPathComponent(UUID().uuidString + ".json")
        try Data("broken".utf8).write(to: file)
        XCTAssertThrowsError(try SharedStudyResourceStore(directory: directory).resources())
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testInvalidResourceDoesNotCreateInboxFile() throws {
        let resource = SharedStudyResource(id: UUID(), title: "Read", content: "file:///notes", kind: .link, receivedAt: Date())
        let store = SharedStudyResourceStore(directory: directory)
        XCTAssertThrowsError(try store.save(resource))
        XCTAssertTrue(try store.resources().isEmpty)
    }

    func testSharingURLPrefersLinkOverDuplicateTextRepresentation() async throws {
        let item = NSExtensionItem()
        item.attributedTitle = NSAttributedString(string: "Chapter 5")
        item.attachments = [NSItemProvider(item: "duplicate page text" as NSString, typeIdentifier: UTType.plainText.identifier), NSItemProvider(item: URL(string: "https://example.com/chapter")! as NSURL, typeIdentifier: UTType.url.identifier)]
        let resource = try await StudyResourceLoader.load(items: [item])
        XCTAssertEqual(resource.kind, .link)
        XCTAssertEqual(resource.content, "https://example.com/chapter")
        XCTAssertEqual(resource.title, "Chapter 5")
    }

    func testSharingPlainTextLoadsNotesFromItemProvider() async throws {
        let item = NSExtensionItem()
        item.attachments = [NSItemProvider(item: "  Solve exercises 1–4  " as NSString, typeIdentifier: UTType.plainText.identifier)]
        let resource = try await StudyResourceLoader.load(items: [item])
        XCTAssertEqual(resource.kind, .text)
        XCTAssertEqual(resource.content, "Solve exercises 1–4")
        XCTAssertEqual(resource.title, "Solve exercises 1–4")
    }

    func testSharingAttributedTextWithoutAttachmentLoadsContent() async throws {
        let item = NSExtensionItem()
        item.attributedContentText = NSAttributedString(string: "Review the lecture")
        let resource = try await StudyResourceLoader.load(items: [item])
        XCTAssertEqual(resource.kind, .text)
        XCTAssertEqual(resource.content, "Review the lecture")
    }

    func testSharingUnsupportedAttachmentReportsFailure() async {
        let item = NSExtensionItem()
        item.attachments = [NSItemProvider(item: Data([1, 2, 3]) as NSData, typeIdentifier: UTType.image.identifier)]
        do {
            _ = try await StudyResourceLoader.load(items: [item])
            XCTFail()
        } catch { XCTAssertTrue(error is SharedResourceFailure) }
    }
}
