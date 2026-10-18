import WinHubCore
import SwiftUI

struct RatingStars: View {
    let rating: Rating

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating.stars ? "star.fill" : "star")
                    .foregroundStyle(index <= rating.stars ? Color.orange : Color.secondary.opacity(0.4))
            }
        }
        .font(.caption)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rating.title)
    }
}

struct EntryIcon: View {
    let entry: CatalogEntry

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LinearGradient(colors: [tint.opacity(0.85), tint.opacity(0.55)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Text(initials)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
    }

    private var initials: String {
        let words = entry.name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        return String(words.prefix(2).compactMap(\.first)).uppercased()
    }

    private var tint: Color {
        let palette: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .green, .red]
        let hash = entry.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palette[hash % palette.count]
    }
}

struct EntryCard: View {
    let entry: CatalogEntry
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            EntryIcon(entry: entry)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName())
                    .font(.headline)
                    .lineLimit(2)
                Text(entry.categoryPath.last ?? "Sem categoria")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { RatingStars(rating: entry.rating); ratingLabel }
                    VStack(alignment: .leading, spacing: 2) { RatingStars(rating: entry.rating); ratingLabel }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var ratingLabel: some View {
        Text(entry.rating.title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .accessibilityHidden(true) // RatingStars already reads the label
    }
}

struct EntryDetailView: View {
    let entry: CatalogEntry
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    EntryIcon(entry: entry)
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Fechar")
                }
                Text(entry.displayName())
                    .font(.title2.bold())
                if entry.displayName() != entry.name {
                    Text(entry.name).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    RatingStars(rating: entry.rating)
                    Text(entry.rating.title).font(.callout.weight(.medium))
                }

                EntryActions(entry: entry)

                if !entry.category.isEmpty {
                    LabeledContent("Categoria", value: entry.categoryPath.joined(separator: " › "))
                }
                if entry.isFeatured {
                    Label("Em destaque", systemImage: "sparkles").foregroundStyle(.orange)
                }

                if !entry.summary.isEmpty {
                    Text(entry.displaySummary())
                        .font(.body)
                        .textSelection(.enabled)
                }

                if let steamID = entry.steamID,
                   let url = URL(string: "https://store.steampowered.com/app/\(steamID)") {
                    Link(destination: url) {
                        Label("Ver na Steam", systemImage: "arrow.up.right.square")
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Install / open buttons for a catalog title.
struct EntryActions: View {
    @Environment(WineStore.self) private var wine
    let entry: CatalogEntry

    var body: some View {
        if let recipe = entry.recipe {
            if let status = wine.activity[entry.id] {
                ProgressView { Text(status).font(.callout) }
                    .progressViewStyle(.linear)
            } else if wine.isInstalled(recipe) {
                if recipe.allLaunches.count > 1 {
                    Menu {
                        ForEach(recipe.allLaunches, id: \.self) { program in
                            Button(program.title) { wine.open(recipe, launch: program) }
                        }
                    } label: {
                        Label("Abrir", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button { wine.open(recipe) } label: {
                        Label("Abrir", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                Text("Na garrafa “\(recipe.bottleName)”.").font(.caption).foregroundStyle(.secondary)
            } else if !wine.recipeIsSupported(recipe) {
                Text("Este título precisa do WinHub \(recipe.minAppVersion ?? "") ou mais novo.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Button { Task { await wine.install(recipe, entryID: entry.id) } } label: {
                    Label("Instalar", systemImage: "arrow.down.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Text("Cria a garrafa “\(recipe.bottleName)” e baixa o instalador oficial.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else if let steamID = entry.steamID {
            if wine.isSteamInstalled {
                Button { wine.playOnSteam(appID: steamID) } label: {
                    Label("Jogar pela Steam", systemImage: "gamecontroller.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Text("A Steam instala o jogo se ainda não estiver instalado.")
                    .font(.caption).foregroundStyle(.secondary)
                if let game = entry.steamGame, let backend = wine.recommendedGraphics(for: game),
                   wine.isInstalled(game), wine.graphics(for: game) != backend {
                    Button { Task { await wine.applyRecommendedGraphics(game) } } label: {
                        Label("Usar \(backend.shortTitle) neste jogo (recomendado)", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    Text("Testado pelo WinHub. Vale só para este jogo; a Steam continua como está.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Label("Instale a Steam pelo catálogo para jogar este título.", systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

private let previewEntry = CatalogEntry(
    id: "preview.1",
    name: "Half-Life 2",
    category: "Games/First Person Shooter",
    summary: "Clássico de tiro em primeira pessoa com física inovadora.",
    rating: .excellent,
    isFeatured: true,
    steamID: 220
)

#Preview("Card") {
    HStack {
        EntryCard(entry: previewEntry, isSelected: false)
        EntryCard(entry: previewEntry, isSelected: true)
    }
    .padding()
    .frame(width: 560)
}

#Preview("Detalhes") {
    @Previewable @State var wine = WineStore()
    EntryDetailView(entry: previewEntry) {}
        .environment(wine)
        .frame(width: 320, height: 420)
}
