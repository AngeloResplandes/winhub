<p align="center">
  <img src="docs/icon.svg" width="128" height="128" alt="Ícone do WinHub">
</p>

<h1 align="center">WinHub</h1>

Precisa de um programa ou jogo que só existe para Windows? Com o WinHub você o encontra num catálogo,
instala e abre no Mac como qualquer outro app, sem máquina virtual e sem instalar o Windows. Títulos com
receita, como a Steam, instalam com um clique.

O WinHub é um aplicativo nativo para macOS que cuida de tudo o que o [Wine](https://www.winehq.org/)
precisa para rodar programas do Windows. Cada programa fica numa "garrafa", um Windows separado com as
próprias configurações, e você escolhe o que cada uma usa: a versão do Windows, os gráficos (Wine ou DXVK)
e as bibliotecas extras instaladas pelo winetricks. Os programas instalados ganham atalhos que abrem pelo
Finder, pelo Spotlight ou pelo Dock.

Na primeira vez, o WinHub baixa o Wine oficial do WineHQ e confere o arquivo antes de instalar; motores,
componentes e instaladores vêm sempre das fontes oficiais. Depois disso, o app se mantém atualizado
sozinho: o catálogo acompanha este repositório, e as versões novas do app são baixadas em segundo plano e
instaladas com um clique.

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
- **Gráficos**: Wine (padrão), **DXVK** (Direct3D 10/11 via Vulkan/MoltenVK) ou, com o motor do WinHub,
  **DXMT** (Direct3D 10/11 direto no Metal), por garrafa ou **por programa**. No caso de um jogo da Steam,
  só o jogo muda e a interface da Steam continua com o Wine.
- **Desempenho**: chave por garrafa que mostra o painel de FPS do Metal (e o do DXVK).
- **Componentes do Windows** via **winetricks** (`vcrun2022`, `corefonts`…), por garrafa ou nas receitas.

### Limitações conhecidas

- **D3DMetal (Game Porting Toolkit da Apple)** não é suportado: a licença da Apple não permite
  redistribuí-lo, e ele não funciona com o Wine oficial do WineHQ. No lugar dele, o motor do WinHub
  ([winhub-engine](https://github.com/AngeloResplandes/winhub-engine), em preparação) traz o
  [DXMT](https://github.com/3Shain/dxmt), aberto, que leva o Direct3D 10/11 direto ao Metal.
- O Direct3D do próprio Wine (wined3d) chega só ao feature level 9_3 no macOS. Jogos que exigem
  Direct3D 11 (como os feitos em Unity 6) precisam de DXVK ou DXMT. Veja
  [docs/compat/hollow-knight.md](docs/compat/hollow-knight.md).
- **Resoluções:** o Wine para Mac oferece aos jogos só os modos de tela do macOS, na proporção da tela
  do Mac. Resoluções 16:9 como 1920×1080 não aparecem.
- Sem **MSync**: os patches abertos ([wine-msync](https://github.com/marzent/wine-msync)) param no
  Wine 9.15. O porte para o Wine 11 está
  planejado em [winhub-engine/docs/msync-plan.md](https://github.com/AngeloResplandes/winhub-engine/blob/main/docs/msync-plan.md).
- Alguns verbos do winetricks exigem o `cabextract`, que não vem no macOS. Ele virá como componente do
  winhub-engine.
- O Wine para macOS é x86_64: em Macs com Apple Silicon é preciso o **Rosetta 2**, que a Apple mantém de
  forma geral até o macOS 27.

## Instalar

1. Baixe o [`WinHub.zip` da versão mais recente](https://github.com/AngeloResplandes/winhub/releases/latest/download/WinHub.zip)
   (veja [todas as versões](https://github.com/AngeloResplandes/winhub/releases)) e mova o `WinHub.app` para
   Aplicativos.
2. Se o app não estiver notarizado, o macOS bloqueia a primeira abertura. Tente abrir uma vez e, em
   **Ajustes do Sistema → Privacidade e Segurança**, clique em **Abrir Mesmo Assim** (desde o macOS 15,
   o clique direito → Abrir não basta mais).
3. No WinHub, clique em **Baixar o Wine** (191 MB, uma vez só).

Depois disso o WinHub se atualiza sozinho: o catálogo acompanha cada commit do repositório e as versões
novas do app são baixadas em segundo plano e instaladas quando você clica em **Reiniciar para atualizar**
(desligue em **Ajustes → Atualizações**). Funciona se o app estiver numa pasta em que você pode gravar,
como Aplicativos.

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

Cada push na `main` (fora mudanças só em `.md`) dispara o workflow de release, que publica a versão
`<VERSION>.<número da execução>` (ex.: `0.2.57`) com o `WinHub.zip`; para mudar major/minor, edite o
arquivo `VERSION`. Os segredos para assinatura e notarização estão descritos em
`.github/workflows/release.yml`.

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
`--in-process-gpu`. Com o wrapper instalado, a Steam é aberta com `-noverifyfiles`, senão ela restaura
o original. Logo depois de instalar a Steam, a primeira sessão ainda fica preta (é nela que a Steam baixa
o cliente e o helper); feche-a (**Encerrar** na garrafa) e abra de novo pelo WinHub.
O app empacotado já inclui o wrapper. Com `swift run`, compile-o e indique o caminho:

```bash
./scripts/build-steam-wrapper.sh
WINHUB_STEAMWEBHELPER_WRAPPER=.build/steamwebhelper-wrapper.exe swift run WinHub
```

## Estrutura

```
Sources/WinHubCore/      catálogo, busca e receitas (sem interface)
Sources/WinHubRuntime/   motor Wine, garrafas, execução, atalhos, DXVK e winetricks
Sources/WinHub/          app SwiftUI
Tests/                   testes unitários e de integração
Support/                 wrapper do steamwebhelper (programa do Windows, compilado no empacotamento)
scripts/package-app.sh   gera dist/WinHub.app e dist/WinHub.zip
scripts/build-steam-wrapper.sh  compila o wrapper da Steam (mingw-w64)
scripts/make-icon.swift  desenha o ícone do app (.icns no empacotamento, docs/icon.svg para o README)
```

Dados do usuário: `~/Library/Application Support/WinHub/` (motor, componentes e garrafas) e
`~/Applications/WinHub/` (atalhos).

## Licença

MIT. Veja [LICENSE](LICENSE) e [CONTRIBUTING.md](CONTRIBUTING.md) (regra de "sala limpa").

---

**Projeto independente.** Sem relação com CodeWeavers, Apple, Microsoft ou Valve. Não contém código,
dados nem binários do CrossOver. Componentes de terceiros são baixados pelo usuário a partir das fontes
oficiais e conferidos por SHA-256. Veja [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
