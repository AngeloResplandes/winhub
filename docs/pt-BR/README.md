[English](../README.md) · **Português (Brasil)**

# Documentação do WinHub

O WinHub é um app nativo para macOS (SwiftUI) que encontra, instala e roda programas e jogos do Windows com o
[Wine](https://www.winehq.org/). Cada programa fica numa "garrafa", um Windows separado com as próprias
configurações, e o WinHub cuida de tudo o que o Wine precisa: o motor, as garrafas, os instaladores, os
componentes do Windows, o Direct3D e atalhos que abrem pelo Finder, pelo Spotlight ou pelo Dock.

O WinHub foi construído estudando **como o CrossOver 26.3 se comporta** (a busca do catálogo, como ele monta as
garrafas e como escolhe o Direct3D de cada jogo) e reproduzindo esse comportamento com código aberto. Nenhum
código ou dado do CrossOver é usado. A parte desse trabalho que toca o motor fica no
[winhub-engine](https://github.com/AngeloResplandes/winhub-engine).

## Por onde começar

| Se você quer… | Leia |
|---|---|
| Entender como o app é organizado | [Arquitetura](architecture.md) |
| Compilar, testar e rodar a partir do código | [Desenvolvimento](development.md) |
| Escolher o Direct3D de um jogo | [Gráficos](graphics.md) |
| Saber exatamente como a busca do catálogo funciona | [Busca do catálogo](catalog-search.md) |
| Ver o que foi estudado no CrossOver e como | [Engenharia reversa](reverse-engineering.md) |
| Ver o quanto o WinHub se aproxima do CrossOver | [Paridade com o CrossOver](crossover-parity.md) e [Lacunas](gaps.md) |
| Saber por que as coisas são como são | [Decisões](decisions.md) |
| Ver como jogos específicos rodam | [Relatórios de compatibilidade](compat/README.md) |

## Os dois repositórios

| Repositório | O que guarda |
|---|---|
| [`AngeloResplandes/winhub`](https://github.com/AngeloResplandes/winhub) (este) | O app: catálogo, garrafas, instaladores, ajustes, atualizações |
| [`AngeloResplandes/winhub-engine`](https://github.com/AngeloResplandes/winhub-engine) | O motor Wine que o WinHub baixa: Wine 11 das fontes LGPL do CrossOver, DXMT, DXVK e o `winhubcompat`, que escolhe o Direct3D de cada processo ([documentação](https://angeloresplandes.github.io/winhub-engine/pt-BR/)) |
