import SwiftUI

/// The key button in the window corner and its popover.
struct APIKeyButton: View {
    let model: SearchModel
    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: model.hasKey ? "sparkles" : "key.fill")
                Text(model.hasKey ? "Jev" : "Add TypeSafe key")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(model.hasKey ? Color.accentColor : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white.opacity(0.9), in: Capsule())
            .overlay(Capsule().stroke(.black.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            APIKeyForm(model: model, isOpen: $isOpen)
        }
    }
}

private struct APIKeyForm: View {
    let model: SearchModel
    @Binding var isOpen: Bool
    @State private var key = ""
    @State private var error: String?
    @State private var isChecking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("TypeSafe API key", systemImage: "key.fill")
                .font(.headline)
            Text(model.hasKey
                ? "Jev ranks your results. The key is in your Keychain."
                : "Jev ranks the results by meaning. The key stays in your Keychain.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField(model.hasKey ? "Paste a new key to replace it" : "Paste your key", text: $key)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if model.hasKey {
                    Button("Remove key", role: .destructive) {
                        model.removeKey()
                        isOpen = false
                    }
                }
                Spacer()
                if isChecking { ProgressView().controlSize(.small) }
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isChecking)
            }
        }
        .padding(18)
        .frame(width: 340)
    }

    private func save() {
        isChecking = true
        error = nil
        Task {
            error = await model.saveKey(key)
            isChecking = false
            if error == nil { isOpen = false }
        }
    }
}
