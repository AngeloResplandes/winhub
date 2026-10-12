[English](ROADMAP.md) · **Português (Brasil)**

# Roadmap do WinHub

**Estágio: 0.2**, publicado a cada push na `main`

> **Última revisão:** 2026-10-12 · **Alvo:** CrossOver 26.3.0 para macOS

Resumo em uma página. Detalhes: [paridade com o CrossOver](docs/pt-BR/crossover-parity.md) (pesos e evidências),
[lacunas](docs/pt-BR/gaps.md) (a lista de trabalho em ordem), [decisões](docs/pt-BR/decisions.md).

## Números principais

| | Valor | Tipo |
|---|---|---|
| **Paridade do WinHub com o CrossOver** | **~53%** | estimado, ponderado por dimensão |
| Busca do catálogo | os mesmos resultados do CrossOver nos casos comparados | medido |
| Steam | instala com um clique; login salvo mantido entre motores | medido |
| Jogo Direct3D 11 | Hollow Knight a 60 FPS pelo DXMT | medido |
| Catálogo | 31 títulos, 1 receita | medido |

## Feito

- Catálogo com busca igual à do CrossOver, receitas, garrafas, qualquer instalador, atalhos, componentes do
  winetricks.
- Janela preta da Steam corrigida com um wrapper; processos órfãos do Wine limpos.
- Atualizações automáticas do app, do catálogo e dos manifestos.
- Direct3D por garrafa e por programa: Wine, DXVK, DXMT; com a revisão 2 do motor, também Automático e D3DMetal,
  escolhidos pelo motor sem nada copiado para as garrafas.
- Banco de regras por jogo assinado, do winhub-engine.

## Próximos passos

1. **Usar a revisão 2 do motor** como padrão no `runtimes.json`.
2. **Mais títulos testados:** entradas no catálogo, receitas e um relatório de compatibilidade por jogo.
3. **Interface em inglês** (String Catalogs), depois outros idiomas.
4. **Exportar e importar garrafas.**
5. **Ícones dos programas** nas listas e nos atalhos.
6. **Versões notarizadas.**

## Histórico de revisões

| Data | Mudança |
|---|---|
| 2026-10-12 | Primeiro roadmap. |
