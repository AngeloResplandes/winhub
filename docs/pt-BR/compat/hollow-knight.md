[English](../../compat/hollow-knight.md) · **Português (Brasil)**

# Hollow Knight (Steam, app 367520): testes no WinHub

Resultados nossos, medidos no WinHub. A versão testada é a do Windows, aberta pela Steam numa garrafa do WinHub.
O jogo também tem versão nativa para Mac.

## Ambiente

| Item | Valor |
|---|---|
| Data | 2026-10-11 (revisão 2: 2026-10-12) |
| Mac | Apple M5, macOS 27.0.1 |
| Motor | WineHQ wine-devel 11.18 (x86_64, Rosetta 2); depois `winhub-wine-11.18-r1` e `winhub-wine-11.0-r2` |
| Garrafa | Steam, Windows 10, wrapper do `steamwebhelper` ativo |
| Jogo | build 22529139, Unity 6000.0.61f1, Direct3D 11 |
| Janela | 1280×720, modo janela (`-screen-fullscreen 0 -screen-width 1280 -screen-height 720`) |

## Resultados

| Backend | Abre? | Medição | Observações |
|---|---|---|---|
| Wine (wined3d, OpenGL) | **Não** | — | `d3d11: failed to create device and context (80004005)` → "Failed to initialize graphics". No log do Wine: `wined3d_device_init Failed to create command stream`. O processo fica preso com a caixa de erro do Unity. |
| DXVK-macOS 1.10.3 | **Sim** | Metal HUD: 60 FPS estáveis (vsync), GPU 1,0–2,1 ms por quadro, 1,47 GB de memória do app | D3D11 "level 11.0". Chega à tela de idioma. O HUD do DXVK mostra cerca de 120 apresentações/s (modo `IMMEDIATE`); o Metal entrega 60 na tela. |
| DXMT v0.80 (motor de teste) | **Sim** | Metal HUD: 60 FPS estáveis (vsync) em 6 amostras ao longo de 12 s, GPU 0,64–1,22 ms por quadro, memória Metal 430–530 MB, app 1,13–1,22 GB | D3D11 "level 11.1", renderer "Apple M5". Overlay da Steam funciona. Aviso inofensivo do Unity: `Failed to create ID3D11Fence`. |
| DXMT, motor `winhub-wine-11.18-r1` (versão publicada), **só no jogo** | **Sim** | Metal HUD: 60 FPS em 4 amostras ao longo de 12 s, GPU 0,66–0,67 ms por quadro, memória Metal 427 MB, app 1,14 GB | Fluxo final: o WinHub instala o Wine oficial e o overlay, e `applyProgramGraphics(.dxmt)` põe o DXMT na pasta do jogo, com `AppDefaults\hollow_knight.exe`. A interface da Steam continua no Wine (o processo dela não carrega o `winemetal`) e funciona normalmente. |
| DXMT, motor `winhub-wine-11.0-r2` (build local), **só no jogo** | **Sim** | jogado por uma pessoa | Wine das fontes LGPL do CrossOver; o motor escolhe o DXMT para o jogo pela regra da garrafa, nada copiado para a garrafa. D3D11 "level 11.1". A Steam abriu com o login salvo. O mesmo aviso inofensivo do `ID3D11Fence`. |

Comparado ao DXVK, o DXMT usou cerca de metade da memória Metal (≈480 MB contra 890 MB) e um pouco menos de GPU por
quadro. Os dois ficam presos em 60 FPS pelo vsync, com muita folga.

O "motor de teste" era o wine-devel 11.18 oficial com dois ajustes:

1. O `winemac.so` recompilado com o patch `winhub-engine/patches/wine/0001-winemac.drv-Export-a-function-table-for-DXMT.patch`
   (revisão 1). O patch exporta `macdrv_functions` no formato que o DXMT espera e cria uma client surface quando a
   janela não tem `client_view`.
2. O DXMT v0.80 (`dxmt-v0.80-builtin.tar.gz`, SHA-256 `8f260e36…529d`) instalado no modo builtin:
   - `d3d11`, `dxgi` e `d3d10core` no lugar das do Wine, em `lib/wine/{x86_64,i386}-windows`;
   - `winemetal.so` e `winemetal.dll` no motor;
   - `winemetal.dll` também em `system32`/`syswow64` da garrafa.

O build "builtin" do DXMT **não funciona** se colocado na pasta do jogo: o Wine vê a marca de builtin e carrega a
própria versão (wined3d) no lugar. Para escolher o backend por jogo, é preciso o build com
`wine_builtin_dll=false`, ou trocar as DLLs no motor. A revisão 2 resolve isso de outro jeito: o motor põe a pasta
do DXMT no começo do caminho de DLLs do Wine no processo do jogo.

### Jogando (DXMT)

Testado por uma pessoa jogando, na revisão 1 (2026-10-11) e na revisão 2 (2026-10-12): o jogo roda bem, com som, e
o controle (Xbox 360) é reconhecido. As teclas injetadas com `SendInput` dentro do Wine não chegam ao Unity 6
(Input System), por isso o gameplay não tem teste automático.

### Tela cheia e resolução

- **Resoluções:** o jogo lista os modos que o Wine informa, e o driver de Mac do Wine só oferece os modos do
  próprio macOS. Nesta tela (1470×956 pontos) são 14 modos, de 960×600 a 2560×1664, todos na proporção da tela do
  Mac. **Não há 1920×1080 nem outros modos 16:9.** Desde a opção de garrafa **Resoluções extras** (12/10/2026), o
  Wine também oferece modos emulados; nesta tela, isso acrescenta 960×540 e 1280×720 (conferido com um programa de
  teste que lista os modos; ainda não neste jogo).
- **Tela cheia:** abrir o jogo já em tela cheia funciona nos dois modos do Unity: "tela cheia em janela" e
  exclusiva (a janela ocupa a tela toda, 1470×956). Trocar pelo menu Opções → Vídeo também funcionou: o Wine troca o
  modo do Mac (por exemplo, para 1280×800) e volta ao sair.
- Numa primeira sessão, a troca pelo menu não teve efeito. O jogo tinha começado **em janela** com um tamanho fora
  do padrão (1369×797). Não foi possível reproduzir depois, e nenhum código mudou entre as duas sessões.
- O driver de Mac do Wine só troca o modo de tela quando o app está em primeiro plano; fora dele, guarda a troca
  para depois. Para investigar, reabra a Steam com `WINEDEBUG=fixme-all,+display,warn+win` e veja as linhas de
  `macdrv_ChangeDisplaySettings` e "Setting display mode" (do DXMT).

### 13/10/2026: revisão 2 do motor com D3DMetal, testado por script

Mesmo Mac, motor `winhub-wine-11.0-r2`, D3DMetal do Game Porting Toolkit 3.0 da Apple, um clone da garrafa da Steam
com Resoluções extras ligado, conduzido pelo [`scripts/game-test.swift`](README.md#testar-com-o-scriptsgame-testswift).

| Backend | Resultado |
|---|---|
| D3DMetal ("Automático") | **Jogável.** Menu a cerca de 117 FPS (tela de 120 Hz, limite de 120); um jogo novo num espaço vazio, andar, pular e atacar a 104–120 FPS, GPU de 5 a 7 ms por quadro. |
| DXMT, DXVK | O menu principal aparece (revisão 2). |

- **Modos de tela:** com Resoluções extras, a lista agora tem **1280×720** e **960×540** (16 modos, de 1470×956 a
  640×480). Escolher 1280×720 ocupa a tela, escalado, com faixas finas em cima e embaixo.
- **Entrada:** teclas mandadas como eventos do macOS chegam ao jogo (Input System do Unity), ao contrário do
  `SendInput` dentro do Wine.
- **A cinemática de abertura fica preta:** o Unity registra `WindowsVideoMedia error 0xc00d36bb` para o vídeo; o jogo
  segue depois dela. O motor ainda não decodifica vídeo H.264 (lacuna "Vídeos dos jogos" do winhub-engine).

### 15/10/2026: revisão 3 do motor, "Automático"

Mesmo Mac (macOS 27.0.1), motor `winhub-wine-11.0-r3`, sem D3DMetal, um clone APFS novo da garrafa da Steam (msync
desligado, Metal HUD ligado), sem escolha por programa e sem regra. O "Automático" escolheu o **DXMT** para o jogo
sozinho (`backend-of`: dxmt): a tela de idiomas a 60 FPS, GPU de cerca de 1 ms por quadro. Escolher o DXMT para o
jogo à mão não é mais necessário.

### 16/10/2026: revisão 5 do motor (vídeos dos jogos)

Mesmo Mac, um build local do `winhub-wine-11.0-r5` (idêntico à versão publicada), um clone APFS da garrafa da Steam
com ID próprio. O vídeo do prólogo (**New Game**) agora é **decodificado**: o antigo
`WindowsVideoMedia error 0xc00d36bb` sumiu, o GStreamer escolhe o `vtdec_hw` (H.264) e o `atdec` (AAC), e cerca de
1.260 quadros de 1920×1080 chegam ao jogo. Ele continua **preto**:

| Backend | Log do Unity | O que acontece |
|---|---|---|
| DXMT (Automático) | sem erro; `D3D11Fence is not available, using ID3D11Query` | o Unity pega a textura de cada quadro do Media Foundation num segundo device Direct3D 11 e pede o handle compartilhado; o handle que recebe é nulo, então o device principal não tem o que desenhar |
| DXVK | `WindowsVideoMedia error 0x80070057` a cada quadro | o DXVK-macOS não tem recursos compartilhados (o `GetSharedHandle` falha) |

Um programa de teste pequeno reproduziu cada passo fora do jogo e achou, no caminho, um defeito do DXMT (o
preenchimento de zeros adiado de uma textura compartilhada apaga o que outro device escreveu); corrigir isso não
bastou para o jogo. O trabalho continua no motor ([lacunas do winhub-engine](https://angeloresplandes.github.io/winhub-engine/pt-BR/gaps.html)).
O jogo continua jogável; só os vídeos ficam pretos.

## Como reproduzir

- O jogo precisa ser aberto pela Steam. Aberto direto, ele encerra com "Application was not launched through
  Steam!", mesmo com `steam_appid.txt`.
- No WinHub: na garrafa da Steam, **Gráficos por programa → Escolher programa…** e escolha o `hollow_knight.exe`,
  depois o DXMT; ou clique em **Usar DXMT neste jogo (recomendado)** na página do jogo no catálogo.
- À mão, DXVK só para o jogo num motor antigo (a interface da Steam continua no wined3d):
  1. Copie `x64/d3d11.dll` e `x64/d3d10core.dll` do DXVK-macOS para a pasta do jogo.
  2. Rode `wine reg add 'HKCU\Software\Wine\AppDefaults\hollow_knight.exe\DllOverrides' /v d3d11 /d native,builtin /f`.
  3. Repita o passo 2 com `d3d10core`.
  4. Abra o jogo com `steam.exe -noverifyfiles -applaunch 367520`.
- Medição: `MTL_HUD_ENABLED=1` (Metal HUD), `DXVK_HUD=fps,devinfo` e `WINEDEBUG=+fps` no ambiente da Steam (o jogo
  herda o ambiente dela).

## Conclusões para o WinHub

- **Nota no catálogo:** Bom (4). Gráficos: DXMT só no jogo (`steamGame.graphics` no `catalog.json`; a página do
  jogo oferece "Usar DXMT neste jogo").
- O wined3d não serve para jogos Unity 6 em D3D11 no macOS. Jogos assim precisam de DXVK, DXMT ou D3DMetal.
- O DXMT é o melhor resultado medido até agora, tanto na revisão 1 quanto na revisão 2.
- Com os gráficos por programa, a Steam nunca usa o DXMT; só o jogo usa, então o risco da janela da Steam com DXMT
  deixa de existir.
- O backend precisa poder ser escolhido **por jogo** dentro da garrafa da Steam, porque trocar a garrafa inteira
  afeta a interface da Steam.
