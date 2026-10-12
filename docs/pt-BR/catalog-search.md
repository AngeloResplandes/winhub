[English](../catalog-search.md) · **Português (Brasil)**

# Busca do catálogo

A busca do catálogo do WinHub reproduz como a tela "instalar um aplicativo do Windows" do CrossOver 26.3 pesquisa
o próprio catálogo. Esta página é a especificação, em termos de comportamento; como isso foi aprendido está em
[Engenharia reversa](reverse-engineering.md#busca-do-catálogo).

Código: [`CatalogSearchEngine`](https://github.com/AngeloResplandes/winhub/blob/main/Sources/WinHubCore/CatalogSearchEngine.swift)
e [`WildcardPattern`](https://github.com/AngeloResplandes/winhub/blob/main/Sources/WinHubCore/WildcardMatcher.swift).
Testes: [`SearchEngineTests`](https://github.com/AngeloResplandes/winhub/blob/main/Tests/WinHubCoreTests/SearchEngineTests.swift).

## Regras

1. **Local e incremental.** A busca roda na memória, sobre o catálogo carregado, enquanto você digita; nada vai
   para a rede.
2. **Só o nome.** O nome é o do idioma do usuário (`localizedNames`, por `Locale.preferredLanguages`), com o nome
   padrão como reserva. Resumo e categoria não são pesquisados.
3. **Palavras em ordem.** O texto é aparado e dividido nos espaços, e vira o padrão `*palavra1*palavra2*`:
   `half life` acha "Half-Life 2", mas não "Life is Strange: Half". `*` e `?` digitados pelo usuário valem como
   texto.
4. **Sem diferenciar maiúsculas, acentos e largura**, com a semântica do `LIKE[cd]` do Foundation. `excel` também
   acha "Excellent", porque o padrão casa em qualquer parte do nome.
5. **Busca vazia mostra os destaques** (`isFeatured`), em "Destaques".
6. **Títulos sem teste aparecem por padrão.** Com **Mostrar apps sem teste** desligado, os títulos com nota "Sem
   teste" (0) ou "Não instala" (1) somem.
7. **Ordem natural pelo nome** (`localizedStandardCompare`): "Game 9" vem antes de "Game 10".
8. **No máximo 128 resultados.** A tela avisa quando há mais.

## Notas

| Valor | No app | Some sem "Mostrar apps sem teste" |
|---:|---|---|
| −1 | Fonte não confiável | não |
| 0 | Sem teste | sim |
| 1 | Não instala | sim |
| 2 | Instala, mas não abre | não |
| 3 | Funciona com limitações | não |
| 4 | Bom | não |
| 5 | Excelente | não |

## Diferenças em relação ao CrossOver

| | CrossOver 26.3 | WinHub |
|---|---|---|
| Catálogo | o próprio (milhares de entradas), baixado e assinado pela CodeWeavers | o `catalog.json` do WinHub (31 títulos hoje), baixado deste repositório |
| Escape | — | `\` também escapa o caractere seguinte |
| Notas | medalhas por versão do CrossOver | uma nota por título, dos testes do próprio WinHub |

O catálogo do CrossOver nunca é lido, copiado ou redistribuído.
