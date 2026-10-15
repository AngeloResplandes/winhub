[English](../../compat/bioshock-remastered.md) · **Português (Brasil)**

# BioShock Remastered (Steam, app 409710): testes no WinHub

## Ambiente

| Item | Valor |
|---|---|
| Data | 15/10/2026 |
| Mac | Apple M5, macOS 27.0.1 |
| Motor | `winhub-wine-11.0-r3` (Wine 11.0 das fontes do CrossOver, x86_64, Rosetta 2) |
| D3DMetal | não instalado |
| Garrafa | clone APFS da garrafa Steam, Windows 10, msync desligado, Metal HUD ligado, Direct3D "Automático" |
| Jogo | build 8552765, Direct3D 11, **32 bits** (`Build\Final\BioshockHD.exe`) |

## Resultados

| Backend | Abre? | Medição | Notas |
|---|---|---|---|
| DXMT ("Automático"), 32 bits | **Sim** | Logos: 60 FPS, GPU abaixo de 1 ms. Tela de termos da 2K: uns 165 FPS (sem limite), GPU de uns 4 ms | Renderiza em 2560×1664 numa janela de 1470×956. As logos de abertura tocam; o Esc pula. |
| DXVK | não disponível | — | A revisão 3 não oferece DXVK a jogos de 32 bits (precisa do `VK_EXT_map_memory_placed`, que o MoltenVK não tem). |

O teste parou nos termos online da 2K ("I agree to all"), que só a pessoa pode aceitar. A jogabilidade ainda não
foi medida.

## O que o WinHub deve fazer

- Catálogo: ainda não entra; espera um teste de jogo depois dos termos.
- Sem regra: o "Automático" já escolhe o DXMT, que roda o jogo.
