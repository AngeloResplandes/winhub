[English](../crossover-parity.md) · **Português (Brasil)**

# Paridade com o CrossOver

> **Última revisão:** 2026-10-18 · **WinHub:** `main` (0.2) · **Alvo:** CrossOver 26.3.0 para macOS

O quanto o WinHub se aproxima do CrossOver, dimensão por dimensão. Números "medidos" vêm de testes; os "estimados"
são avaliação, com o motivo ao lado. O motor tem a própria tabela, mais detalhada:
[paridade do motor](https://angeloresplandes.github.io/winhub-engine/pt-BR/crossover-parity.html). A lista de
trabalho está em [Lacunas](gaps.md).

## Resumo

| | Valor | Tipo |
|---|---|---|
| **Paridade do WinHub** (ponderada, abaixo) | **~64%** | estimado |
| Busca do catálogo | os mesmos resultados do CrossOver nos casos comparados | medido |
| Steam e um jogo Direct3D 11 | Steam com login salvo; Hollow Knight pelo DXMT no feature level 11.1 | medido em 2026-10-12 |

## Por dimensão

| Dimensão | Peso | CrossOver 26.3 | WinHub | % | Tipo |
|---|---:|---|---|---:|---|
| Busca do catálogo | 10% | local, padrão `*a*b*`, nomes localizados, 128 resultados | as mesmas regras ([Busca do catálogo](catalog-search.md)) | 100% | medido: os mesmos 8 destaques e os mesmos 16 resultados para `excel` |
| Conteúdo do catálogo | 10% | cerca de 4.500 aplicativos com notas por versão | 35 títulos, 9 destaques, notas dos testes do próprio WinHub (8 relatórios de compatibilidade) | 5% | contagem medida, peso estimado |
| Receitas de instalação | 10% | receitas para milhares de aplicativos | 1 receita (Steam); o formato cobre zip, passos extras, ajustes da garrafa, regras do compatdb, minAppVersion e launches extras ([Receitas](recipes.md)); qualquer `.exe`/`.msi`, winetricks | 30% | estimado |
| Garrafas | 10% | criar, versão do Windows, ajustes, modelos, arquivos | criar a partir de modelos, duplicar, renomear, versão do Windows, Direct3D, msync, HUD, componentes, variáveis e substituições de DLL, ferramentas do próprio Wine, executar comando, exportar e importar no formato próprio do WinHub, `.winhubbottle` | 95% | estimado |
| Steam | 10% | funciona | funciona: wrapper da janela preta, login salvo, jogos abertos pela Steam | 90% | medido |
| Gráficos e motor | 20% | o motor do CrossOver 26.3 | a revisão 3 do motor (`wine-11.0-r3`), o padrão; veja a tabela de paridade do próprio motor | 71% | estimado (paridade do motor) |
| Regras por jogo | 10% | banco curado, atualizado online | regras de Direct3D por programa; o canal do banco assinado funciona e tem 1 regra | 20% | estimado |
| Integração com o Mac | 5% | atalhos dos programas instalados | atalhos `.app` que abrem pelo Finder, pelo Spotlight e pelo Dock | 80% | estimado |
| Atualizações | 5% | app, catálogo e regras | app, catálogo, manifestos e regras assinadas | 95% | estimado |
| Interface e idiomas | 10% | vários idiomas | português do Brasil, inglês e espanhol | 75% | estimado |
| **Ponderado** | 100% | | | **~64%** | estimado |

## Diferenças que são escolhas, não lacunas

| | CrossOver | WinHub | Por quê |
|---|---|---|---|
| D3DMetal | incluído | só o do próprio usuário | a licença da Apple não permite redistribuir |
| Direct3D automático sem D3DMetal | — | DXMT | o DXMT é aberto e cobre o Direct3D 10/11 |
| Banco de regras | cifrado | JSON legível, assinado com Ed25519 | qualquer pessoa pode ler e propor regras |
| Catálogo | o da CodeWeavers | o próprio, versionado neste repositório | sala limpa; toda nota vem de um teste nosso |
| Código | app fechado | MIT, público | |

## Histórico de revisões

| Data | Mudança |
|---|---|
| 2026-10-12 | Primeira avaliação (~53%, revisão 1 do motor como padrão). |
| 2026-10-12 | A revisão 2 do motor vira o padrão: gráficos e motor de 50% para 68%, total ~57%. |
| 2026-10-13 | Garrafas 85% (exportar e importar), interface de 40% para 70% (inglês), a revisão 3 do motor vira o padrão (68% para 71%); total ~61%. |
| 2026-10-16 | Interface de 70% para 75% (espanhol); total ~62%. |
| 2026-10-16 | Garrafas de 85% para 95% (duplicar, renomear, ferramentas do Wine, executar comando, modelos, variáveis e DLLs); total ~63%. |
| 2026-10-18 | Receitas de instalação de 15% para 30% (formato ampliado; ainda 1 receita no catálogo); total ~64%. |
