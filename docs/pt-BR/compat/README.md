[English](../../compat/README.md) · **Português (Brasil)**

# Relatórios de compatibilidade

Resultados nossos, medidos no WinHub. Cada relatório diz o Mac, o motor, a garrafa e o build do jogo, o que foi
tentado e o que funcionou, para poder ser reproduzido. As notas do catálogo e as recomendações de Direct3D por jogo
vêm destes relatórios.

| Jogo | Direct3D | Resultado | Melhor escolha |
|---|---|---|---|
| [Hollow Knight](hollow-knight.md) | 11 (Unity 6) | roda, 60 FPS | DXMT só no jogo |
| [The Witcher 3](the-witcher-3.md) | só 12 | instala, não abre | precisa do D3DMetal ou de Direct3D 12 no motor |

## Como escrever um relatório

1. Teste num clone APFS da garrafa, com uma Steam aberta por vez ([por quê](../decisions.md#2026-10-11-nunca-abrir-duas-steams-da-mesma-garrafa)).
2. Registre: data, Mac e macOS, motor (o id no `runtimes.json`), ajustes da garrafa, build do jogo e versão do
   Direct3D.
3. Para cada Direct3D tentado: abre ou não, medições (Metal HUD: `MTL_HUD_ENABLED=1`) e as linhas relevantes do
   log.
4. Termine com o que o WinHub deve fazer (nota no catálogo, `steamGame.graphics`, uma regra).
5. Escreva a página em inglês em `docs/compat/` e o espelho em `docs/pt-BR/compat/`.
