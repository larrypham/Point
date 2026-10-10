import BrowserPersistence
import Foundation
import Testing

@Suite("Browsing history persistence")
struct BrowsingHistoryRepositoryTests {
    @Test
    func fileRepositoryStoresRecentVisitTitleAndAddress() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = FileBrowsingHistoryRepository(
            fileURL: directory.appendingPathComponent("history.json")
        )
        let url = try #require(URL(string: "https://example.com/articles/point"))

        try await repository.recordVisit(
            url: url,
            title: "Point Article",
            visitedAt: Date()
        )
        let entries = try await repository.recent(limit: 10)

        #expect(entries.count == 1)
        #expect(entries[0].url == url)
        #expect(entries[0].title == "Point Article")
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
