import Foundation
import Observation
import SymbolSearch

@MainActor
@Observable
final class SearchModel {
    var query = ""
    var copiedName: String?
    var status: String?
    var focusRequests = 0
    /// The iOS deployment target, or nil for no filter.
    var minIOS = UserDefaults.standard.object(forKey: "minIOS") as? Int
    var onCopied: () -> Void = {}
    var onEscape: () -> Void = {}
    let scene = SymbolScene()

    private var retriever: Retriever?
    private var reranker = JevReranker(apiKey: ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"])
    var hasKey: Bool { reranker != nil }
    private var searchTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    init() {
        scene.onCopy = { [weak self] name in
            self?.showCopied(name)
            self?.onCopied()
        }
        scene.onMouseDown = { [weak self] in self?.focusRequests += 1 }
        Task { await load() }
        Task { await loadStoredKey() }
    }

    /// macOS can show a password dialog for the Keychain. The read runs off the main thread,
    /// so the window opens while that dialog waits.
    private func loadStoredKey() async {
        guard reranker == nil else { return }
        reranker = JevReranker(apiKey: await Task.detached { KeychainStore.read() }.value)
        search()
    }

    /// Checks the key with one request, then stores it. Returns an error message on failure.
    func saveKey(_ key: String) async -> String? {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let candidate = JevReranker(apiKey: key) else { return "The key is empty." }
        do {
            try await candidate.validate()
        } catch {
            return "TypeSafe did not accept the key. \(error)"
        }
        guard KeychainStore.save(key) else { return "The Keychain did not save the key." }
        reranker = candidate
        status = nil
        search()
        return nil
    }

    func applyMinIOS() {
        UserDefaults.standard.set(minIOS, forKey: "minIOS")
        scene.minIOS = minIOS.map(Double.init)
    }

    func removeKey() {
        KeychainStore.delete()
        reranker = nil
        search()
    }

    private func load() async {
        let url = Bundle.main.url(forResource: "symbols", withExtension: "json")
            ?? Bundle.module.url(forResource: "symbols", withExtension: "json")
        guard let url, let catalog = try? Data(contentsOf: url) else {
            status = "symbols.json is missing. Run Scripts/build_catalog.py."
            return
        }
        let retriever = await Task.detached { try? Retriever(catalog: catalog) }.value
        self.retriever = retriever
        scene.fillPile(with: retriever?.symbols ?? [])
        search()
    }

    func search() {
        searchTask?.cancel()
        status = nil
        guard let retriever else { return }
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            scene.show([])
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            let shortlist = await Task.detached { retriever.search(query, limit: 48) }.value
            guard !Task.isCancelled else { return }
            scene.show(shortlist.prefix(24).filter { $0.score >= 0.4 })

            guard let reranker else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let ranked = try await reranker.rerank(shortlist, query: query)
                guard !Task.isCancelled else { return }
                scene.show(ranked.filter { $0.score >= 0.5 })
                status = nil
            } catch {
                // New typing cancels the request in flight. That is not an error.
                guard !Task.isCancelled else { return }
                status = (error as? RerankError)?.description ?? error.localizedDescription
            }
        }
    }

    private func showCopied(_ name: String) {
        copiedName = name
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            copiedName = nil
        }
    }
}
