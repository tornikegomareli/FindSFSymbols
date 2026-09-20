import Foundation
import Testing
@testable import SymbolSearch

/// Calls the real API. It runs only when TYPESAFE_API_KEY is set.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"] != nil))
struct JevLiveTests {
    @Test(arguments: ["things you can wear", "money", "send a message"])
    func rerank(query: String) async throws {
        let catalog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/FindSFSymbols/Resources/symbols.json")
        let retriever = try Retriever(catalog: Data(contentsOf: catalog))
        let reranker = try #require(JevReranker(apiKey: ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"]))
        let shortlist = retriever.search(query, limit: 48)
        let start = Date()
        let ranked = try await reranker.rerank(shortlist, query: query)
        print("JEV \(query): \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
        for match in ranked { print("JEV   \(String(format: "%.2f", match.score)) \(match.symbol.name)") }
        #expect(ranked.count == shortlist.count)
    }
}
