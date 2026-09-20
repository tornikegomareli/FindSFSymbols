import SpriteKit
import SwiftUI

struct ContentView: View {
    @Bindable var model: SearchModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: model.scene, preferredFramesPerSecond: 120)
                .ignoresSafeArea()
            searchBar
                .padding(.top, 56)
        }
        .overlay(alignment: .bottom) {
            if let name = model.copiedName {
                Text("Copied \(name)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.8), in: Capsule())
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                DeploymentTargetMenu(model: model)
                APIKeyButton(model: model)
            }
            .padding(12)
        }
        .overlay(alignment: .top) {
            if let status = model.status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .animation(.spring(duration: 0.3), value: model.copiedName)
        .preferredColorScheme(.light)
        .onExitCommand { model.onEscape() }
        .onChange(of: model.query) { model.search() }
        .onChange(of: model.minIOS, initial: true) { model.applyMinIOS() }
        .onChange(of: model.focusRequests, initial: true) {
            // The SpriteKit view takes the keyboard focus at launch and on each click. Take it back.
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                searchFocused = true
            }
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("Describe a symbol", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 30))
                .focused($searchFocused)
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
        .frame(width: 680, height: 84)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.black.opacity(0.06)))
        .shadow(color: .black.opacity(0.08), radius: 18, y: 6)
    }
}

/// The iOS deployment target. Symbols that need a later iOS turn gray and stay low.
struct DeploymentTargetMenu: View {
    @Bindable var model: SearchModel

    var body: some View {
        Menu {
            Picker("Deployment target", selection: $model.minIOS) {
                Text("Any iOS").tag(Int?.none)
                ForEach([26, 18, 17, 16, 15, 14, 13], id: \.self) { version in
                    Text("iOS \(version)").tag(Int?.some(version))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Text(model.minIOS.map { "iOS \($0)+" } ?? "Any iOS")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(model.minIOS == nil ? Color.secondary : Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.9), in: Capsule())
                .overlay(Capsule().stroke(.black.opacity(0.06)))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .fixedSize()
    }
}
