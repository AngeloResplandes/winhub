[English](../graphics.md) · **Português (Brasil)**

# Gráficos (Direct3D)

Jogos do Windows desenham com o Direct3D. No Mac, alguém precisa traduzir o Direct3D para o Metal, e o tradutor
que funciona melhor muda de jogo para jogo. O WinHub deixa você escolher por garrafa e por programa.

## As opções

| No app | O que é | Direct3D | Exige |
|---|---|---|---|
| **Automático** | O motor escolhe o melhor que roda aqui: D3DMetal, depois DXMT, depois o do Wine | — | um motor que escolhe o Direct3D (revisão 2 do winhub-engine) |
| **Wine** | O Direct3D do próprio Wine (wined3d, sobre OpenGL) | até o feature level 9_3 no macOS | nada; o padrão nos motores antigos |
| **DXMT** | [DXMT](https://github.com/3Shain/dxmt): Direct3D direto sobre o Metal | 10, 11 | o motor do WinHub |
| **DXVK** | [DXVK](https://github.com/doitsujin/dxvk): Direct3D sobre Vulkan, pelo MoltenVK | 9 (revisão 2), 10, 11 | revisão 2: incluído, só jogos de 64 bits; motores antigos: o componente DXVK-macOS (2,8 MB, baixado uma vez) |
| **D3DMetal** | O tradutor da Apple, do Game Porting Toolkit | 11, 12 | a sua cópia do Game Porting Toolkit e a revisão 2 |

O Direct3D do próprio Wine só chega ao feature level 9_3 no macOS (OpenGL 4.1), então jogos que exigem Direct3D 11,
como os feitos em Unity 6, precisam de DXMT, DXVK ou D3DMetal ([Hollow Knight](compat/hollow-knight.md)).

## Por garrafa e por programa

- **Gráficos (Direct3D)** nos ajustes da garrafa vale para todos os programas dela.
- **Gráficos por programa** dá a um `.exe` a própria escolha. É assim que um jogo da Steam usa o DXMT enquanto a
  janela da própria Steam fica com a escolha da garrafa.
- Um jogo do catálogo com recomendação testada mostra **Usar … neste jogo (recomendado)**. Nada é aplicado até
  você clicar.

## D3DMetal

O D3DMetal é da Apple e a licença dele não permite redistribuí-lo, então o WinHub nunca o inclui nem o baixa. Se
você tem o Game Porting Toolkit:

1. Abra **Ajustes → D3DMetal (opcional) → Escolher pasta…**.
2. Escolha a pasta do toolkit, a `redist` dele ou a `redist/lib`; o WinHub acha a certa.
3. O **D3DMetal** aparece nas garrafas. No **Automático**, o motor o prefere para jogos de 64 bits.

Se a pasta estiver num disco externo, o D3DMetal só funciona enquanto esse disco estiver montado.

## Sincronização rápida e desempenho

- **Sincronização rápida (MSync)** (revisão 2): sincronização mais barata em jogos limitados pela CPU. Vale na
  próxima vez que um programa abrir. Se a garrafa estiver rodando, encerre-a antes (**Encerrar**): o Wine recusa
  programas com uma configuração diferente da do `wineserver` que já está rodando.
- **Mostrar desempenho (FPS) nos jogos**: o painel de desempenho do Metal (e o do DXVK, quando em uso).

## Como funciona

- **Revisão 2 (`backend-dispatch`).** O WinHub só diz ao motor o que você escolheu (`WINHUB_GRAPHICS_BACKEND`) e
  escreve as escolhas por programa como regras em `<garrafa>/compat-rules.json`. O `winhubcompat` do motor põe o
  tradutor escolhido no começo do caminho de busca de DLLs do Wine em cada processo: nada é copiado para a garrafa,
  do jeito que o CrossOver funciona desde a versão 25. Detalhes: [winhubcompat](https://angeloresplandes.github.io/winhub-engine/pt-BR/compatdb.html).
- **Motores antigos (revisão 1, Wine oficial).** O WinHub copia as DLLs: DXVK ou DXMT para o `system32`/`syswow64`
  da garrafa com overrides `n,b`, ou para a pasta do `.exe` do programa (64 ou 32 bits pelo cabeçalho PE) com
  overrides em `HKCU\Software\Wine\AppDefaults\<exe>\DllOverrides`. Voltar ao Wine restaura as DLLs do motor e
  remove os overrides; DLLs que o próprio jogo traz nunca são apagadas.
- **Migração.** Quando uma garrafa montada para um motor antigo abre um programa na revisão 2, o WinHub desfaz
  antes as cópias e os overrides e transforma as escolhas por programa em regras.
