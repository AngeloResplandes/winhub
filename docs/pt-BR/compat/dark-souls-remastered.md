[English](../../compat/dark-souls-remastered.md) · **Português (Brasil)**

# Dark Souls Remastered (Steam, app 570940): testes no WinHub

## Ambiente

| Item | Valor |
|---|---|
| Data | 12/10/2026 e 13/10/2026 |
| Mac | Apple M5, macOS 27 |
| Motor | `winhub-wine-11.0-r2` (Wine 11.0 das fontes do CrossOver, x86_64, Rosetta 2) |
| D3DMetal | Game Porting Toolkit 3.0 da Apple, na pasta da própria pessoa |
| Garrafa | clone APFS da garrafa da Steam, Windows 10, msync ligado, Resoluções extras ligado, Metal HUD ligado, Direct3D "Automático" |
| Jogo | build 10943698 (app 1.03.1), Direct3D 11, 64 bits |

Testado com o [`scripts/game-test.swift`](README.md#testar-com-o-scriptsgame-testswift): o script abriu o jogo pela
Steam, mandou teclas e cliques como eventos do macOS e leu o FPS no Metal HUD.

## Resultados

| Backend | Abre? | Medição | Observações |
|---|---|---|---|
| D3DMetal ("Automático") | **Sim, jogável** | 60 FPS (o limite do jogo), GPU de 8 a 13 ms por quadro no Asilo dos Mortos-vivos | Título, menus, criação de personagem, o vídeo pré-renderizado de abertura, cenas em tempo real e andar no Asilo. Salvar e voltar ao título funciona. |
| DXVK | **Sim, jogável** | 60 FPS (log do Metal HUD), GPU de cerca de 14 ms por quadro no Asilo | As mesmas cenas. |
| DXMT | **Não** | — | Trava durante o fade da tela de título: nenhum quadro novo, e o processo fica em cerca de 110% de CPU. |
| Wine (wined3d) | **Não** | — | O processo abre e fica parado sem janela (o wined3d só chega ao feature level 9_3 no macOS). |

Entrada: o teclado (E confirma, Q volta, setas, Home/End trocam as abas do menu) e o mouse nos menus funcionam. O
Alt+F4 é ignorado; saia por **Sistema → Sair do jogo**. A digitação de texto (nome do personagem) funciona.

O save fica em `Documents\NBGI\DARK SOULS REMASTERED`, que numa garrafa do WinHub é a `~/Documents` do Mac: todas as
garrafas do mesmo usuário do Mac, e o Steam Cloud, dividem o arquivo. Cada espaço de personagem tem um checksum MD5,
que foi como conferimos o arquivo depois dos testes.

## O que o WinHub deve fazer

- Catálogo: nota 5, `steamGame.graphics` = `dxvk`.
- Regra (banco do winhub-engine): `graphics_backend` = `dxvk` para o app 570940 da Steam. Sem o D3DMetal, o
  "Automático" escolheria o DXMT, que trava. O D3DMetal também roda bem, com menos tempo de GPU; a pessoa ainda pode
  escolhê-lo.
