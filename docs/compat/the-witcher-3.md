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

## Resultado: instala, mas não abre

- **A versão atual é só DirectX 12.** O `launcher-configuration.json` lista apenas `bin\x64_dx12\witcher3.exe`,
  e a pasta `bin\x64` (DX11) não existe. O modo DX11 só existe no ramo beta "classic" da Steam (1.32).
- **Launcher da CD Projekt (`REDlauncher`, Qt WebEngine):** trava ao abrir, com
  `Unhandled exception 0x80000003` (breakpoint), e cai no depurador do Wine. Isso lembra os problemas da
  Steam com o próprio Chromium.
- **Jogo aberto direto (`witcher3.exe` DX12, Steam aberta):** mostra "GPU does not meet minimal
  requirements. Support for DirectX 12 is required." O D3D12 do Wine (vkd3d sobre MoltenVK) não oferece o
  que o jogo exige, e o DXMT v0.80 do motor não tem D3D12.

## O mesmo vale para

Resident Evil 4 Remake e Hogwarts Legacy também são só D3D12 (não testados por isso).

## Caminhos

1. Ramo beta "classic" (1.32, DX11) na Steam, para testar o jogo com DXMT ou DXVK.
2. D3D12 no motor: o DXMT trabalha num D3D12 experimental depois da v0.80 (licença LGPL a partir daí).
3. O launcher que trava pode ser evitado com a opção de abertura `--launcher-skip` na Steam, quando o jogo
   em si funcionar.
