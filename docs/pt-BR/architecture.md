[English](../architecture.md) · **Português (Brasil)**

# Arquitetura

O WinHub é um pacote Swift com três módulos. O app só orquestra; tudo o que pode ser testado sem tela fica nas
duas bibliotecas.

```
Sources/WinHubCore/      dados puros, sem interface e sem processos
Sources/WinHubRuntime/   tudo o que toca disco, rede e processos do Wine
Sources/WinHub/          o app SwiftUI
Support/                 wrapper do steamwebhelper (programa do Windows, compilado no empacotamento)
Tests/                   testes unitários e de integração (Swift Testing)
```

O `WinHub` depende do `WinHubCore` e do `WinHubRuntime`. O `WinHubRuntime` depende do `WinHubCore` para executar
as receitas do catálogo; o Core continua sem Runtime, sem processos e sem interface.

## Módulos

| Módulo | Tipos principais | Papel |
|---|---|---|
| **WinHubCore** | `CatalogEntry`, `Rating`, `Recipe`, `CatalogLoader`, `CatalogSearchEngine`, `WildcardPattern`, `ArgumentSplitter` | O catálogo e a busca ([Busca do catálogo](catalog-search.md)), receitas de instalação |
| **WinHubRuntime** | `RuntimeManifest`, `RuntimeManager` | Baixa, confere (SHA-256) e instala o motor Wine, inclusive os overlays do motor |
| | `Bottle`, `BottleStore` | Uma garrafa é uma pasta com `bottle.json` e `prefix/` (o `WINEPREFIX`); o store cria, duplica, renomeia e apaga garrafas |
| | `BottleTemplate`, `BottleAdvancedSettings`, `WineTool` | Modelos para garrafas novas; lê e grava como texto as variáveis e as substituições de DLL da garrafa; as ferramentas do próprio Wine |
| | `WineEnvironment` | Monta o ambiente dos processos do Wine (uma função pura) |
| | `WineLauncher`, `ProgramScanner`, `WineServerStatus`, `WineOrphanReaper` | Roda o Wine, encontra os programas instalados, sabe se a garrafa está rodando, limpa processos órfãos |
| | `BottleSession`, `BottleGuard` | Registra qual WinHub roda o Wine numa garrafa; decide se outro WinHub, motor ou Steam está no caminho |
| | `BottleArchive` | Exporta uma garrafa (sem os logs e o registro de sessão) para um arquivo `.winhubbottle` e importa uma como garrafa nova |
| | `ShellLink`, `ProgramIcon` | Lê o alvo de um atalho e o ícone do programa no `.exe` (remontado como `.ico`) |
| | `ComponentManager`, `GraphicsBackend` | DXVK e winetricks; o Direct3D da garrafa e de cada programa ([Gráficos](graphics.md)) |
| | `CompatRules`, `D3DMetal`, `CompatDatabaseSync` | Regras da garrafa para o motor, o D3DMetal do usuário, o banco de regras assinado |
| | `RecipeRunner` | Executa o instalador de uma receita do catálogo (exe, msi ou zip) e os passos extras, com um executor falso nos testes |
| | `AppLauncherBuilder`, `SteamWebHelperWrapper` | Atalhos `.app`; a correção da janela preta da Steam |
| | `AppUpdater`, `RemoteDataSync` | Atualizações do app; catálogo e manifestos da `main` |
| **WinHub** | `WinHubApp`, `RootView`, `CatalogStore`, `WineStore`, `UpdateStore`, telas | Cenas, menus, ajustes, links `winhub://`; stores observáveis que as telas leem |

Dados do usuário: `~/Library/Application Support/WinHub/{Runtimes,Components,Bottles,Remote,compat}`,
`~/Library/Caches/WinHub/{Downloads,Updates}`, atalhos em `~/Applications/WinHub/`.

## Fluxos principais

**Motor.** O `runtimes.json` lista os motores; o primeiro é instalado. O `RuntimeManager.install` baixa o pacote
oficial do Wine, confere o SHA-256 e o desempacota; quando a entrada tem `overlay` (uma versão do winhub-engine),
confere esse também, remove as pastas listadas em `overlay.replace` (que precisam ficar dentro da pasta do Wine)
e desempacota o overlay por cima. O marcador `.winhub-runtime.json` é gravado por último, para um motor instalado
pela metade nunca ser usado. Um motor mais novo no `runtimes.json` não invalida o instalado; a barra lateral
oferece "Atualizar o Wine".

**Garrafa nova.** `BottleStore.create` → `WineLauncher.initialize`: `wineboot --init` com Mono e Gecko
desligados, `winecfg /v <versão>`, depois `wineserver -k` e `-w`.

**Receita.** Um título do catálogo com `recipe` instala com um clique: garrafa pelo nome (criada com os `settings`
da receita se for nova, senão reaproveitada) → dependências do winetricks → download → exe/msi ou extração do zip
→ `steps` extras → grava `rules` → confere que `launch.windowsPath` existe → abre. Formato:
[Receitas do catálogo](recipes.md).

**Abrir um programa.** O `WineStore.launch` inicia o programa e não espera por ele; "em execução" vem do
`WineServerStatus` (alguém segura o `lock` do `wineserver`), porque programas como a Steam se reiniciam sozinhos.

**Atalhos.** Um atalho `.app` só roda `open "winhub://open?bottle=<uuid>&shortcut=<path>"`; o WinHub confere que o
`.lnk` está dentro do `drive_c` da garrafa antes de abri-lo. O Wine nunca roda dentro do processo do próprio
atalho (programas abertos assim travam).

**Atualizações.** O `UpdateStore` confere 10 s depois de abrir e depois a cada hora:

1. o `RemoteDataSync` baixa `catalog.json`, `runtimes.json` e `components.json` da `main` e só os guarda se esta
   versão do app conseguir decodificá-los;
2. o `CompatDatabaseSync` baixa o banco de regras do motor e a assinatura Ed25519 dele, e só o instala com
   assinatura válida e banco mais novo;
3. o `AppUpdater` lê a versão mais nova no GitHub, baixa o `WinHub.zip`, confere o SHA-256 que o GitHub calculou,
   o identificador, a versão e o `codesign --verify`, e troca o app em "Reiniciar para atualizar".

## Ferramentas da garrafa

Os modelos ficam em "Nova garrafa"; as outras ferramentas ficam na página da garrafa, em "Manutenção" e
"Configuração".

- **Duplicar garrafa…** clona a pasta (`cp -cR`, um clone do APFS) numa garrafa nova, com id e nome próprios. Os
  logs e o registro de sessão não são copiados, nem os atalhos `.app`. Uma garrafa em uso é encerrada antes, depois
  de uma confirmação. Enquanto uma tarefa roda na garrafa, Duplicar, Renomear, Executar comando e Avançado esperam;
  um nome que outra garrafa já tem (sem contar maiúsculas) é recusado na própria janela, antes de qualquer coisa
  fechar.
- **Renomear garrafa…** muda só o nome no `bottle.json`; o id e a pasta continuam. A pasta dos atalhos acompanha o
  nome, e um atalho `.app` que já existe continua abrindo, porque aponta para o id da garrafa. Tirar o nome
  “Steam” da garrafa da Steam pede uma confirmação antes.
- **Ferramentas do Wine** abre, na garrafa, a configuração do Wine (`winecfg`), o editor do registro (`regedit`), o
  painel de controle (`control`), o gerenciador de tarefas (`taskmgr`) e um prompt de comando (`cmd`).
- **Executar comando…** roda uma vez um `.exe`, `.msi` ou `.bat` de qualquer lugar do Mac, com argumentos, pasta de
  trabalho e variáveis extras (que valem mais que as da garrafa). O `ArgumentSplitter` separa os argumentos: espaços
  e tabulações separam, só as aspas duplas agrupam (a aspa simples é um caractere comum, como no Windows), e a barra
  invertida só escapa uma aspa dupla dentro de aspas duplas. Por isso um caminho entre aspas que termina em barra
  invertida, como `"C:\Games\"`, é lido como aspa escapada e engole o resto da linha, igual ao Windows. Um `.msi`
  ignora a pasta de trabalho.
- **Modelo** (em "Nova garrafa"): Jogos (Windows 10, Direct3D Automático, msync), Aplicativos (Windows 10, Direct3D
  do próprio Wine) e Programas antigos (Windows 7, Direct3D do próprio Wine); Personalizado é a garrafa simples.
  Se o motor instalado não tem o Direct3D ou o msync que o modelo pede, usa-se o Direct3D do próprio Wine (ou, sem
  ele, o primeiro disponível) e o msync fica desligado. A versão do Windows escolhida no seletor vale mais que a do
  modelo.
- **Avançado…** edita as variáveis de ambiente da garrafa (`NOME=valor`, uma por linha; o valor vale como está, sem
  aspas; linhas que começam com `#` são ignoradas; `WINEPREFIX` é do WinHub e é recusada) e as substituições de DLL
  (`xinput1_3=n,b`; `n` é a DLL do Windows, `b` a do Wine; modo vazio desliga a DLL). Uma linha errada é recusada com
  o número dela. `d3d10core`, `d3d11`, `dxgi` e `winemetal` também são recusadas: quem cuida delas é a escolha em
  "Gráficos (Direct3D)", e um motor que escolhe o Direct3D tomaria essa substituição por sobra das DLLs copiadas de
  antes e a removeria. As substituições que o WinHub pôs para o Direct3D de um motor antigo ficam fora do editor e
  são mantidas. A mudança vale para os programas abertos depois; se a garrafa está rodando e a mudança exige
  reiniciar, o WinHub pergunta antes de encerrar os programas.

## O catálogo e as receitas

O catálogo é o `Sources/WinHub/Resources/catalog.json`: uma lista de `CatalogEntry` (`id`, `name`,
`localizedNames`, `category`, `summary`, `rating`, `isFeatured`, `steamID`, `steamGame`, `recipe`). Uma receita
diz como instalar e abrir um título ([Receitas do catálogo](recipes.md)):

```json
"recipe": {
  "bottleName": "Steam",
  "windowsVersion": "win10",
  "dependencies": [],
  "installer": { "url": "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe", "arguments": ["/S"] },
  "launch": { "windowsPath": "C:\\Program Files (x86)\\Steam\\steam.exe" }
}
```

Campos opcionais cobrem zip, passos extras, ajustes da garrafa, regras do compatdb, `minAppVersion` e `launches`
extras. O `steamGame` (`installDir`, `executable`, `graphics`) diz onde um jogo da Steam fica na garrafa da Steam e
qual Direct3D funcionou melhor nos nossos testes. Use só URLs oficiais de download e descreva só passos que você
testou.

## Trabalhando com o motor

Os motores declaram o que sabem fazer em `features` no `runtimes.json`:

| Feature | O que o WinHub faz com ela |
|---|---|
| `dxmt` | Oferece o DXMT. Em motores sem `backend-dispatch`, copia as DLLs do DXMT para a garrafa ou para a pasta do programa |
| `dxvk` | O DXVK vem com o motor em vez do componente DXVK-macOS |
| `msync` | Oferece a chave de msync por garrafa (`WINEMSYNC=1`) |
| `backend-dispatch` | O motor escolhe o Direct3D: o WinHub só define `WINHUB_GRAPHICS_BACKEND` e escreve as regras por programa; oferece Automático e D3DMetal |
| `compatdb` | O motor lê arquivos de regras: o da garrafa (`WINHUB_COMPAT_RULES`) e o banco assinado (`WINHUB_HOME/compat/compatdb.json`) |
| `nvext` | Oferece a chave por garrafa das extensões da NVIDIA do DXMT (`DXMT_ENABLE_NVEXT=1`: NVAPI e DLSS pelo MetalFX) |

Com `backend-dispatch`, o `WineEnvironment` define `WINHUB_GRAPHICS_BACKEND`, `WINHUB_COMPAT_RULES`,
`WINHUB_HOME` e, quando o usuário tem o D3DMetal, `WINHUB_D3DMETAL_DIR` e `CX_APPLEGPTK_LIBD3DSHARED_PATH`. Como o
motor usa essas variáveis: [winhubcompat](https://angeloresplandes.github.io/winhub-engine/pt-BR/compatdb.html).

Garrafas montadas quando o WinHub copiava DLLs são migradas antes de um programa abrir
(`migrateToDispatchedGraphics`): as DLLs do próprio Wine voltam, as cópias e os overrides `n,b` saem, e os
programas com Direct3D próprio viram regras em `<garrafa>/compat-rules.json`.

## O ambiente dos processos

O `WineEnvironment` só herda `HOME`, `USER`, `LOGNAME`, `LANG`, `LC_ALL`, `TMPDIR` e `SHELL`, sempre define
`ROSETTA_ADVERTISE_AVX=1` e `DOTNET_EnableWriteXorExecute=0` (as mesmas duas variáveis que o lançador do
CrossOver define), usa `WINEDEBUG=fixme-all` por padrão e deixa as configurações da garrafa vencerem.
