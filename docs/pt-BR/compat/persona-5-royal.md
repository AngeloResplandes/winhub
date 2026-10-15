[English](../../compat/persona-5-royal.md) · **Português (Brasil)**

# Persona 5 Royal (Steam, app 1687950): testes no WinHub

## Ambiente

| Item | Valor |
|---|---|
| Data | 15/10/2026 |
| Mac | Apple M5, macOS 27.0.1 |
| Motor | `winhub-wine-11.0-r3` (Wine 11.0 das fontes do CrossOver, x86_64, Rosetta 2) |
| D3DMetal | não instalado |
| Garrafa | clone APFS da garrafa Steam, Windows 10, msync desligado, Metal HUD ligado, Direct3D "Automático" |
| Jogo | build 15515071, Direct3D 11, 64 bits |

## Resultado: instala, mas não abre

O jogo fecha logo depois de abrir, antes de qualquer janela ter conteúdo:
`Unhandled page fault on read access to 00000000000008FF at address 00000001401D7EB9`. O endereço fica dentro do
`P5R.exe` e é o mesmo em todas as tentativas:

| Tentativa | Resultado |
|---|---|
| Pela Steam, "Automático" (DXMT) | falha; o depurador do Wine abre |
| Direto, DXMT | a mesma falha, logo depois de carregar o `d3d11.dll` |
| Direto, DXVK | a mesma falha, antes de carregar o `d3d11.dll` |
| DXMT, overlay da Steam desligado (`gameoverlayrenderer64=d`) | a mesma falha |
| DXMT, sem `ROSETTA_ADVERTISE_AVX` | a mesma falha |

A falha vem antes de o jogo desenhar qualquer coisa e não depende do Direct3D, então a causa está em outro lugar
(uma API que o Wine responde diferente, ou o que o jogo lê do sistema). Não tentado: D3DMetal, outras versões do
Windows, `WINEDEBUG=+seh,+relay` em volta da falha.

## O que o WinHub deve fazer

- Catálogo: nota 2 ("Instala, mas não abre"), sem `steamGame.graphics`.
- Sem regra.
