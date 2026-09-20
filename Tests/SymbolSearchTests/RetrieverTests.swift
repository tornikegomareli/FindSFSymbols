import Foundation
import Testing
@testable import SymbolSearch

private let catalogURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Sources/FindSFSymbols/Resources/symbols.json")

private let retriever = try! Retriever(catalog: Data(contentsOf: catalogURL))

@Suite struct RetrieverTests {
    // The second stage can only reorder the shortlist, so the shortlist must contain these.
    @Test(arguments: [
        ("things you can wear", ["tshirt.fill", "shoe.fill", "eyeglasses", "sunglasses.fill", "hat.cap.fill"]),
        ("money", ["dollarsign", "creditcard.fill", "banknote.fill"]),
        ("bad weather", ["cloud.bolt.rain.fill", "tornado", "hurricane"]),
        ("send a message", ["paperplane.fill", "envelope.fill", "message.fill"]),
        ("pets", ["dog.fill", "cat.fill", "pawprint.fill"]),
        ("music", ["music.note", "headphones", "guitars.fill"]),
        ("hea", ["heart.fill", "headphones"]),
    ])
    func shortlistContains(query: String, expected: [String]) {
        let names = retriever.search(query, limit: 60).map(\.symbol.name)
        let missing = expected.filter { !names.contains($0) }
        #expect(missing.isEmpty, "\(query): missing \(missing). Top: \(names.prefix(15))")
    }

    @Test func emptyQueryReturnsNothing() {
        #expect(retriever.search("  the ", limit: 60).isEmpty)
    }
}
