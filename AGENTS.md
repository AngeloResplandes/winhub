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
3. **D3DMetal / Game Porting Toolkit da Apple: nunca redistribuir** (licença da Apple). Só é usado
   quando o próprio usuário põe a pasta `redist/lib` do toolkit em
   `~/Library/Application Support/WinHub/D3DMetal` (`D3DMetal.installed()`), e só com um motor que
   escolhe o Direct3D (feature `backend-dispatch`).
4. **Marcas** (Windows, Mac, Steam, CrossOver) só de forma nominativa, sem logotipos.
5. Ao adicionar um componente baixável, atualize `THIRD_PARTY_NOTICES.md`.

## Comandos

```bash
swift build                 # compilar
swift test                  # 102 testes (unitários; os com Wine real ficam desligados)
swift run WinHub            # rodar sem empacotar (atalhos .app e links winhub:// não funcionam assim)
./scripts/package-app.sh    # gera dist/WinHub.app (universal) e dist/WinHub.zip, assinatura ad-hoc;
                            # compila o wrapper da Steam (precisa de: brew install mingw-w64)
swift scripts/make-icon.swift saida.icns  # desenha o ícone (o package-app.sh já chama)
swift scripts/make-icon.swift docs/icon.svg   # mesmo desenho em SVG, usado no README (rode ao mudar o ícone)
./scripts/build-steam-wrapper.sh   # só o wrapper, em .build/; para usar a Steam com swift run:
WINHUB_STEAMWEBHELPER_WRAPPER=.build/steamwebhelper-wrapper.exe swift run WinHub
open Package.swift          # abrir no Xcode
```

Testes com o Wine de verdade (precisam do Wine já baixado pelo app em `~/Library/Application Support/WinHub/Runtimes`):

```bash
RUN_WINE_TESTS=1 swift test --filter ComponentIntegrationTests   # baixa DXVK e winetricks se faltarem
# WINHUB_DXVK_ARCHIVE/WINHUB_WINETRICKS usam arquivos locais; WINHUB_CABEXTRACT_VERB=corefonts testa o cabextract
# baixa e instala de verdade o 1º motor do runtimes.json (Wine oficial + overlay do winhub-engine) e o cabextract
RUN_WINE_TESTS=1 WINHUB_INSTALL_ENGINE=1 swift test --filter EngineInstallTests
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
  AppUpdater                        acha a release mais nova no GitHub, baixa, confere e troca o .app
  RemoteDataSync                    cópia local dos JSON de Resources/ da branch main
  Downloader, ProcessRunner         utilitários
Sources/WinHub/          app SwiftUI
  WinHubApp (cenas, menus, Ajustes, onOpenURL), RootView (barra lateral + folhas),
  CatalogStore (@Observable, catálogo e busca), WineStore (@Observable, motor/garrafas/tarefas),
  UpdateStore (@Observable, atualizações; OfficialData = JSON baixado ou o do pacote),
  CatalogView, EntryViews (cards, detalhe, ações Instalar/Abrir), BottleViews (garrafas, programas, folhas)
  Resources/: catalog.json, runtimes.json, components.json
scripts/make-icon.swift  ícone do app desenhado em código (CoreGraphics → .icns); sem imagens no Git
Support/steamwebhelper-wrapper/  programa do Windows (C, MIT) compilado pelo package-app.sh com mingw-w64
```

Dependências: `WinHub` → `WinHubCore` + `WinHubRuntime`. Core e Runtime não dependem um do outro nem da UI.

Dados do usuário: `~/Library/Application Support/WinHub/{Runtimes,Components,Bottles,Remote}`,
`~/Library/Caches/WinHub/{Downloads,Updates}`, atalhos em `~/Applications/WinHub/`.

## Fluxos principais

- **Motor:** `runtimes.json` → `RuntimeManager.install` (download → SHA-256 → `tar` → marcador
  `.winhub-runtime.json` gravado por último). Hoje: WineHQ `wine-devel-11.18-osx64` (x86_64, precisa de Rosetta 2).
- **Garrafa nova:** `BottleStore.create` → `WineLauncher.initialize` (`wineboot --init` com Mono/Gecko
  desligados → `winecfg /v <versão>` → `wineserver -k`/`-w`).
- **Receita** (`Recipe` no catálogo): garrafa por nome (reutiliza se existir) → dependências via
  winetricks → baixa instalador → `runInstaller` → confere `launch.windowsPath` → abre.
- **Abrir programa:** `WineStore.launch` dispara e não espera; o estado "em execução" vem do
  `WineServerStatus`, não do processo iniciado (a Steam se reinicia sozinha).
- **Atualizações** (`UpdateStore`, 10 s após abrir e depois a cada hora): (1) `RemoteDataSync` baixa
  `catalog.json`, `runtimes.json` e `components.json` de `raw.githubusercontent.com/<repo>/main/Sources/WinHub/Resources/`
  e só grava em `Application Support/WinHub/Remote/` se decodificar nesta versão do app; o catálogo
  oficial e os manifestos são recarregados (um catálogo importado pelo usuário nunca é trocado). Um
  `runtimes.json` com Wine novo não invalida o instalado (`RuntimeManager.installedRuntimes()`): a barra
  lateral oferece "Atualizar o Wine". (2) `AppUpdater` lê `releases/latest` (com ETag), baixa o
  `WinHub.zip`, confere o SHA-256 do `digest` que o GitHub calcula, valida identificador, versão,
  `codesign --verify` e, com Developer ID, o mesmo TeamIdentifier. "Reiniciar para atualizar" roda um
  `sh` que espera o PID sair, troca o `.app` (desfaz se falhar) e o abre. O repositório vem da chave
  `WinHubUpdateRepository` do Info.plist (`GITHUB_REPOSITORY` no CI). Cada push na `main` gera a release
  `v<VERSION>.<run_number>` (`release.yml`).
- **Atalhos `.app`:** o script do atalho só faz `open "winhub://open?bottle=<uuid>&shortcut=<path>"`;
  o `WineStore.handle(_:)` valida que o `.lnk` está dentro do `drive_c` da garrafa e o abre.

## Decisões e armadilhas (aprendidas na prática)

- **Motor = Wine oficial do WineHQ.** O WineCX 24 (build aberto do código da CodeWeavers) quebra a Steam
  no macOS 27: o sistema devolve vazia a lista de conexões TCP (`net.inet.tcp.pcblist`) para apps comuns,
  e a Steam rejeita o `steamwebhelper` ("Erro de transporte inesperado"). O Wine ≥ 9.17 monta essa tabela
  no wineserver e funciona. Não volte para um motor sem essa correção. O motor r2 (fontes do CrossOver
  26, Wine 11.0) tem a correção (`nsiproxy.sys/tcp.c` pede `get_tcp_connections` ao wineserver), mas a
  Steam precisa ser testada nele antes de ele virar o padrão.
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
- **Atualização do app:** só com o `WinHub.app` empacotado, fora da translocação do Gatekeeper
  (`/AppTranslocation/`) e numa pasta gravável; com `swift run` só os dados se atualizam. Asset sem
  `digest` é ignorado. O zip baixado pelo `URLSession` não ganha o atributo de quarentena, por isso o app
  novo abre sem novo aviso do Gatekeeper. Mudanças nos JSON precisam continuar decodificáveis pelas
  versões anteriores (`decodeIfPresent`), senão os apps antigos ignoram a atualização até se atualizarem.
- **`WINEDEBUG` padrão é `fixme-all`** (`err` não esconde os "fixme" e enche os logs).
- **Ambiente isolado:** `WineEnvironment` só herda `HOME, USER, LOGNAME, LANG, LC_ALL, TMPDIR, SHELL`;
  sempre define `ROSETTA_ADVERTISE_AVX=1` e `DOTNET_EnableWriteXorExecute=0`. Configurações da garrafa vencem.
- **DXVK-macOS** só tem `d3d10core` e `d3d11` (o `dxgi` é do Wine). DXVK/DXMT → overrides `n,b`. Voltar
  ao Wine copia de volta as DLLs do motor (`lib/wine/{x86_64,i386}-windows`; no Wine 11 o `system32` guarda
  cópias exatas delas) e **remove** os overrides; só um motor sem esses arquivos recebe `b`.
- **Catálogo de jogos da Steam:** `steamGame` (`installDir`, `executable`, `graphics`) diz onde o jogo
  fica e qual Direct3D funcionou melhor nos nossos testes. A tela do jogo só oferece o botão
  "Usar … neste jogo"; nada é aplicado sem clique.
- **Resoluções no Mac:** o `winemac.drv` só lista os modos do macOS (sem 16:9) e só troca o modo com o app
  em primeiro plano. Veja `docs/compat/hollow-knight.md`.
- **Gráficos por programa** (`Bottle.programGraphics`, `applyProgramGraphics`): as DLLs vão para a pasta
  do `.exe` (64 ou 32 bits pelo cabeçalho PE) e os overrides para
  `HKCU\Software\Wine\AppDefaults\<exe>\DllOverrides`. O `WINEDLLOVERRIDES` do ambiente vence o
  registro, por isso a garrafa não pode forçar `b` nessas DLLs. Só são apagadas DLLs idênticas às que o
  WinHub copiou; se o jogo traz a própria, a troca é recusada.
- **wined3d no macOS só chega ao D3D feature level 9_3** (OpenGL 4.1). Jogos Unity 6 em D3D11 (ex.:
  Hollow Knight) falham ao criar o dispositivo. Precisam de DXVK ou DXMT (`docs/compat/`).
- **Motor `winhub-engine` r2 (feature `backend-dispatch`):** Wine 11 das fontes LGPL do CrossOver
  (com msync e os ganchos de Metal que o DXMT e o D3DMetal usam) instalado como **overlay** sobre o
  pacote oficial do WineHQ: `overlay.replace` (`["bin", "lib/wine"]`) apaga essas pastas do pacote antes
  de desempacotar, e o resto dele (bibliotecas, wine-mono, wine-gecko) fica. O `winhubcompat.so` do motor
  escolhe o Direct3D de cada processo por `WINHUB_GRAPHICS_BACKEND` (`auto`, `wined3d`, `dxmt`, `dxvk`,
  `d3dmetal`) e põe a pasta dele (`lib/dxmt`, `lib/dxvk` ou o D3DMetal do usuário) no começo do caminho de
  DLLs do Wine: **nada é copiado** para a garrafa e os overrides `n,b` não são usados. Jogos com Direct3D
  próprio viram regras em `<garrafa>/compat-rules.json` (`CompatRules`, `WINHUB_COMPAT_RULES`). Garrafas
  da época em que o WinHub copiava DLLs são migradas antes de abrir um programa
  (`migrateToDispatchedGraphics`): as DLLs do Wine voltam e as cópias e overrides saem.
- **Banco de compatibilidade do motor:** `CompatDatabaseSync` (na verificação periódica do `UpdateStore`)
  baixa `data/compatdb.json` e `compatdb.json.sig` da `main` do winhub-engine, confere a assinatura
  Ed25519 com a chave embutida (`CompatDatabaseSync.publicKey`) e só grava em
  `Application Support/WinHub/compat/compatdb.json` um banco com `timestamp` maior que o atual. A chave
  privada fica fora dos repositórios (`~/.winhub-signing/` do mantenedor; veja `docs/compatdb.md` no
  winhub-engine). Trocar a chave exige uma versão nova do app.
- **D3DMetal:** a pasta vem dos Ajustes (`D3DMetal.location`, padrão `Application Support/WinHub/D3DMetal`);
  o seletor aceita a pasta do Game Porting Toolkit ou a `redist/lib` dele (`D3DMetal.resolve`).
- **Motores antigos (r1, sem `backend-dispatch`):** o DXMT vem como DLLs nativas em `lib/dxmt/{x64,x32}`,
  copiadas por `applyGraphics(.dxmt)`, e o DXVK-macOS vem do componente. Esse caminho continua no código
  para quem ainda usa esses motores. `.auto` e `.d3dmetal` não existem neles.
- **MSync** não existe no Wine oficial; o motor r2 traz o da árvore do CrossOver (feature `msync`). O
  ajuste é por garrafa (`Bottle.msync`); ao mudá-lo, encerre a garrafa: o `ntdll` recusa processos com um
  `WINEMSYNC` diferente do `wineserver` que já está rodando.
- **winetricks:** alguns verbos exigem `cabextract`, que não vem no macOS. Se `components.json` tiver um
  componente `cabextract`, ele entra no `PATH` do winetricks.
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
- `.github/workflows/release.yml`: cada push na `main` (exceto só `.md`) publica `v<VERSION>.<run_number>`
  com `WinHub.zip`; assina/notariza se os segredos do Developer ID existirem (lista no próprio arquivo).
- Commits: mensagens em inglês, no imperativo. O autor do repositório usa o e-mail noreply do GitHub.

## Próximos passos possíveis

- Ícones reais dos programas (extrair do `.exe`) nos cards e atalhos.
- Mais receitas testadas no catálogo; catálogo comunitário versionado.
- Mais jogos D3D10/11 no relatório de compatibilidade (`docs/compat/`), com `steamGame` no catálogo.
- Modos de tela 16:9 emulados no `winemac.drv` (hoje só os do macOS aparecem para os jogos).
- Wine ARM64 nativo quando o suporte do upstream para macOS chegar (o Rosetta 2 perde o suporte geral no
  macOS 28).
