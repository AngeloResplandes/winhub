# AGENTS.md — guia para agentes de código

WinHub é um app nativo para macOS (SwiftUI) que encontra, instala e roda programas do Windows usando o
Wine. Projeto **público e independente** (MIT). Leia este arquivo inteiro antes de mudar algo.

## Regras que não podem ser quebradas

1. **Sala limpa.** Não copie código, scripts, textos, traduções, ícones, dados ou bancos de
   compatibilidade de produtos comerciais, em especial do CrossOver (CodeWeavers). Não adicione ao
   repositório resultados de engenharia reversa (código descompilado, endereços, símbolos internos).
   Use só documentação pública (WineHQ, Apple, projetos abertos). Detalhes em `CONTRIBUTING.md`.
2. **Nenhum binário de terceiros no repositório.** Wine, DXVK, winetricks e instaladores são baixados
   em tempo de execução, da fonte oficial, e conferidos por SHA-256 (manifestos em `Sources/WinHub/Resources/`).
   `dist/` e `.build/` ficam fora do Git.
3. **D3DMetal / Game Porting Toolkit da Apple: não usar nem redistribuir** (licença da Apple, e não
   funciona com o Wine oficial).
4. **Marcas** (Windows, Mac, Steam, CrossOver) só de forma nominativa, sem logotipos.
5. Ao adicionar um componente baixável, atualize `THIRD_PARTY_NOTICES.md`.

## Comandos

```bash
swift build                 # compilar
swift test                  # 65 testes (unitários; os com Wine real ficam desligados)
swift run WinHub            # rodar sem empacotar (atalhos .app e links winhub:// não funcionam assim)
./scripts/package-app.sh    # gera dist/WinHub.app (universal) e dist/WinHub.zip, assinatura ad-hoc;
                            # compila o wrapper da Steam (precisa de: brew install mingw-w64)
./scripts/build-steam-wrapper.sh   # só o wrapper, em .build/; para usar a Steam com swift run:
WINHUB_STEAMWEBHELPER_WRAPPER=.build/steamwebhelper-wrapper.exe swift run WinHub
open Package.swift          # abrir no Xcode
```

Testes com o Wine de verdade (precisam do Wine já baixado pelo app em `~/Library/Application Support/WinHub/Runtimes`):

```bash
RUN_WINE_TESTS=1 WINHUB_DXVK_ARCHIVE=/caminho/dxvk.tar.gz WINHUB_WINETRICKS=/caminho/winetricks \
  swift test --filter ComponentIntegrationTests
```

## Arquitetura

```
Sources/WinHubCore/      dados puros, sem UI e sem processos (testável)
  CatalogEntry, Rating, Recipe(+SteamClient), CatalogLoader(JSONCatalog),
  CatalogSearchEngine, WildcardMatcher
Sources/WinHubRuntime/   tudo que toca disco, rede e processos do Wine
  RuntimeManifest/RuntimeManager   baixa, confere e instala o motor Wine
  Bottle/BottleStore                garrafa = pasta com bottle.json + prefix/ (WINEPREFIX)
  WineEnvironment                   monta o ambiente dos processos Wine (função pura)
  WineLauncher                      wineboot, winecfg, instaladores, start /unix, wineserver -k
  ProgramScanner                    encontra .lnk no Menu Iniciar/Área de Trabalho da garrafa
  WineServerStatus                  "garrafa em execução" = alguém segura o `lock` do wineserver
  WineOrphanReaper                  encerra processos órfãos de um wineserver que morreu
  Components                        DXVK e winetricks (ComponentManager) + GraphicsBackend
  AppLauncherBuilder                atalhos ~/Applications/WinHub/<garrafa>/<programa>.app
  SteamWebHelperWrapper             põe o wrapper no lugar do steamwebhelper.exe da Steam
  Downloader, ProcessRunner         utilitários
Sources/WinHub/          app SwiftUI
  WinHubApp (cenas, menus, Ajustes, onOpenURL), RootView (barra lateral + folhas),
  CatalogStore (@Observable, catálogo e busca), WineStore (@Observable, motor/garrafas/tarefas),
  CatalogView, EntryViews (cards, detalhe, ações Instalar/Abrir), BottleViews (garrafas, programas, folhas)
  Resources/: catalog.json, runtimes.json, components.json
Support/steamwebhelper-wrapper/  programa do Windows (C, MIT) compilado pelo package-app.sh com mingw-w64
```

Dependências: `WinHub` → `WinHubCore` + `WinHubRuntime`. Core e Runtime não dependem um do outro nem da UI.

Dados do usuário: `~/Library/Application Support/WinHub/{Runtimes,Components,Bottles}`,
`~/Library/Caches/WinHub/Downloads`, atalhos em `~/Applications/WinHub/`.

## Fluxos principais

- **Motor:** `runtimes.json` → `RuntimeManager.install` (download → SHA-256 → `tar` → marcador
  `.winhub-runtime.json` gravado por último). Hoje: WineHQ `wine-devel-11.18-osx64` (x86_64, precisa de Rosetta 2).
- **Garrafa nova:** `BottleStore.create` → `WineLauncher.initialize` (`wineboot --init` com Mono/Gecko
  desligados → `winecfg /v <versão>` → `wineserver -k`/`-w`).
- **Receita** (`Recipe` no catálogo): garrafa por nome (reutiliza se existir) → dependências via
  winetricks → baixa instalador → `runInstaller` → confere `launch.windowsPath` → abre.
- **Abrir programa:** `WineStore.launch` dispara e não espera; o estado "em execução" vem do
  `WineServerStatus`, não do processo iniciado (a Steam se reinicia sozinha).
- **Atalhos `.app`:** o script do atalho só faz `open "winhub://open?bottle=<uuid>&shortcut=<path>"`;
  o `WineStore.handle(_:)` valida que o `.lnk` está dentro do `drive_c` da garrafa e o abre.

## Decisões e armadilhas (aprendidas na prática)

- **Motor = Wine oficial do WineHQ.** O WineCX 24 (build aberto do código da CodeWeavers) quebra a Steam
  no macOS 27: o sistema devolve vazia a lista de conexões TCP (`net.inet.tcp.pcblist`) para apps comuns,
  e a Steam rejeita o `steamwebhelper` ("Erro de transporte inesperado"). O Wine ≥ 9.17 monta essa tabela
  no wineserver e funciona. Não volte para um motor sem essa correção.
- **Janela preta da Steam (Wine 11 no macOS).** A interface da Steam é um Chromium (`steamwebhelper.exe`)
  que desenha cada janela a partir de outro processo (o de GPU); o driver de macOS do Wine 11 não mostra o
  que um processo desenha na janela de outro, então tudo fica preto (com ou sem GPU). Correção: o
  `SteamWebHelperWrapper` troca o `steamwebhelper.exe` por `Support/steamwebhelper-wrapper` (o original vira
  `steamwebhelper_real.exe`), que o abre com `--in-process-gpu`; `WINHUB_CEF_FLAGS` substitui as opções
  para testes. A troca é feita só antes de cada abertura (a Steam repõe o helper ao se atualizar); com a
  Steam rodando ela é sempre desfeita, porque a Steam se reinicia **sem argumentos** depois de se
  atualizar e então confere os arquivos (uma troca periódica chegou a gerar um laço de reinícios).
  Com o wrapper instalado, a abertura leva `-noverifyfiles` (`SteamClient.launchArguments(wrapperInstalled:)`;
  no `.lnk`, `start /unix Steam.lnk -noverifyfiles` repassa a opção), senão ela detecta o tamanho
  diferente e restaura o original. **Sem wrapper (primeira abertura após instalar) não use a opção:** o
  instalador pula a etapa que baixa o cliente e fica parado. Por isso a primeira sessão depois de instalar
  fica preta; da segunda em diante funciona (testado numa garrafa nova). Todo build do wrapper contém
  `SteamWebHelperWrapper.marker`, para um wrapper antigo nunca ser tomado pelo helper da Steam (ele se
  abriria em laço). Não funcionam: as opções `-cef-*` da Steam (ela não as repassa), `renderer=vulkan`
  no wined3d (a janela nem aparece) e o DXVK (o D3D11 funciona, mas a janela continua preta). Não há
  mais builds oficiais do Wine 10 para macOS. Com `swift run` o wrapper só existe se
  `WINHUB_STEAMWEBHELPER_WRAPPER` apontar para ele (`scripts/build-steam-wrapper.sh`); sem isso, janela preta.
- **Nunca rode o Wine de dentro do processo de um atalho `.app`.** Programas iniciados assim travam (a
  Steam fica parada em "Verifying…"). Por isso os atalhos delegam ao WinHub via `winhub://`.
- **Processos órfãos de wineserver morto.** Se o wineserver morre sem encerrar os clientes (ex.: SIGKILL),
  o `winedevice.exe` do `winebus.sys` fica vivo para sempre (laço do IOHID que nunca fala com o servidor;
  o Wine trata SIGTERM encerrando só uma thread). O próximo wineserver reusa a pasta
  `/tmp/.wine-<uid>/server-<dev>-<inode>/` e o `-k` dele não alcança os órfãos. O `WineOrphanReaper` os
  encerra (SIGKILL) quando ninguém segura o `lock` da pasta; roda após `shutdown` e antes de cada `launch`.
  Use o `lock`, não o `socket`, para saber se o servidor vive: um servidor morto com SIGKILL deixa o socket.
- **`WINEDEBUG` padrão é `fixme-all`** (`err` não esconde os "fixme" e enche os logs).
- **Ambiente isolado:** `WineEnvironment` só herda `HOME, USER, LOGNAME, LANG, LC_ALL, TMPDIR, SHELL`;
  sempre define `ROSETTA_ADVERTISE_AVX=1` e `DOTNET_EnableWriteXorExecute=0`. Configurações da garrafa vencem.
- **DXVK-macOS** só tem `d3d10core` e `d3d11` (o `dxgi` é do Wine). DXVK → overrides `n,b`; voltar ao
  Wine → `b` (não precisa restaurar arquivos).
- **MSync** é exclusivo do Wine da CodeWeavers; o Wine oficial não tem.
- **winetricks:** alguns verbos exigem `cabextract`, que não vem no macOS.
- **Compatibilidade com Swift 6.1 (Xcode 16.4, usado no CI):** closures `async` passados a métodos de
  classes `@MainActor` precisam ser marcados `@MainActor` (ou ter resultado `Sendable`). O Swift local
  pode ser mais novo e não acusar; o CI acusa.
- `@State`, `#Preview` e `@Previewable` exigem Xcode (o plugin de macros não vem nas Command Line Tools).

## Convenções

- **Interface em português do Brasil**; código, identificadores e comentários em inglês.
- Comentários curtos, só onde o "porquê" não é óbvio (siga a densidade do código vizinho).
- Modelos `Codable` novos: use `decodeIfPresent` com padrão para manter compatibilidade com JSON antigo
  (`bottle.json`, catálogos de usuários).
- Testes com **Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect`). Testes que precisam do
  Wine real ficam atrás de `RUN_WINE_TESTS=1`.
- Prefira lógica pura e testável no Core/Runtime; a UI só orquestra pelo `WineStore`/`CatalogStore`.
- Instaladores e componentes: só URLs oficiais; SHA-256 obrigatório para componentes, opcional para
  instaladores que o fabricante atualiza no mesmo endereço (ex.: `SteamSetup.exe`).

## CI e publicação

- `.github/workflows/ci.yml`: build + testes + empacotamento a cada push/PR (runner `macos-15`, Xcode 16.4).
- `.github/workflows/release.yml`: tag `v*` publica `WinHub.zip`; assina/notariza se os segredos do
  Developer ID existirem (lista no próprio arquivo).
- Commits: mensagens em inglês, no imperativo. O autor do repositório usa o e-mail noreply do GitHub.

## Próximos passos possíveis

- Ícones reais dos programas (extrair do `.exe`) nos cards e atalhos.
- Mais receitas testadas no catálogo; catálogo comunitário versionado.
- Motor alternativo compilado do código LGPL da CodeWeavers (traria MSync e permitiria avaliar D3DMetal).
- Instalação/edição de dependências por receita com `cabextract` embutido (licença compatível).
