import WinHubCore
import SwiftUI

struct CatalogView: View {
    @Environment(CatalogStore.self) private var store

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 12)]

    var body: some View {
        @Bindable var store = store
        ScrollViewReader { proxy in
            ScrollView {
                header
                    .id("top")
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.result.entries) { entry in
                        EntryCard(entry: entry, isSelected: store.selection == entry.id)
                            .onTapGesture { store.selection = entry.id }
                    }
                }
                .padding(.horizontal, 20)
                if !store.result.showsNoResults { footer }
            }
            // Each new search starts from the top of the list.
            .onChange(of: store.query) { proxy.scrollTo("top", anchor: .top) }
        }
        .overlay { overlay }
        .navigationTitle("Catálogo")
        .navigationSubtitle(store.source.label)
        .searchable(text: $store.query, placement: .toolbar, prompt: "Buscar jogos e apps")
        .inspector(isPresented: .constant(store.selectedEntry != nil)) {
            if let entry = store.selectedEntry {
                EntryDetailView(entry: entry) { store.selection = nil }
                    .inspectorColumnWidth(min: 280, ideal: 320, max: 420)
            }
        }
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $store.showUntested) {
                    Label("Sem teste", systemImage: "questionmark.diamond")
                }
                .help("Mostrar apps sem teste")
            }
        }
        .alert("Erro ao carregar catálogo", isPresented: .constant(store.errorMessage != nil)) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(store.result.isFeatured ? "Destaques" : "Resultados")
                .font(.title2.bold())
            Spacer()
            if !store.result.isFeatured && !store.result.showsNoResults {
                Text(countLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var countLabel: String {
        let result = store.result
        if result.isTruncated {
            return "Mostrando \(result.entries.count) de \(result.totalMatches) — refine a busca"
        }
        return result.totalMatches == 1 ? "1 título" : "\(result.totalMatches) títulos"
    }

    private var footer: some View {
        Text("\(store.engine.entries.count) títulos no catálogo")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.vertical, 20)
    }

    @ViewBuilder
    private var overlay: some View {
        if store.isLoading {
            ProgressView("Carregando catálogo…")
        } else if store.result.showsNoResults {
            ContentUnavailableView {
                Label("Nenhum resultado para “\(store.query)”", systemImage: "magnifyingglass")
            } description: {
                Text(store.showUntested
                     ? "Tente outras palavras."
                     : "Tente outras palavras ou ative “Mostrar apps sem teste”.")
            }
        }
    }
}

#Preview {
    @Previewable @State var store = CatalogStore()
    @Previewable @State var wine = WineStore()
    NavigationStack { CatalogView() }
        .environment(store)
        .environment(wine)
        .frame(width: 900, height: 600)
        .task { await store.loadInitialCatalog() }
}
