[English](../development.md) · **Português (Brasil)**

# Desenvolvimento

## Requisitos

- macOS 14 ou mais novo; Macs com Apple silicon também precisam do **Rosetta 2** (o motor Wine é x86_64).
- Xcode 16 ou mais novo (Swift 6). `@State`, `#Preview` e `@Previewable` exigem o Xcode; as Command Line Tools
  não trazem o plug-in de macros.
- Para empacotar o app: mingw-w64 (`brew install mingw-w64`), que compila o wrapper da Steam.

## Compilar, testar, rodar

```bash
swift build
swift test            # 116 testes; os que precisam do Wine de verdade ficam desligados
swift run WinHub      # roda sem empacotar
open Package.swift    # abre no Xcode
```

Com `swift run`, os atalhos `.app` e os links `winhub://` não funcionam, e as atualizações do app ficam
desligadas (só o catálogo e os manifestos se atualizam).

### Steam com `swift run`

Sem o wrapper, a janela da Steam fica preta ([por quê](decisions.md#2026-10-11-trocar-o-steamwebhelper-por-um-wrapper)).
Compile-o e indique o caminho ao WinHub:

```bash
./scripts/build-steam-wrapper.sh
```

```bash
WINHUB_STEAMWEBHELPER_WRAPPER=.build/steamwebhelper-wrapper.exe swift run WinHub
```

### Testes com o Wine de verdade

Precisam do motor já baixado pelo app (`~/Library/Application Support/WinHub/Runtimes`):

```bash
RUN_WINE_TESTS=1 swift test --filter ComponentIntegrationTests
```

`WINHUB_DXVK_ARCHIVE` e `WINHUB_WINETRICKS` usam arquivos locais em vez de baixar; `WINHUB_CABEXTRACT_VERB=corefonts`
também testa o cabextract. Para baixar e instalar de verdade o primeiro motor do `runtimes.json`:

```bash
RUN_WINE_TESTS=1 WINHUB_INSTALL_ENGINE=1 swift test --filter EngineInstallTests
```

## Empacotamento

```bash
./scripts/package-app.sh
```

Gera o `dist/WinHub.app` (universal) e o `dist/WinHub.zip` com assinatura ad-hoc, desenhando o ícone por código
(`scripts/make-icon.swift`) e compilando o wrapper da Steam. Com `DEVELOPER_ID` e `NOTARY_PROFILE` definidos, assina
e notariza. Para conferir uma mudança na interface, abra o app empacotado: `open dist/WinHub.app`.

## Versões

Todo push na `main` que muda mais do que Markdown e documentação roda o `.github/workflows/release.yml`, que testa,
empacota e publica `v<VERSION>.<número da execução>` (por exemplo `v0.2.57`) com o `WinHub.zip`. Os apps
instalados a encontram e se atualizam sozinhos. Edite o `VERSION` para mudar o número major ou minor. Os segredos
de assinatura e notarização estão listados no começo do workflow.

O CI (`ci.yml`) usa o Swift 6.1 (Xcode 16.4), que é mais rígido que o Swift local recente com isolamento: closures
`async` passados a métodos `@MainActor` precisam ser marcados `@MainActor` (ou devolver um resultado `Sendable`).

## Testar um motor local

Para experimentar um build do [winhub-engine](https://github.com/AngeloResplandes/winhub-engine) antes de ele ser
publicado (foi assim que a revisão 2 foi testada em 2026-10-12):

1. Compile o motor (o `./scripts/package.sh` do winhub-engine grava o overlay e o `winhub-manifests.json` em
   `work/dist`).
2. Instale-o como o WinHub faria, em `~/Library/Application Support/WinHub/Runtimes/<id>/`: desempacote o pacote
   oficial do Wine, remova as pastas listadas em `overlay.replace`, desempacote o overlay por cima e grave a
   entrada `runtime` do `winhub-manifests.json` em `.winhub-runtime.json` **por último**.
3. Ponha essa entrada em primeiro lugar no `~/Library/Application Support/WinHub/Remote/runtimes.json` (guarde
   uma cópia do arquivo).
4. Desligue **Ajustes → Atualizações → Procurar atualizações automaticamente**, senão a próxima verificação troca
   o `runtimes.json` pelo da `main`.
5. Teste numa **cópia** de uma garrafa (no APFS, `cp -c` faz um clone instantâneo) e nunca abra duas Steams da
   mesma garrafa ao mesmo tempo ([por quê](decisions.md#2026-10-11-nunca-abrir-duas-steams-da-mesma-garrafa)).

Para desfazer: restaure a cópia do `runtimes.json`, religue as verificações automáticas e apague a pasta do motor.

## Convenções

- **Os textos da interface são escritos em português do Brasil** (o idioma de origem) e traduzidos em
  `Sources/WinHub/Resources/Localizable.xcstrings`; código, identificadores e comentários em inglês. Texto que não é
  um literal do SwiftUI (erros, progresso, títulos de enums) usa `String(localized:)`, em qualquer módulo. Depois de
  mudar a interface, rode `./scripts/update-strings.sh` e traduza as chaves novas; o `LocalizationTests` falha com
  uma chave sem inglês ou com argumentos diferentes. O `package-app.sh` copia as pastas `.lproj` compiladas para o
  app, então com `swift run` a interface fica em português. As entradas do catálogo se traduzem por `localizedNames`
  e `localizedSummaries`.
- Comentários curtos, só onde o "porquê" não é óbvio.
- Modelos `Codable` novos usam `decodeIfPresent` com padrão, para JSON antigo (`bottle.json`, catálogos de
  usuários) continuar decodificando, e mudanças no JSON publicado precisam continuar decodificáveis pelas versões
  antigas do app.
- Testes com **Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect`).
- A lógica fica no Core ou no Runtime, onde pode ser testada; a interface só orquestra pelos stores.
- Instaladores e componentes só de URLs oficiais; SHA-256 obrigatório para componentes e opcional para
  instaladores que o fabricante atualiza no mesmo endereço (como o `SteamSetup.exe`).
- Commits: em inglês, no imperativo.
