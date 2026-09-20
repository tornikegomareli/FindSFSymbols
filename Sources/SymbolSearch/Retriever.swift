import Foundation
import NaturalLanguage

public struct Symbol: Decodable, Sendable, Hashable {
    public let name: String
    public let keywords: [String]
    public let categories: [String]
    /// The first iOS version that has this symbol name.
    public let ios: Double

    public init(name: String, keywords: [String], categories: [String], ios: Double = 13) {
        self.name = name
        self.keywords = keywords
        self.categories = categories
        self.ios = ios
    }
}

public struct Match: Sendable, Hashable {
    public let symbol: Symbol
    /// 0 to 1. Higher is a better match.
    public var score: Double
}

/// First search stage. It ranks the whole catalog on the device with word vectors.
public struct Retriever: Sendable {
    public let symbols: [Symbol]
    private let tokens: [[String]]
    private let vectors: [[[Float]]]

    private static let stopWords: Set<String> = [
        "a", "an", "the", "you", "can", "to", "of", "and", "or", "things", "thing", "that", "for",
        "with", "in", "on", "i", "my", "something", "stuff", "is", "are", "it",
    ]

    public init(catalog: Data) throws {
        let symbols = try JSONDecoder().decode([Symbol].self, from: catalog)
        let embedding = WordVectors()
        var tokens: [[String]] = []
        var vectors: [[[Float]]] = []
        for symbol in symbols {
            let words = Self.words(of: symbol, embedding: embedding)
            tokens.append(words)
            vectors.append(words.compactMap { embedding.vector(for: $0) })
        }
        self.symbols = symbols
        self.tokens = tokens
        self.vectors = vectors
    }

    public func search(_ query: String, limit: Int) -> [Match] {
        let embedding = WordVectors()
        let queryWords = query.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !Self.stopWords.contains($0) }
        guard !queryWords.isEmpty else { return [] }
        let queryVectors = queryWords.map { embedding.vector(for: $0) }

        var matches: [Match] = []
        for index in symbols.indices {
            var total: Float = 0
            for (word, vector) in zip(queryWords, queryVectors) {
                var best: Float = 0
                if tokens[index].contains(word) {
                    best = 1
                } else if let vector {
                    for candidate in vectors[index] {
                        best = max(best, dot(vector, candidate))
                    }
                } else if word.count >= 2, tokens[index].contains(where: { $0.hasPrefix(word) }) {
                    // A word with no vector is a word in progress. "hea" finds "heart".
                    best = 0.9
                }
                total += best
            }
            // Many symbols tie on one shared word. The short name is the main symbol.
            let parts = symbols[index].name.split(separator: ".").count
            let score = Double(total) / Double(queryWords.count) - 0.01 * Double(parts - 1)
            matches.append(Match(symbol: symbols[index], score: max(0, score)))
        }
        return Array(matches.sorted { $0.score > $1.score }.prefix(limit))
    }

    /// Name parts and keywords. A compound such as "dollarsign" also gives "dollar" and "sign".
    private static func words(of symbol: Symbol, embedding: WordVectors) -> [String] {
        var words: [String] = []
        for part in symbol.name.split(separator: ".") where Int(part) == nil && part != "fill" {
            words.append(String(part))
        }
        for keyword in symbol.keywords {
            words += keyword.lowercased().split(separator: " ").map(String.init)
        }
        for word in words where embedding.vector(for: word) == nil {
            words += embedding.split(compound: word)
        }
        var seen: Set<String> = []
        return words.filter { seen.insert($0).inserted }
    }

    private func dot(_ a: [Float], _ b: [Float]) -> Float {
        var sum: Float = 0
        for i in 0..<a.count { sum += a[i] * b[i] }
        return sum
    }
}

/// Unit-length English word vectors from the NaturalLanguage framework.
private struct WordVectors {
    private let embedding = NLEmbedding.wordEmbedding(for: .english)

    func vector(for word: String) -> [Float]? {
        guard let vector = embedding?.vector(for: word) else { return nil }
        let length = vector.reduce(0) { $0 + $1 * $1 }.squareRoot()
        return vector.map { Float($0 / length) }
    }

    func split(compound word: String) -> [String] {
        guard let embedding, word.count >= 6 else { return [] }
        for offset in 3...(word.count - 3) {
            let cut = word.index(word.startIndex, offsetBy: offset)
            let head = String(word[..<cut]), tail = String(word[cut...])
            if embedding.contains(head), embedding.contains(tail) { return [head, tail] }
        }
        // "tshirt" has a one-letter head.
        let tail = String(word.dropFirst())
        return embedding.contains(tail) ? [tail] : []
    }
}
