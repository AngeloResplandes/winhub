[English](../../compat/lethal-company.md) · **Português (Brasil)**

# Lethal Company (Steam, app 1966720): testes no WinHub

## Ambiente

| Item | Valor |
|---|---|
| Data | 12/10/2026 e 13/10/2026 |
| Mac | Apple M5, macOS 27 |
| Motor | `winhub-wine-11.0-r2` (Wine 11.0 das fontes do CrossOver, x86_64, Rosetta 2) |
| D3DMetal | Game Porting Toolkit 3.0 da Apple, na pasta da própria pessoa |
| Garrafa | clone APFS da garrafa da Steam, Windows 10, msync ligado, Resoluções extras ligado, Metal HUD ligado, Direct3D "Automático" |
| Jogo | build 22825947, Unity 2022.3.62f2, Direct3D 11 (level 11.1), 64 bits |

Testado com o [`scripts/game-test.swift`](README.md#testar-com-o-scriptsgame-testswift): o script abriu o jogo pela
Steam, mandou teclas e cliques como eventos do macOS e leu o FPS no Metal HUD.

## Resultados

| Backend | Abre? | Medição | Observações |
|---|---|---|---|
| D3DMetal ("Automático") | **Sim, jogável** | 60 FPS, GPU de 6 a 14 ms por quadro | Telas de configuração, hospedar em LAN (só local), a nave, andar e olhar com o mouse. O Unity vê "AMD Compatibility Mode", o adaptador do D3DMetal. |
| DXMT | **Sim** | — | Os menus aparecem e se animam. |
| DXVK | **Sim** | — | Os menus aparecem e se animam. |

**O microfone travava o jogo antes de o WinHub declará-lo** (corrigido em 13/10/2026, veja
[Decisões](../decisions.md#2026-10-13-declarar-o-microfone-no-infoplist-do-winhub)): a primeira tela de configuração
parava de reagir. Com a correção, o jogo lista o "Microfone (MacBook Air)" e segue; o macOS pergunta uma vez se o
WinHub pode usar o microfone.

Falta conferir à mão: uma forma borrada azul e laranja bem perto da câmera dentro da nave (provavelmente um objeto
da nave desfocado).

## O que o WinHub deve fazer

- Catálogo: nota 4. Nenhuma regra é necessária: o "Automático" escolhe o D3DMetal ou o DXMT, e os dois funcionam.
