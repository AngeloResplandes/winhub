[English](../../compat/skyrim-special-edition.md) · **Português (Brasil)**

# The Elder Scrolls V: Skyrim Special Edition (Steam, app 489830): testes no WinHub

## Ambiente

| Item | Valor |
|---|---|
| Data | 15/10/2026 |
| Mac | Apple M5, macOS 27.0.1 |
| Motor | `winhub-wine-11.0-r3` (Wine 11.0 das fontes do CrossOver, x86_64, Rosetta 2) |
| D3DMetal | não instalado |
| Garrafa | clone APFS da garrafa Steam, Windows 10, msync desligado, Metal HUD ligado, Direct3D "Automático"; o `Documents` do clone é uma cópia, não o link para o `~/Documents` do Mac |
| Jogo | build 24914197 (sem o Anniversary Upgrade), Direct3D 11, 64 bits; o launcher escolheu o preset Ultra |

Testado com o [`scripts/game-test.swift`](README.md#testar-com-o-scriptsgame-testswift) e rodando o `SkyrimSE.exe`
direto, com `SteamAppId`/`SteamGameId`, enquanto a Steam da garrafa estava aberta.

## Resultados

| Backend | Abre? | Medição | Notas |
|---|---|---|---|
| DXMT ("Automático") | **Não** | — | A janela abre e o jogo fecha uns 12 s depois, antes da tela de título. A última linha do log é `err: Pure virtual function called`. O mesmo pela Steam e rodando direto. |
| DXVK | **Sim, jogável** | Tela de título: 60 FPS, GPU de uns 6 ms por quadro. Jogo novo, a cena da carroça (Ultra, 1470×956): 37 FPS, GPU de uns 21 ms por quadro | Pela Steam e rodando direto. O teclado funciona nos menus. |
| Wine (wined3d) | não tentado | — | O wined3d só chega ao feature level 9_3 no macOS; o jogo precisa do 11_0. |

O launcher (`SkyrimSELauncher.exe`) usa Direct3D 9 pelo Wine e funciona: detecção do hardware e Play.

## Regras pelo id do app na Steam não chegam ao jogo

A primeira regra testada casava pelo app da Steam (`steam_game_id` 489830) e não se aplicou quando a Steam abriu o
jogo: o motor registrou `SteamGameId (null)` para o launcher e para o `SkyrimSE.exe`. A Steam põe o `SteamGameId` no
ambiente Windows do jogo, e o motor lê do ambiente Unix do processo, que o Wine não preenche a partir do Windows.
Uma regra que casa pelo caminho do executável (`path_suffix`) funciona pela Steam. O mesmo vale para a regra do Dark
Souls Remastered. Corrigir o motor para ler o ambiente Windows é uma tarefa à parte.

## O que o WinHub deve fazer

- Catálogo: nota 4, `steamGame.graphics` = `dxvk` (`installDir` `Skyrim Special Edition`, `SkyrimSE.exe`).
- Regra (banco do winhub-engine): `graphics_backend` = `dxvk` para o sufixo de caminho
  `\Skyrim Special Edition\SkyrimSE.exe`. Sem ela, o "Automático" escolhe o DXMT, que fecha o jogo.
