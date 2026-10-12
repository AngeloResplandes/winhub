import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct WinHubApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var store = CatalogStore()
    @State private var wine = WineStore()
    @State private var updates = UpdateStore()

    var body: some Scene {
        WindowGroup("WinHub") {
            RootView()
                .environment(store)
                .environment(wine)
                .environment(updates)
                .frame(minWidth: 900, minHeight: 560)
                .task {
                    await store.loadInitialCatalog()
                    updates.start(catalog: store, wine: wine)
                }
                .onOpenURL { wine.handle($0) }
        }
        .handlesExternalEvents(matching: ["*"])
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Procurar Atualizações…") {
                    Task { await updates.check(userInitiated: true) }
                }
            }
            CommandGroup(after: .newItem) {
                Button("Instalar app não listado…") { wine.chooseInstaller() }
                    .keyboardShortcut("i")
                Button("Importar garrafa…") { Task { await wine.importBottle() } }
                Divider()
                Button("Importar catálogo…") { presentImportPanel() }
                    .keyboardShortcut("o")
                Button("Restaurar catálogo oficial") {
                    Task { await store.resetToOfficial() }
                }
            }
        }

        Settings {
            SettingsView()
                .environment(store)
                .environment(wine)
                .environment(updates)
        }
    }

    @MainActor
    private func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Escolha um catálogo do WinHub (.json)")
        if panel.runModal() == .OK, let url = panel.url {
            Task { await store.importCatalog(from: url) }
        }
    }
}

/// Lets the SwiftPM-built executable behave like a regular windowed app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct SettingsView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(WineStore.self) private var wine
    @Environment(UpdateStore.self) private var updates

    var body: some View {
        @Bindable var store = store
        @Bindable var updates = updates
        Form {
            Section("Catálogo") {
                Toggle("Mostrar apps sem teste", isOn: $store.showUntested)
                Text("Inclui títulos sem avaliação ou marcados como “Não instala”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Wine") {
                if let runtime = wine.runtime {
                    LabeledContent("Instalado", value: "\(runtime.manifest.name) \(runtime.manifest.version)")
                    LabeledContent("Licença", value: runtime.manifest.license)
                } else {
                    Button("Baixar o Wine…") { wine.isShowingRuntimeSetup = true }
                }
            }
            Section("D3DMetal (opcional)") {
                LabeledContent("Pasta", value: wine.d3dmetalLocation.path)
                LabeledContent("Situação", value: wine.hasD3DMetal ? String(localized: "Encontrado") : String(localized: "Não encontrado"))
                HStack {
                    Button("Escolher pasta…") { wine.chooseD3DMetalFolder() }
                    if !wine.usesDefaultD3DMetalFolder {
                        Button("Usar a pasta padrão") { wine.useDefaultD3DMetalFolder() }
                    }
                }
                Text("O D3DMetal (Direct3D 11/12) é da Apple e não vem com o WinHub. Se você tem o Game Porting Toolkit, aponte a pasta dele; o motor do WinHub passa a oferecer “D3DMetal” nas garrafas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Atualizações") {
                LabeledContent("Versão", value: updates.currentVersion?.description ?? "desenvolvimento")
                Toggle("Procurar atualizações automaticamente", isOn: $updates.automaticChecks)
                Text("O catálogo e os dados acompanham o repositório no GitHub; versões novas do app são baixadas e instaladas ao reiniciar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(updates.statusText).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if updates.readyVersion != nil {
                        Button("Reiniciar para atualizar") { updates.restartToUpdate() }
                    } else {
                        Button("Procurar agora") { Task { await updates.check() } }
                            .disabled(updates.phase == .checking)
                    }
                }
                if let lastCheck = updates.lastCheck {
                    LabeledContent("Última verificação", value: lastCheck.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}
