[English](../../compat/peak.md) · **Português (Brasil)**

# PEAK (Steam, app 3527290): testes no WinHub

## Ambiente

| Item | Valor |
|---|---|
| Data | 12/10/2026 e 13/10/2026 |
| Mac | Apple M5, macOS 27 |
| Motor | `winhub-wine-11.0-r2` (Wine 11.0 das fontes do CrossOver, x86_64, Rosetta 2) |
| D3DMetal | Game Porting Toolkit 3.0 da Apple, na pasta da própria pessoa |
| Garrafa | clone APFS da garrafa da Steam, Windows 10, msync ligado, Resoluções extras ligado, Metal HUD ligado, Direct3D "Automático" |
| Jogo | build 25739797, Unity 6000.3.15f1, Direct3D 11, 64 bits |

Testado com o [`scripts/game-test.swift`](README.md#testar-com-o-scriptsgame-testswift): o script abriu o jogo pela
Steam, mandou teclas e cliques como eventos do macOS e leu o FPS no Metal HUD.

## Resultados

| Backend | Abre? | Medição | Observações |
|---|---|---|---|
| D3DMetal ("Automático") | **Sim, jogável** | menu principal (uma cena 3D) de 116 a 127 FPS; aeroporto (lobby) de 73 a 82 FPS, GPU de 8 a 12 ms por quadro | "Jogar offline", o aeroporto e andar. A lista de microfones mostra o microfone do Mac. |
| DXMT | **Sim** | — | O menu principal aparece e se anima. |
| DXVK | **Sim** | — | O menu principal aparece e se anima. |

**O microfone travava o jogo antes de o WinHub declará-lo**: o carregamento de "Jogar offline" parava depois que o
gravador de voz pedia o microfone (o log do Unity termina em `MicWrapper`; o macOS registrou que recusou o pedido
porque o app não tinha descrição de uso). Corrigido em 13/10/2026, veja
[Decisões](../decisions.md#2026-10-13-declarar-o-microfone-no-infoplist-do-winhub).

## O que o WinHub deve fazer

- Catálogo: nota 4. Nenhuma regra é necessária.
