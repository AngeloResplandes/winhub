import SwiftUI
import WinHubCore
import WinHubRuntime

/// A program's own icon (from its `.exe`), or a generic one while it loads or if it has none.
struct ProgramIconView: View {
    @Environment(WineStore.self) private var wine
    let program: InstalledProgram
    let bottle: Bottle
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = wine.programIcons[program.id] {
                Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                    .fill(.blue.gradient)
                    .overlay { Image(systemName: "macwindow").font(.system(size: size * 0.45)).foregroundStyle(.white) }
            }
        }
        .frame(width: size, height: size)
        .task(id: program.id) { wine.loadIcon(for: program, in: bottle) }
    }
}

/// Icon tile for a Windows program.
struct ProgramTile: View {
    let program: InstalledProgram
    let bottle: Bottle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ProgramIconView(program: program, bottle: bottle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(program.name).font(.headline).lineLimit(2)
                    Text(bottle.name).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill").foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Abrir \(program.name)")
    }
}

/// Every installed program, across bottles.
struct ProgramsView: View {
    @Environment(WineStore.self) private var wine
    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 12)]

    var body: some View {
        let items = wine.bottles.flatMap { bottle in
            (wine.programs[bottle.id] ?? []).map { (bottle, $0) }
        }
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items, id: \.1.id) { bottle, program in
                    ProgramTile(program: program, bottle: bottle) { wine.open(program, in: bottle) }
                        .contextMenu { LauncherButton(program: program, bottle: bottle) }
                }
            }
            .padding(20)
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("Nenhum programa instalado", systemImage: "macwindow.on.rectangle")
                } description: {
                    Text("Instale um título pelo Catálogo ou use “Instalar app não listado”.")
                }
            }
        }
        .navigationTitle("Programas")
        .toolbar {
            ToolbarItem {
                Button { wine.refresh() } label: { Label("Atualizar", systemImage: "arrow.clockwise") }
            }
        }
    }
}

/// One bottle: its programs, settings and maintenance actions.
struct BottleDetailView: View {
    @Environment(WineStore.self) private var wine
    let bottle: Bottle
    let onDeleted: () -> Void
    /// Called with the new bottle's id after a successful duplicate (the sidebar selects it).
    var onDuplicated: (Bottle.ID) -> Void = { _ in }
    @State private var isConfirmingDelete = false
    @State private var isDuplicating = false
    @State private var isRenaming = false
    @State private var isRunningCommand = false
    /// A new name that leaves the "Steam" bottle, waiting for confirmation.
    @State private var steamRename: String?
    /// A change that closes the bottle's programs, waiting for confirmation.
    @State private var pendingChange: PendingChange?
    @State private var verbs = ""

    var body: some View {
        let programs = wine.programs[bottle.id] ?? []
        Form {
            Section("Programas") {
                if programs.isEmpty {
                    Text("Nenhum atalho encontrado nesta garrafa.").foregroundStyle(.secondary)
                }
                ForEach(programs) { program in
                    HStack {
                        Label { Text(program.name) } icon: { ProgramIconView(program: program, bottle: bottle, size: 20) }
                        Spacer()
                        LauncherButton(program: program, bottle: bottle)
                        Button("Abrir") { wine.open(program, in: bottle) }
                    }
                }
                Button { wine.chooseInstaller(into: bottle.id) } label: {
                    Label("Executar instalador…", systemImage: "square.and.arrow.down")
                }
            }

            Section("Configuração") {
                Picker("Versão do Windows", selection: Binding(
                    get: { bottle.windowsVersion },
                    set: { version in Task { await wine.setWindowsVersion(version, for: bottle) } }
                )) {
                    ForEach(Bottle.WindowsVersion.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Gráficos (Direct3D)", selection: Binding(
                    get: { bottle.graphics },
                    set: { backend in Task { await wine.setGraphics(backend, for: bottle) } }
                )) {
                    ForEach(wine.graphicsBackends, id: \.self) { Text($0.title).tag($0) }
                }
                .help("DXVK e DXMT costumam ser mais rápidos em jogos Direct3D 10/11. O DXVK é baixado na primeira vez (2,8 MB); o DXMT vem com o motor do WinHub.")
                if wine.supportsMSync {
                    Toggle("Sincronização rápida (MSync)", isOn: Binding(
                        get: { bottle.msync },
                        set: { enabled in
                            if wine.msyncChangeClosesPrograms(enabled, for: bottle) {
                                pendingChange = .msync(enabled)
                            } else {
                                Task { await wine.setMSync(enabled, for: bottle) }
                            }
                        }
                    ))
                    .help("Reduz o custo de sincronização do Wine em jogos. Vale na próxima vez que um programa abrir; com a garrafa aberta, os programas dela são fechados para aplicar.")
                }
                if wine.supportsNVIDIAExtensions {
                    Toggle("Recursos da NVIDIA (DLSS pelo MetalFX)", isOn: Binding(
                        get: { bottle.nvidiaExtensions },
                        set: { wine.setNVIDIAExtensions($0, for: bottle) }
                    ))
                    .help("Com o DXMT, faz os jogos verem uma placa NVIDIA e usarem o DLSS por cima do MetalFX. Deixe desligado se um jogo passar a falhar. Vale na próxima vez que um programa abrir.")
                }
                Toggle("Resoluções extras (16:9 e outras)", isOn: Binding(
                    get: { bottle.extraDisplayModes },
                    set: { enabled in
                        if wine.activeBottles.contains(bottle.id) {
                            pendingChange = .displayModes(enabled)
                        } else {
                            Task { await wine.setExtraDisplayModes(enabled, for: bottle) }
                        }
                    }
                ))
                .help("Deixa os jogos escolherem resoluções que o Mac não tem, como 1280×720 (até o tamanho da tela). O Wine simula a troca em vez de recusá-la. Com a garrafa aberta, os programas dela são fechados para aplicar.")
                Toggle("Mostrar desempenho (FPS) nos jogos", isOn: Binding(
                    get: { bottle.performanceHUD },
                    set: { wine.setPerformanceHUD($0, for: bottle) }
                ))
                .help("Mostra o painel de desempenho do Metal (e o do DXVK, se ele estiver em uso).")
                LabeledContent("Motor", value: wine.runtime?.manifest.version ?? bottle.runtimeID)
                LabeledContent("Em execução", value: wine.activeBottles.contains(bottle.id) ? String(localized: "Sim") : String(localized: "Não"))
            }

            Section {
                let choices = wine.graphicsBackends.filter { $0 != .wined3d && $0 != .auto }
                ForEach(bottle.programGraphics.keys.sorted(), id: \.self) { program in
                    HStack {
                        Label(program.split(separator: "\\").last.map(String.init) ?? program, systemImage: "gamecontroller")
                            .help(program)
                        Spacer()
                        Picker("Gráficos", selection: Binding(
                            get: { bottle.programGraphics[program] ?? .dxvk },
                            set: { backend in Task { await wine.setProgramGraphics(backend, program: program, in: bottle) } }
                        )) {
                            ForEach(choices, id: \.self) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button { Task { await wine.setProgramGraphics(nil, program: program, in: bottle) } } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Voltar aos gráficos da garrafa")
                    }
                }
                Button { Task { await wine.chooseProgramForGraphics(in: bottle) } } label: {
                    Label("Escolher programa…", systemImage: "plus")
                }
            } header: {
                Text("Gráficos por programa")
            } footer: {
                Text("Vale só para o .exe escolhido, como um jogo da Steam. O resto da garrafa (a própria Steam, por exemplo) continua com a opção acima.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    TextField("Componentes", text: $verbs, prompt: Text("ex.: vcrun2022 corefonts"))
                    Button("Instalar") {
                        let text = verbs
                        verbs = ""
                        Task { await wine.installDependenciesFromUI(text, in: bottle) }
                    }
                    .disabled(verbs.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Componentes do Windows")
            } footer: {
                Text(wine.hasCabextract
                     ? "Instalados com o winetricks (baixado na primeira vez, com o cabextract)."
                     : "Instalados com o winetricks (baixado na primeira vez). Alguns componentes exigem o cabextract.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Manutenção") {
                Button { wine.revealDriveC(bottle) } label: { Label("Mostrar o disco C: no Finder", systemImage: "folder") }
                Button { wine.revealLogs(bottle) } label: { Label("Abrir os logs", systemImage: "doc.text.magnifyingglass") }
                Menu {
                    ForEach(WineTool.allCases, id: \.self) { tool in
                        Button { wine.openTool(tool, in: bottle) } label: { Label(tool.title, systemImage: tool.systemImage) }
                    }
                } label: {
                    Label("Ferramentas do Wine", systemImage: "wrench.and.screwdriver")
                }
                .help("Abre os programas do próprio Wine (configuração, registro, painel de controle…) nesta garrafa.")
                Button { isRunningCommand = true } label: { Label("Executar comando…", systemImage: "play.rectangle") }
                    .help("Roda uma vez qualquer programa do Windows nesta garrafa, com argumentos, pasta de trabalho e variáveis.")
                Button { Task { await wine.shutdown(bottle) } } label: {
                    Label("Encerrar todos os programas", systemImage: "stop.circle")
                }
                Button { Task { await wine.exportBottle(bottle) } } label: {
                    Label("Exportar garrafa…", systemImage: "square.and.arrow.up")
                }
                .help("Salva a garrafa inteira num arquivo .winhubbottle, para backup ou para levar a outro Mac.")
                Button { isRenaming = true } label: {
                    Label("Renomear garrafa…", systemImage: "pencil")
                }
                .help("Muda o nome da garrafa e da pasta dos atalhos .app. Os programas não precisam ser fechados.")
                Button { isDuplicating = true } label: {
                    Label("Duplicar garrafa…", systemImage: "plus.square.on.square")
                }
                .help("Cria uma cópia da garrafa com os programas e as configurações. Os atalhos .app não são copiados.")
                Button(role: .destructive) { isConfirmingDelete = true } label: {
                    Label("Apagar garrafa…", systemImage: "trash")
                }
            }
        }
        .formStyle(.grouped)
        // Pinned above the scrolling form so a long operation stays visible wherever the page is scrolled.
        .safeAreaInset(edge: .top, spacing: 0) {
            if let status = wine.activity[bottle.id.uuidString] {
                ProgressView { Text(status) }
                    .progressViewStyle(.linear)
                    .padding()
                    .background(.bar)
            }
        }
        .navigationTitle(bottle.name)
        .navigationSubtitle(bottle.windowsVersion.title)
        .confirmationDialog("Apagar a garrafa “\(bottle.name)”?", isPresented: $isConfirmingDelete) {
            Button("Apagar garrafa e programas", role: .destructive) {
                Task {
                    await wine.delete(bottle)
                    onDeleted()
                }
            }
        } message: {
            Text("Todos os programas e arquivos dentro dela serão apagados. Esta ação não pode ser desfeita.")
        }
        .sheet(isPresented: $isRenaming) {
            RenameBottleSheet(bottle: bottle) { name in
                if SteamClient.isRenamedClientBottle(original: bottle.name,
                                                     imported: name.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    steamRename = name
                } else {
                    wine.rename(bottle, to: name)
                }
            }
        }
        .confirmationDialog("Renomear a garrafa “\(bottle.name)”?", isPresented: Binding(
            get: { steamRename != nil },
            set: { if !$0 { steamRename = nil } }
        )) {
            Button("Renomear mesmo assim") {
                if let name = steamRename { wine.rename(bottle, to: name) }
                steamRename = nil
            }
            Button("Cancelar", role: .cancel) { steamRename = nil }
        } message: {
            Text("O catálogo e os jogos da Steam usam só a garrafa “Steam”. Renomear mesmo assim?")
        }
        .sheet(isPresented: $isRunningCommand) {
            RunCommandSheet(bottle: bottle)
        }
        .sheet(isPresented: $isDuplicating) {
            DuplicateBottleSheet(bottle: bottle) { name in
                if wine.activeBottles.contains(bottle.id) {
                    pendingChange = .duplicate(name)
                } else {
                    duplicate(as: name)
                }
            }
        }
        .confirmationDialog("Fechar os programas desta garrafa?", isPresented: Binding(
            get: { pendingChange != nil },
            set: { if !$0 { pendingChange = nil } }
        )) {
            if case .duplicate(let name) = pendingChange {
                Button("Encerrar e continuar") {
                    pendingChange = nil
                    duplicate(as: name)
                }
            } else {
                Button("Encerrar e aplicar") {
                    switch pendingChange {
                    case .msync(let enabled): Task { await wine.setMSync(enabled, for: bottle) }
                    case .displayModes(let enabled): Task { await wine.setExtraDisplayModes(enabled, for: bottle) }
                    case .duplicate, nil: break
                    }
                    pendingChange = nil
                }
            }
            Button("Cancelar", role: .cancel) { pendingChange = nil }
        } message: {
            if case .duplicate = pendingChange {
                Text("Para duplicar, a garrafa precisa estar encerrada. Salve o que estiver aberto antes de continuar.")
            } else {
                Text("Esta opção só muda com a garrafa encerrada. Salve o que estiver aberto antes de continuar.")
            }
        }
    }

    private func duplicate(as name: String) {
        Task {
            await wine.duplicate(bottle, name: name) { onDuplicated($0.id) }
        }
    }

    enum PendingChange {
        case msync(Bool)
        case displayModes(Bool)
        case duplicate(String)
    }
}

/// New name for a bottle, starting from the current one.
struct RenameBottleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bottle: Bottle
    let onRename: (String) -> Void
    @State private var name = ""

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Form {
            TextField("Nome", text: $name)
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .top) { SheetHeader(title: "Renomear garrafa", systemImage: "pencil") }
        .frame(width: 380)
        .onAppear { name = bottle.name }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Renomear") {
                    let name = name
                    dismiss()
                    onRename(name)
                }
                .disabled(trimmed.isEmpty || trimmed == bottle.name)
            }
        }
    }
}

/// Name for the copy of a bottle; suggests a free one.
struct DuplicateBottleSheet: View {
    @Environment(WineStore.self) private var wine
    @Environment(\.dismiss) private var dismiss
    let bottle: Bottle
    let onDuplicate: (String) -> Void
    @State private var name = ""

    var body: some View {
        Form {
            TextField("Nome", text: $name)
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .top) { SheetHeader(title: "Duplicar garrafa", systemImage: "plus.square.on.square") }
        .frame(width: 380)
        .onAppear { name = wine.suggestedCopyName(for: bottle) }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Duplicar") {
                    let name = name
                    dismiss()
                    onDuplicate(name)
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

/// Runs any Windows program once in a bottle.
struct RunCommandSheet: View {
    @Environment(WineStore.self) private var wine
    @Environment(\.dismiss) private var dismiss
    let bottle: Bottle
    @State private var file: URL?
    @State private var arguments = ""
    @State private var workingDirectory = ""
    @State private var variables = ""

    private var parsedVariables: Result<[String: String], EnvironmentLines.InvalidLine> {
        EnvironmentLines.parse(variables)
    }

    private var defaultFolder: String {
        file.map(bottle.defaultWorkingDirectory(forFile:)) ?? ""
    }

    var body: some View {
        Form {
            LabeledContent("Programa") {
                HStack {
                    Text(file?.lastPathComponent ?? String(localized: "Nenhum"))
                        .foregroundStyle(file == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Escolher…") { if let url = wine.chooseCommandFile(in: bottle) { file = url } }
                }
            }
            TextField("Argumentos", text: $arguments, prompt: Text("ex.: -windowed \"C:\\Meus Jogos\""))
            TextField("Pasta de trabalho", text: $workingDirectory, prompt: Text(defaultFolder))
            Section {
                TextEditor(text: $variables)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 70)
            } header: {
                Text("Variáveis de ambiente")
            } footer: {
                if case .failure(let invalid) = parsedVariables {
                    Text("Linha inválida: \(invalid.line). Use NOME=valor, uma por linha.")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("Uma por linha, no formato NOME=valor. Valem só para esta execução e vencem as da garrafa.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .top) { SheetHeader(title: "Executar comando", systemImage: "play.rectangle") }
        .frame(width: 460)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Executar") {
                    guard let file, case .success(let environment) = parsedVariables else { return }
                    let folder = workingDirectory.trimmingCharacters(in: .whitespaces)
                    dismiss()
                    wine.runCommand(file, arguments: ArgumentSplitter.split(arguments),
                                    workingDirectory: folder.isEmpty ? defaultFolder : folder,
                                    environment: environment, in: bottle)
                }
                .disabled(file == nil || (try? parsedVariables.get()) == nil)
            }
        }
    }
}

struct NewBottleSheet: View {
    @Environment(WineStore.self) private var wine
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var version = Bottle.WindowsVersion.win10
    /// `nil` is "Personalizado": only the Windows version below.
    @State private var template: BottleTemplate?

    var body: some View {
        Form {
            TextField("Nome", text: $name, prompt: Text("Ex.: Jogos"))
            Picker("Modelo", selection: $template) {
                Text("Personalizado").tag(BottleTemplate?.none)
                ForEach(BottleTemplate.all) { Text($0.title).tag(BottleTemplate?.some($0)) }
            }
            .onChange(of: template) { _, new in
                if let new { version = new.windowsVersion }
            }
            if let template {
                Text(template.help)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker("Versão do Windows", selection: $version) {
                ForEach(Bottle.WindowsVersion.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .top) { SheetHeader(title: "Nova garrafa", systemImage: "shippingbox") }
        .frame(width: 380)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Criar") {
                    let (name, version, template) = (name, version, template)
                    dismiss()
                    Task { await wine.createBottle(name: name, windowsVersion: version, template: template) }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

/// Bottle choice for a user-picked installer.
struct InstallSheet: View {
    @Environment(WineStore.self) private var wine
    @Environment(\.dismiss) private var dismiss
    let pending: WineStore.PendingInstall
    @State private var bottleID: Bottle.ID?
    @State private var newName = ""
    @State private var version = Bottle.WindowsVersion.win10

    var body: some View {
        Form {
            LabeledContent("Instalador", value: pending.file.lastPathComponent)
            Picker("Garrafa", selection: $bottleID) {
                Text("Nova garrafa").tag(Bottle.ID?.none)
                ForEach(wine.bottles) { Text($0.name).tag(Bottle.ID?.some($0.id)) }
            }
            if bottleID == nil {
                TextField("Nome da nova garrafa", text: $newName)
                Picker("Versão do Windows", selection: $version) {
                    ForEach(Bottle.WindowsVersion.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
            Text("Execute apenas instaladores de fontes em que você confia.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .top) { SheetHeader(title: "Instalar app não listado", systemImage: "square.and.arrow.down") }
        .frame(width: 420)
        .onAppear {
            bottleID = pending.bottleID
            newName = pending.file.deletingPathExtension().lastPathComponent
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Instalar") {
                    let target = wine.bottle(id: bottleID)
                    let (file, name, version) = (pending.file, newName, version)
                    dismiss()
                    Task { await wine.installUnlisted(file, into: target, newBottleName: name, windowsVersion: version) }
                }
                .disabled(bottleID == nil && newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

/// Creates (or shows) the program's `.app` launcher in ~/Applications/WinHub.
struct LauncherButton: View {
    @Environment(WineStore.self) private var wine
    let program: InstalledProgram
    let bottle: Bottle

    var body: some View {
        if wine.hasLauncher(for: program, in: bottle) {
            Button("Mostrar atalho") { wine.revealLauncher(for: program, in: bottle) }
                .help("Mostrar o atalho em Aplicativos › WinHub. Arraste-o para o Dock para abrir com um clique.")
        } else {
            Button("Criar atalho") { wine.createLauncher(for: program, in: bottle) }
                .help("Cria um app em Aplicativos › WinHub que abre este programa pelo Finder, Spotlight ou Dock.")
        }
    }
}

struct SheetHeader: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.title3.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .top], 20)
    }
}

/// Explains and downloads the Wine runtime.
struct RuntimeSetupView: View {
    @Environment(WineStore.self) private var wine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(wine.runtimeUpgrade == nil ? "Baixar o Wine" : "Atualizar o Wine",
                  systemImage: "shippingbox.and.arrow.backward").font(.title2.bold())
            Text("Para rodar programas do Windows, o WinHub usa o Wine, um projeto de código aberto. Ele é baixado uma vez, direto da fonte oficial, e conferido antes de ser instalado.")
                .fixedSize(horizontal: false, vertical: true)

            if let manifest = wine.manifest {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow { Text("Versão").foregroundStyle(.secondary); Text("\(manifest.name) \(manifest.version)") }
                    GridRow {
                        Text("Tamanho").foregroundStyle(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: manifest.downloadSize, countStyle: .file))
                    }
                    GridRow { Text("Licença").foregroundStyle(.secondary); Text(manifest.license) }
                    GridRow {
                        Text("Código-fonte").foregroundStyle(.secondary)
                        Link(manifest.sourceURL.host() ?? manifest.sourceURL.absoluteString, destination: manifest.sourceURL)
                    }
                }
            }

            if RuntimeManager.isAppleSilicon {
                Text("Neste Mac, o Wine roda pelo Rosetta 2 da Apple. A Apple mantém o Rosetta para todos os apps até o macOS 27; a partir do macOS 28 ele fica restrito a jogos antigos, e o WinHub vai precisar de um Wine nativo para Apple silicon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !wine.isRosettaAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Este Mac precisa do Rosetta 2, da Apple, para rodar o Wine.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Button(wine.isInstallingRosetta ? "Instalando o Rosetta…" : "Instalar o Rosetta") {
                        Task { await wine.installRosetta() }
                    }
                    .disabled(wine.isInstallingRosetta)
                    Text("O macOS pede a senha de administrador.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if let progress = wine.runtimeProgress {
                ProgressView(value: progress) {
                    Text(progress < 1 ? "Baixando… \(Int(progress * 100))%" : "Conferindo e instalando…")
                }
            }

            HStack {
                Spacer()
                Button("Agora não") { dismiss() }
                Button("Baixar e instalar") { Task { await wine.installRuntime() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(wine.runtimeProgress != nil || wine.manifest == nil || !wine.isRosettaAvailable)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
