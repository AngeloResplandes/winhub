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
                    Button { isCreatingBottle = true } label: {
                        Label("Nova garrafa…", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .safeAreaInset(edge: .bottom) { RuntimeStatusView().padding(10) }
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
        .alert("Algo deu errado", isPresented: .constant(wine.errorMessage != nil)) {
            Button("OK") { wine.errorMessage = nil }
        } message: {
            Text(wine.errorMessage ?? "")
        }
        .onAppear { wine.refresh() }
    }
}

/// Wine runtime state at the bottom of the sidebar.
struct RuntimeStatusView: View {
    @Environment(WineStore.self) private var wine

    var body: some View {
        if let progress = wine.runtimeProgress {
            ProgressView(value: progress) { Text("Baixando o Wine…").font(.caption) }
        } else if let runtime = wine.runtime {
            Label("\(runtime.manifest.name) \(runtime.manifest.version)", systemImage: "checkmark.seal")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Button { wine.isShowingRuntimeSetup = true } label: {
                Label("Baixar o Wine", systemImage: "arrow.down.circle").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
    }
}
