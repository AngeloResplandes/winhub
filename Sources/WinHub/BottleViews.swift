import SwiftUI
import WinHubRuntime

/// Icon tile for a Windows program.
struct ProgramTile: View {
    let program: InstalledProgram
    let bottleName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.blue.gradient)
                    .overlay { Image(systemName: "macwindow").font(.title2).foregroundStyle(.white) }
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(program.name).font(.headline).lineLimit(2)
                    if let bottleName {
                        Text(bottleName).font(.caption).foregroundStyle(.secondary)
                    }
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
                    ProgramTile(program: program, bottleName: bottle.name) { wine.open(program, in: bottle) }
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
    @State private var isConfirmingDelete = false
    @State private var verbs = ""

    var body: some View {
        let programs = wine.programs[bottle.id] ?? []
        Form {
            if let status = wine.activity[bottle.id.uuidString] {
                Section { ProgressView { Text(status) }.progressViewStyle(.linear) }
            }

            Section("Programas") {
                if programs.isEmpty {
                    Text("Nenhum atalho encontrado nesta garrafa.").foregroundStyle(.secondary)
                }
                ForEach(programs) { program in
                    HStack {
                        Label(program.name, systemImage: "macwindow")
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
                        set: { wine.setMSync($0, for: bottle) }
                    ))
                    .help("Reduz o custo de sincronização do Wine em jogos. Vale na próxima vez que um programa abrir.")
                }
                Toggle("Mostrar desempenho (FPS) nos jogos", isOn: Binding(
                    get: { bottle.performanceHUD },
                    set: { wine.setPerformanceHUD($0, for: bottle) }
                ))
                .help("Mostra o painel de desempenho do Metal (e o do DXVK, se ele estiver em uso).")
                LabeledContent("Motor", value: wine.runtime?.manifest.version ?? bottle.runtimeID)
                LabeledContent("Em execução", value: wine.activeBottles.contains(bottle.id) ? "Sim" : "Não")
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
                Button { Task { await wine.shutdown(bottle) } } label: {
                    Label("Encerrar todos os programas", systemImage: "stop.circle")
                }
                Button(role: .destructive) { isConfirmingDelete = true } label: {
                    Label("Apagar garrafa…", systemImage: "trash")
                }
            }
        }
        .formStyle(.grouped)
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
    }
}

struct NewBottleSheet: View {
    @Environment(WineStore.self) private var wine
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var version = Bottle.WindowsVersion.win10

    var body: some View {
        Form {
            TextField("Nome", text: $name, prompt: Text("Ex.: Jogos"))
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
                    let (name, version) = (name, version)
                    dismiss()
                    Task { await wine.createBottle(name: name, windowsVersion: version) }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
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
    let title: String
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
