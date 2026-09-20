import Foundation
import Testing
@testable import SymbolSearch

@Suite struct JevRerankerTests {
    @Test func bodyHasOneNoulQuestionPerSymbol() throws {
        let matches = ["tshirt.fill", "shoe.fill"].map {
            Match(symbol: Symbol(name: $0, keywords: ["clothing"], categories: []), score: 1)
        }
        let body = JevReranker.body(for: matches, query: "things you can wear")
        let questions = try #require(body["questions"] as? [String: [String: Any]])
        let state = try #require(body["state"] as? [String: Any])
        let icons = try #require(state["icons"] as? [String: [String: Any]])

        #expect(body["model"] as? String == "jev-latest")
        #expect(state["query"] as? String == "things you can wear")
        #expect(Set(questions.keys) == ["s0", "s1"])
        #expect(questions["s0"]?["type"] as? String == "noul")
        #expect(icons["s0"]?["name"] as? String == "tshirt")
        #expect(JSONSerialization.isValidJSONObject(body))
    }

    @Test func noKeyMeansNoReranker() {
        #expect(JevReranker(apiKey: nil) == nil)
        #expect(JevReranker(apiKey: "") == nil)
    }
}
