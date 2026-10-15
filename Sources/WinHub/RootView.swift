import SwiftUI
import WinHubRuntime

/// Main window: sidebar with Catálogo, Programas and the bottles.
struct RootView: View {
    enum Section: Hashable {
        case catalog
        case programs
        case bottle(Bottle.ID)
    }

    @Environment(WineStore.self) private var wine
    @Environment(UpdateStore.self) private var updates
    @State private var section: Section? = .catalog
    @State private var isCreatingBottle = false

    var body: some View {
        @Bindable var wine = wine
        NavigationSplitView {
            List(selection: $section) {
                Label("Catálogo", systemImage: "square.grid.2x2").tag(Section.catalog)
                Label("Programas", systemImage: "macwindow.on.rectangle").tag(Section.programs)
                SwiftUI.Section("Garrafas") {
                    ForEach(wine.bottles) { bottle in
                        HStack {
                            Label(bottle.name, systemImage: "shippingbox")
                            Spacer()
                            if wine.activity[bottle.id.uuidString] != nil {
                                ProgressView().controlSize(.small)
                            } else if wine.activeBottles.contains(bottle.id) {
                                Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(.green)
                                    .help("Programa aberto")
                            }
                        }
                        .tag(Section.bottle(bottle.id))
                    }
                    if let status = wine.activity[WineStore.importActivity] {
                        HStack {
                            Label(status, systemImage: "square.and.arrow.down")
                            Spacer()
                            ProgressView().controlSize(.small)
                        }
                        .foregroundStyle(.secondary)
                    }
                    Button { isCreatingBottle = true } label: {
                        Label("Nova garrafa…", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    AppUpdateBanner()
                    RuntimeStatusView()
                }
                .padding(10)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            switch section {
            case .catalog, nil:
                CatalogView()
            case .programs:
                ProgramsView()
            case .bottle(let id):
                if let bottle = wine.bottle(id: id) {
                    BottleDetailView(bottle: bottle) { section = .catalog }
                } else {
                    ContentUnavailableView("Garrafa não encontrada", systemImage: "shippingbox")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { wine.chooseInstaller() } label: {
                    Label("Instalar app não listado", systemImage: "square.and.arrow.down")
                }
                .help("Instalar um programa do Windows a partir de um arquivo .exe ou .msi")
            }
        }
        .sheet(isPresented: $wine.isShowingRuntimeSetup) { RuntimeSetupView() }
        .sheet(isPresented: $isCreatingBottle) { NewBottleSheet() }
        .sheet(item: $wine.pendingInstall) { pending in InstallSheet(pending: pending) }
        .confirmationDialog("Encerrar os programas antes de continuar?",
                            isPresented: $wine.isShowingConflict,
                            titleVisibility: .visible, presenting: wine.pendingConflict) { pending in
            // `pending` is captured: dismissing the dialog clears `pendingConflict` before the task runs.
            if pending.opensProgram {
                Button("Encerrar e abrir", role: .destructive) { Task { await wine.resolveConflict(pending) } }
            } else {
                Button("Encerrar e continuar", role: .destructive) { Task { await wine.resolveConflict(pending) } }
            }
            Button("Cancelar", role: .cancel) { wine.cancelConflict() }
        } message: { pending in
            Text(Self.message(for: pending))
        }
        .alert("Algo deu errado", isPresented: .constant(wine.errorMessage != nil)) {
            Button("OK") { wine.errorMessage = nil }
        } message: {
            Text(wine.errorMessage ?? "")
        }
        .alert("Atualizações", isPresented: .constant(updates.notice != nil)) {
            Button("OK") { updates.notice = nil }
        } message: {
            Text(updates.notice ?? "")
        }
        .onAppear { wine.refresh() }
    }

    static func message(for pending: WineStore.PendingConflict) -> String {
        switch pending.conflict {
        case .otherWinHub(let appPath):
            // `…/WinHub.app/Contents/MacOS/WinHub` → `…/WinHub.app`
            let app = appPath.range(of: ".app/").map { String(appPath[..<$0.lowerBound]) + ".app" } ?? appPath
            return String(localized: "A garrafa “\(pending.bottle.name)” está em uso por outro WinHub (\(app)).")
        case .otherEngine:
            return String(localized: "Os programas da garrafa “\(pending.bottle.name)” estão rodando com outro motor.")
        case .steamRunning(let name, _):
            return String(localized: "A Steam já está aberta na garrafa “\(name)”. Duas Steam ao mesmo tempo podem desinstalar jogos.")
        }
    }
}

/// A downloaded WinHub version waiting for a restart.
struct AppUpdateBanner: View {
    @Environment(UpdateStore.self) private var updates
    @Environment(WineStore.self) private var wine

    var body: some View {
        if case .ready(let version, _, let notes) = updates.phase {
            let busy = !wine.activity.isEmpty || wine.runtimeProgress != nil
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("WinHub \(version)", systemImage: "arrow.down.app").font(.caption.bold())
                    Spacer()
                    Link("Novidades", destination: notes).font(.caption)
                }
                Button { updates.restartToUpdate() } label: {
                    Text("Reiniciar para atualizar").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(busy)
                if busy {
                    Text("Aguarde as tarefas em andamento terminarem.").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

/// Wine runtime state at the bottom of the sidebar.
struct RuntimeStatusView: View {
    @Environment(WineStore.self) private var wine

    var body: some View {
        if let progress = wine.runtimeProgress {
            ProgressView(value: progress) { Text("Baixando o Wine…").font(.caption) }
        } else if let runtime = wine.runtime {
            VStack(alignment: .leading, spacing: 4) {
                Label("\(runtime.manifest.name) \(runtime.manifest.version)", systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let upgrade = wine.runtimeUpgrade {
                    Button("Atualizar o Wine para \(upgrade.version)…") { wine.isShowingRuntimeSetup = true }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Button { wine.isShowingRuntimeSetup = true } label: {
                Label("Baixar o Wine", systemImage: "arrow.down.circle").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
    }
}
