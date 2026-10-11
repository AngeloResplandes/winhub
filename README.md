# WinHub

Aplicativo nativo para macOS (SwiftUI) para encontrar, instalar e rodar programas do Windows no Mac,
usando o [Wine](https://www.winehq.org/).

> **Projeto independente.** Sem relação com CodeWeavers, Apple, Microsoft ou Valve. Não contém código,
> dados nem binários do CrossOver. Componentes de terceiros são baixados pelo usuário a partir das fontes
> oficiais e conferidos por SHA-256. Veja [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## O que já faz

- **Catálogo com busca**: palavras em ordem, sem diferenciar maiúsculas e acentos, nome no idioma do usuário.
- **Motor Wine**: baixa o pacote oficial do WineHQ para macOS (11.18) na primeira vez.
- **Garrafas**: cada garrafa é um "Windows" separado (prefixo Wine), com versão do Windows própria.
- **Instalar pelo catálogo**: títulos com receita (por exemplo, a **Steam**) instalam com um clique e
  depois mostram **Abrir**. Jogos com ID da Steam ganham **Jogar pela Steam**.
- **Instalar app não listado** (⌘I): escolha um `.exe` ou `.msi` e a garrafa.
- **Programas**: lista os atalhos instalados em todas as garrafas.
- **Atalhos no Finder e no Dock**: "Criar atalho" gera `~/Applications/WinHub/<garrafa>/<programa>.app`,
  que abre o programa pelo Finder, Spotlight ou Dock (arraste para o Dock).
- **Gráficos**: Wine (padrão) ou **DXVK** (Direct3D 10/11 via Vulkan/MoltenVK), por garrafa.
- **Componentes do Windows** via **winetricks** (`vcrun2022`, `corefonts`…), por garrafa ou nas receitas.

### Limitações conhecidas

- **D3DMetal (Game Porting Toolkit da Apple)** não é suportado: ele exige o Wine modificado pela Apple ou
  pela CodeWeavers, e não funciona com o Wine oficial do WineHQ. A licença da Apple também não permite
  redistribuí-lo. Fica para um motor alternativo futuro.
- Sem **MSync** (otimização exclusiva do Wine da CodeWeavers).
- Alguns verbos do winetricks exigem o `cabextract`, que não vem no macOS.
- O Wine para macOS é x86_64: em Macs com Apple Silicon é preciso o **Rosetta 2**.

## Instalar

1. Baixe `WinHub.zip` na página de [Releases](../../releases) e mova o `WinHub.app` para Aplicativos.
2. Se o app não estiver notarizado, abra com **clique direito → Abrir** na primeira vez.
3. No WinHub, clique em **Baixar o Wine** (191 MB, uma vez só).

## Desenvolvimento

Requer macOS 14+, Xcode 16+ (Swift 6) e, em Macs com Apple Silicon, o Rosetta 2.
Para abrir no Xcode: `open Package.swift`.

```bash
swift run WinHub
```

```bash
swift test
```

Testes com o Wine de verdade (opcionais; precisam do Wine já baixado pelo app):

```bash
RUN_WINE_TESTS=1 WINHUB_DXVK_ARCHIVE=/caminho/dxvk.tar.gz WINHUB_WINETRICKS=/caminho/winetricks swift test --filter ComponentIntegrationTests
```

Empacotar o `.app` (assinatura ad-hoc; com `DEVELOPER_ID` e `NOTARY_PROFILE` assina e notariza).
O script também compila o wrapper da Steam (veja abaixo) e precisa do mingw-w64 (`brew install mingw-w64`):

```bash
./scripts/package-app.sh
```

Uma tag `v*` dispara o workflow de release, que publica `WinHub.zip`. Os segredos para assinatura e
notarização estão descritos em `.github/workflows/release.yml`.

## Catálogo e receitas

O catálogo é um JSON (`Sources/WinHub/Resources/catalog.json`; as avaliações do exemplo são
**ilustrativas**). Uma receita descreve como instalar e abrir um título:

```json
"recipe": {
  "bottleName": "Steam",
  "windowsVersion": "win10",
  "dependencies": [],
  "installer": { "url": "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe", "arguments": ["/S"] },
  "launch": { "windowsPath": "C:\\Program Files (x86)\\Steam\\steam.exe" }
}
```

Use apenas URLs oficiais de download e descreva só passos que você testou (veja [CONTRIBUTING.md](CONTRIBUTING.md)).

### Steam e a janela preta

No Wine 11 para macOS, a janela da Steam fica preta: a interface dela é um Chromium que desenha cada
janela a partir de outro processo, e o driver de macOS do Wine não mostra esse desenho. O WinHub
coloca na garrafa um pequeno programa próprio (`Support/steamwebhelper-wrapper/`) no lugar do
`steamwebhelper.exe`; ele abre o original (renomeado para `steamwebhelper_real.exe`) com
`--in-process-gpu`. A Steam é sempre aberta com `-noverifyfiles`, senão ela restaura o original.
Com `swift run` o wrapper não existe (só o app empacotado o inclui), e a janela fica preta.

## Estrutura

```
Sources/WinHubCore/      catálogo, busca e receitas (sem interface)
Sources/WinHubRuntime/   motor Wine, garrafas, execução, atalhos, DXVK e winetricks
Sources/WinHub/          app SwiftUI
Tests/                   testes unitários e de integração
Support/                 wrapper do steamwebhelper (programa do Windows, compilado no empacotamento)
scripts/package-app.sh   gera dist/WinHub.app e dist/WinHub.zip
```

Dados do usuário: `~/Library/Application Support/WinHub/` (motor, componentes e garrafas) e
`~/Applications/WinHub/` (atalhos).

## Licença

MIT. Veja [LICENSE](LICENSE) e [CONTRIBUTING.md](CONTRIBUTING.md) (regra de "sala limpa").
