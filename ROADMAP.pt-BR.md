[English](ROADMAP.md) · **Português (Brasil)**

# Roadmap do WinHub

**Estágio: 0.2**, publicado a cada push na `main`

> **Última revisão:** 2026-10-16 · **Alvo:** CrossOver 26.3.0 para macOS

Resumo em uma página. Detalhes: [paridade com o CrossOver](docs/pt-BR/crossover-parity.md) (pesos e evidências),
[lacunas](docs/pt-BR/gaps.md) (a lista de trabalho em ordem), [decisões](docs/pt-BR/decisions.md).

## Números principais

| | Valor | Tipo |
|---|---|---|
| **Paridade do WinHub com o CrossOver** | **~63%** | estimado, ponderado por dimensão |
| Busca do catálogo | os mesmos resultados do CrossOver nos casos comparados | medido |
| Steam | instala com um clique; login salvo mantido entre motores | medido |
| Jogo Direct3D 11 | Hollow Knight a 60 FPS pelo DXMT | medido |
| Catálogo | 35 títulos, 1 receita, 8 relatórios de compatibilidade | medido |

## Feito

- Catálogo com busca igual à do CrossOver, receitas, garrafas, qualquer instalador, atalhos, componentes do
  winetricks.
- Janela preta da Steam corrigida com um wrapper; processos órfãos do Wine limpos.
- Atualizações automáticas do app, do catálogo e dos manifestos.
- Direct3D por garrafa e por programa: Wine, DXVK, DXMT; com a revisão 2 do motor, também Automático e D3DMetal,
  escolhidos pelo motor sem nada copiado para as garrafas.
- Banco de regras por jogo assinado, do winhub-engine.
- A revisão 4 do motor (`wine-11.0-r4`) é o motor padrão.
- Ícones dos programas, lidos do `.exe` de cada um, nas listas e nos atalhos `.app`.
- Interface em inglês e em espanhol (String Catalog), seguindo o idioma do macOS; resumos em inglês e em espanhol
  no catálogo.
- Exportar e importar garrafas (`.winhubbottle`).
- Resoluções extras: os modos de tela emulados do Wine (16:9 e outros até o tamanho da tela) por garrafa.
- Ferramentas da garrafa: duplicar e renomear garrafas, modelos para garrafas novas, as ferramentas do próprio Wine,
  "Executar comando" e um editor das variáveis e das substituições de DLL da garrafa.

## Próximos passos

1. **Mais títulos testados:** entradas no catálogo, receitas e um relatório de compatibilidade por jogo.
2. **Versões notarizadas.**

## Histórico de revisões

| Data | Mudança |
|---|---|
| 2026-10-12 | Primeiro roadmap. |
| 2026-10-12 | A revisão 2 do motor é o padrão. |
| 2026-10-12 | Ícones dos programas e resoluções extras prontos. |
| 2026-10-12 | Interface em inglês pronta. |
| 2026-10-12 | Exportar e importar garrafas prontos. |
| 2026-10-13 | A revisão 3 do motor é o padrão; paridade ~61%. |
| 2026-10-15 | A revisão 4 do motor é o padrão. |
| 2026-10-16 | Interface em espanhol pronta; paridade ~62%. |
| 2026-10-16 | Ferramentas da garrafa prontas (duplicar, renomear, ferramentas do Wine, executar comando, modelos, variáveis e DLLs); paridade ~63%. |
