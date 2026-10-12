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

O `WinHub` depende do `WinHubCore` e do `WinHubRuntime`; as duas bibliotecas não dependem uma da outra nem da
interface.

## Módulos

| Módulo | Tipos principais | Papel |
|---|---|---|
| **WinHubCore** | `CatalogEntry`, `Rating`, `Recipe`, `CatalogLoader`, `CatalogSearchEngine`, `WildcardPattern` | O catálogo e a busca ([Busca do catálogo](catalog-search.md)), receitas de instalação |
| **WinHubRuntime** | `RuntimeManifest`, `RuntimeManager` | Baixa, confere (SHA-256) e instala o motor Wine, inclusive os overlays do motor |
| | `Bottle`, `BottleStore` | Uma garrafa é uma pasta com `bottle.json` e `prefix/` (o `WINEPREFIX`) |
| | `WineEnvironment` | Monta o ambiente dos processos do Wine (uma função pura) |
| | `WineLauncher`, `ProgramScanner`, `WineServerStatus`, `WineOrphanReaper` | Roda o Wine, encontra os programas instalados, sabe se a garrafa está rodando, limpa processos órfãos |
| | `ShellLink`, `ProgramIcon` | Lê o alvo de um atalho e o ícone do programa no `.exe` (remontado como `.ico`) |
| | `ComponentManager`, `GraphicsBackend` | DXVK e winetricks; o Direct3D da garrafa e de cada programa ([Gráficos](graphics.md)) |
| | `CompatRules`, `D3DMetal`, `CompatDatabaseSync` | Regras da garrafa para o motor, o D3DMetal do usuário, o banco de regras assinado |
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

**Receita.** Um título do catálogo com `recipe` instala com um clique: garrafa pelo nome (reaproveitada se
existir) → dependências do winetricks → baixa o instalador → roda → confere que `launch.windowsPath` existe →
abre.

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

## O catálogo e as receitas

O catálogo é o `Sources/WinHub/Resources/catalog.json`: uma lista de `CatalogEntry` (`id`, `name`,
`localizedNames`, `category`, `summary`, `rating`, `isFeatured`, `steamID`, `steamGame`, `recipe`). Uma receita
diz como instalar e abrir um título:

```json
"recipe": {
  "bottleName": "Steam",
  "windowsVersion": "win10",
  "dependencies": [],
  "installer": { "url": "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe", "arguments": ["/S"] },
  "launch": { "windowsPath": "C:\\Program Files (x86)\\Steam\\steam.exe" }
}
```

O `steamGame` (`installDir`, `executable`, `graphics`) diz onde um jogo da Steam fica na garrafa da Steam e qual
Direct3D funcionou melhor nos nossos testes. Use só URLs oficiais de download e descreva só passos que você testou.

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
