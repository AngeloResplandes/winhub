**English** · [Português (Brasil)](pt-BR/catalog-search.md)

# Catalog search

The search in WinHub's catalog reproduces how the "install a Windows application" screen of CrossOver 26.3
searches its own catalog. This page is the specification, in terms of behaviour; how it was learned is in
[Reverse engineering](reverse-engineering.md#catalog-search).

Code: [`CatalogSearchEngine`](https://github.com/AngeloResplandes/winhub/blob/main/Sources/WinHubCore/CatalogSearchEngine.swift)
and [`WildcardPattern`](https://github.com/AngeloResplandes/winhub/blob/main/Sources/WinHubCore/WildcardMatcher.swift).
Tests: [`SearchEngineTests`](https://github.com/AngeloResplandes/winhub/blob/main/Tests/WinHubCoreTests/SearchEngineTests.swift).

## Rules

1. **Local and incremental.** The search runs in memory over the loaded catalog while you type; nothing goes to
   the network.
2. **Only the name.** The name is the one in the user's language (`localizedNames`, by `Locale.preferredLanguages`),
   falling back to the default name. Summary and category are not searched.
3. **Words in order.** The text is trimmed and split on whitespace, and becomes the pattern `*word1*word2*`:
   `half life` finds "Half-Life 2" but not "Life is Strange: Half". `*` and `?` typed by the user are matched
   literally.
4. **Ignoring case, accents and width**, with the semantics of Foundation's `LIKE[cd]`. `excel` also finds
   "Excellent", because the pattern matches anywhere in the name.
5. **Empty search shows the featured titles** (`isFeatured`), under "Destaques".
6. **Untested titles are shown by default.** With **Mostrar apps sem teste** off, titles rated "Sem teste" (0) or
   "Não instala" (1) are hidden.
7. **Natural order by name** (`localizedStandardCompare`): "Game 9" comes before "Game 10".
8. **At most 128 results.** The screen says when there are more.

## Ratings

| Value | In the app | Hidden without "Mostrar apps sem teste" |
|---:|---|---|
| −1 | Fonte não confiável | no |
| 0 | Sem teste | yes |
| 1 | Não instala | yes |
| 2 | Instala, mas não abre | no |
| 3 | Funciona com limitações | no |
| 4 | Bom | no |
| 5 | Excelente | no |

## Differences from CrossOver

| | CrossOver 26.3 | WinHub |
|---|---|---|
| Catalog | its own (thousands of entries), downloaded and signed by CodeWeavers | WinHub's `catalog.json` (35 titles today), downloaded from this repository |
| Escaping | — | `\` also escapes the next character |
| Ratings | medals per CrossOver version | one rating per title, from WinHub's own tests |

The CrossOver catalog is never read, copied or redistributed.
