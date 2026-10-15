[English](../../compat/the-witcher-3.md) · **Português (Brasil)**

# The Witcher 3: Wild Hunt (Steam, app 292030): testes no WinHub

Resultados nossos, medidos no WinHub.

## Ambiente

| Item | Valor |
|---|---|
| Data | 2026-10-11 |
| Mac | Apple M5, macOS 27.0.1 |
| Motor | `winhub-wine-11.18-r1` (WineHQ 11.18 + overlay do winhub-engine) |
| Garrafa | Steam, Windows 10, gráficos da garrafa: Wine |
| Jogo | "The Witcher 3: Wild Hunt — Remastered", build 25773555 (74 GB) |

## Resultado (versão atual): instala, mas não abre

- **A versão atual é só DirectX 12.** O `launcher-configuration.json` lista apenas `bin\x64_dx12\witcher3.exe`, e a
  pasta `bin\x64` (DX11) não existe. O modo DX11 só existe no ramo beta "classic" da Steam (1.32).
- **Launcher da CD Projekt (`REDlauncher`, Qt WebEngine):** trava ao abrir, com `Unhandled exception 0x80000003`
  (breakpoint), e cai no depurador do Wine. Isso lembra os problemas da Steam com o próprio Chromium.
- **Jogo aberto direto (`witcher3.exe` DX12, Steam aberta):** mostra "GPU does not meet minimal requirements.
  Support for DirectX 12 is required." O D3D12 do Wine (vkd3d sobre MoltenVK) não oferece o que o jogo exige, e o
  DXMT v0.80 não tem D3D12.

## 15/10/2026: o ramo "classic" (1.32, DX11) na revisão 3 do motor

Mesmo Mac (macOS 27.0.1), motor `winhub-wine-11.0-r3`, sem D3DMetal, um clone APFS da garrafa Steam (Windows 10,
msync desligado, Metal HUD ligado, Direct3D "Automático"). Ramo beta `classic` da Steam, build 3280809, com as duas
expansões. O `bin\x64\witcher3.exe` rodou direto, com `SteamAppId`/`SteamGameId`, enquanto a Steam da garrafa
estava aberta.

| Backend | Resultado |
|---|---|
| DXMT ("Automático") | **Início jogável.** Menu principal em português a 60 FPS (GPU abaixo de 1 ms); menus de jogo novo, dificuldade e tutoriais; as cenas do prólogo no motor do jogo a 58–60 FPS, GPU de 12–17 ms por quadro, nos ajustes que o jogo escolheu (1470×956). |
| DXVK | não tentado (o DXMT já roda o jogo). |

Não conferido: a versão atual (DX12) com D3DMetal, combate e áreas abertas, o REDprelauncher que a Steam abre neste
ramo (o jogo foi aberto direto).

## O mesmo vale para

Resident Evil 4 Remake e Hogwarts Legacy também são só D3D12 (não testados por isso).

## Caminhos

1. Ramo beta "classic" (1.32, DX11) na Steam: roda com DXMT (15/10/2026, acima).
2. D3D12 no motor: o DXMT trabalha num D3D12 experimental depois da v0.80 (licença LGPL a partir daí); ou o
   D3DMetal do usuário na revisão 2.
3. O launcher que trava pode ser evitado com a opção de abertura `--launcher-skip` na Steam, quando o jogo em si
   funcionar.
