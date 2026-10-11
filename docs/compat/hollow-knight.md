# Hollow Knight (Steam, app 367520): testes no WinHub

Resultados nossos, medidos no WinHub. A versão testada é a do Windows, aberta pela Steam numa garrafa do WinHub.
O jogo também tem versão nativa para Mac.

## Ambiente

| Item | Valor |
|---|---|
| Data | 2026-10-11 |
| Mac | Apple M5, macOS 27.0.1 |
| Motor | WineHQ wine-devel 11.18 (x86_64, Rosetta 2) |
| Garrafa | Steam, Windows 10, wrapper do `steamwebhelper` ativo |
| Jogo | build 22529139, Unity 6000.0.61f1, Direct3D 11 |
| Janela | 1280×720, modo janela (`-screen-fullscreen 0 -screen-width 1280 -screen-height 720`) |

## Resultados

| Backend | Abre? | Medição | Observações |
|---|---|---|---|
| Wine (wined3d, OpenGL) | **Não** | — | `d3d11: failed to create device and context (80004005)` → "Failed to initialize graphics". No log do Wine: `wined3d_device_init Failed to create command stream`. O processo fica preso com a caixa de erro do Unity. |
| DXVK-macOS 1.10.3 | **Sim** | Metal HUD: 60 FPS estáveis (vsync), GPU 1,0–2,1 ms por quadro, 1,47 GB de memória do app | D3D11 "level 11.0". Chega à tela de idioma. O HUD do DXVK mostra cerca de 120 apresentações/s (modo `IMMEDIATE`); o Metal entrega 60 na tela. |
| DXMT v0.80 (motor de teste) | **Sim** | Metal HUD: 60 FPS estáveis (vsync) em 6 amostras ao longo de 12 s, GPU 0,64–1,22 ms por quadro, memória Metal 430–530 MB, app 1,13–1,22 GB | D3D11 "level 11.1", renderer "Apple M5". Overlay da Steam funciona. Aviso inofensivo do Unity: `Failed to create ID3D11Fence`. |

Comparado ao DXVK, o DXMT usou cerca de metade da memória Metal (≈480 MB contra 890 MB) e um pouco
menos de GPU por quadro. Os dois ficam presos em 60 FPS pelo vsync, com muita folga.

O "motor de teste" é o wine-devel 11.18 oficial com dois ajustes:

1. O `winemac.so` foi recompilado com o patch
   `winhub-engine/patches/wine/0001-winemac.drv-Export-a-function-table-for-DXMT.patch`. O patch exporta
   `macdrv_functions` no formato que o DXMT espera e cria uma client surface quando a janela não tem
   `client_view`.
2. O DXMT v0.80 (`dxmt-v0.80-builtin.tar.gz`, SHA-256 `8f260e36…529d`) foi instalado no modo builtin:
   - `d3d11`, `dxgi` e `d3d10core` no lugar das do Wine, em `lib/wine/{x86_64,i386}-windows`;
   - `winemetal.so` e `winemetal.dll` no motor;
   - `winemetal.dll` também em `system32`/`syswow64` da garrafa.

O build "builtin" do DXMT **não funciona** se colocado na pasta do jogo: o Wine vê a marca de builtin e
carrega a própria versão (wined3d) no lugar. Para escolher o backend por jogo, é preciso o build com
`wine_builtin_dll=false`, ou trocar as DLLs no motor.

Ainda não testado: gameplay (Dirtmouth / Forgotten Crossroads), áudio e controle. As teclas injetadas
com `SendInput` dentro do Wine não chegam ao Unity 6 (Input System), então essa parte precisa de alguém
jogando.

## Como reproduzir

- O jogo precisa ser aberto pela Steam. Aberto direto, ele encerra com "Application was not launched
  through Steam!", mesmo com `steam_appid.txt`.
- DXVK só para o jogo, sem mudar a garrafa toda (a interface da Steam continua no wined3d):
  1. Copie `x64/d3d11.dll` e `x64/d3d10core.dll` do DXVK-macOS para a pasta do jogo.
  2. Rode `wine reg add 'HKCU\Software\Wine\AppDefaults\hollow_knight.exe\DllOverrides' /v d3d11 /d native,builtin /f`.
  3. Repita o passo 2 com `d3d10core`.
  4. Abra o jogo com `steam.exe -noverifyfiles -applaunch 367520`.
- Medição: `MTL_HUD_ENABLED=1` (Metal HUD), `DXVK_HUD=fps,devinfo` e `WINEDEBUG=+fps` no ambiente da
  Steam (o jogo herda o ambiente dela).

## Conclusões para o WinHub

- O wined3d não serve para jogos Unity 6 em D3D11 no macOS. Jogos assim precisam de DXVK ou DXMT.
- O DXMT funciona com o Wine oficial 11.18 e o nosso patch no `winemac.drv`. É o melhor resultado
  medido até agora.
- Falta verificar a interface da Steam aberta já com o DXMT no motor. Neste teste, o processo principal
  da Steam tinha começado antes da troca das DLLs.
- O backend precisa poder ser escolhido **por jogo** dentro da garrafa da Steam (`AppDefaults` no
  registro), porque trocar a garrafa inteira para DXVK afeta a interface da Steam.
