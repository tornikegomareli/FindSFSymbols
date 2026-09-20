import Foundation

/// Second search stage. Jev judges each shortlisted symbol against the query.
/// One request carries one Noul question per symbol. The questions run in parallel.
public struct JevReranker: Sendable {
    private let apiKey: String
    private let endpoint = URL(string: "https://api.typesafe.ai/v1/systemone")!

    public init?(apiKey: String?) {
        guard let apiKey, !apiKey.isEmpty else { return nil }
        self.apiKey = apiKey
    }

    public func rerank(_ matches: [Match], query: String) async throws -> [Match] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.body(for: matches, query: query))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw RerankError(message: String(decoding: data, as: UTF8.self))
        }
        let answers = try JSONDecoder().decode(Response.self, from: data).answers
        return matches.enumerated()
            .compactMap { index, match in
                answers["s\(index)"].map { Match(symbol: match.symbol, score: $0.noul) }
            }
            .sorted { $0.score > $1.score }
    }

    /// Sends one small question. It throws if the service rejects the key.
    public func validate() async throws {
        let probe = Match(symbol: Symbol(name: "heart.fill", keywords: [], categories: []), score: 1)
        _ = try await rerank([probe], query: "heart")
    }

    static func body(for matches: [Match], query: String) -> [String: Any] {
        var icons: [String: Any] = [:]
        var questions: [String: Any] = [:]
        for (index, match) in matches.enumerated() {
            let symbol = match.symbol
            icons["s\(index)"] = [
                "name": symbol.name.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "),
                "keywords": symbol.keywords,
                "categories": symbol.categories,
            ]
            questions["s\(index)"] = [
                "type": "noul",
                "instructions": "A person searches an icon library with the text in `query`. "
                    + "Is the icon described at `icons.s\(index)` a good result for that search?",
                "criteria": [
                    "true": "The icon shows the thing, action, or idea that the search text describes.",
                    "false": "The icon shows something else, or it only shares a word with the search text.",
                ],
            ]
        }
        return ["model": "jev-latest", "state": ["query": query, "icons": icons], "questions": questions]
    }

    private struct Response: Decodable {
        struct Answer: Decodable { let noul: Double }
        let answers: [String: Answer]
    }
}

public struct RerankError: Error, CustomStringConvertible {
    let message: String
    public var description: String { "TypeSafe request failed: \(message)" }
}
