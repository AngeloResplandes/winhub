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

## Testar com o `scripts/game-test.swift`

O script faz o papel da pessoa no Mac: abre um jogo pela Steam aberta na garrafa, escolhe o Direct3D dele (a mesma
regra por programa que o WinHub escreve), acha e captura a janela, manda teclas e cliques como eventos do macOS (os
jogos recebem como entrada de verdade, ao contrário do `SendInput` dentro do Wine), diz qual Direct3D o processo
carregou e lê o FPS médio no log do Metal HUD.

```bash
swiftc -O scripts/game-test.swift -o .build/game-test
.build/game-test launch "<pasta da garrafa>" 570940
.build/game-test wait "dark souls"          # id da janela, pid, tamanho
.build/game-test focus <id>; .build/game-test key e; .build/game-test key w 2
.build/game-test shot <id> captura.png 900
.build/game-test fps <pid> 8                # precisa de MTL_HUD_ENABLED=1 e MTL_HUD_LOG_ENABLED=1 na garrafa
```

O que aprendemos usando:

- A pessoa não pode usar o Mac durante uma rodada: o jogo ocupa a tela e toda tecla vai para o app da frente.
- Olhe uma captura antes de cada passo que pode perder progresso. **Nunca encerre o processo de um jogo enquanto um
  save pode estar sendo gravado**; volte antes à tela de título pelo menu do próprio jogo, e use um espaço de save
  novo, nunca o da pessoa.
- O clone da garrafa não isola todos os saves: `C:\users\<usuário>\Documents` aponta para a `~/Documents` do Mac,
  então jogos que salvam ali (Dark Souls Remastered: `Documents\NBGI`) dividem o arquivo com a garrafa original e
  com o Steam Cloud. Faça backup antes.
- Abra a Steam com `open -a <o WinHub.app em teste> "winhub://open?…"`; um `open` simples pode entregar o link a
  outro WinHub (por exemplo, o `/Applications/WinHub.app`).
- O log do Metal HUD traz o número do quadro, mas esconde o tempo do quadro; o `fps` divide quadros por segundos. Só
  os motores que apresentam pela camada do Metal HUD informam (o D3DMetal informou; DXMT e DXVK às vezes mostram
  `inf`).
