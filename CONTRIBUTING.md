**English** · [Português (Brasil)](CONTRIBUTING.pt-BR.md)

# Contributing

Thanks for your interest in WinHub.

## Clean-room rules (required)

- **We study CrossOver for behaviour only:** what it does, how its bundle is laid out, which files and settings
  it uses. Findings go in [`docs/reverse-engineering.md`](docs/reverse-engineering.md), described as behaviour.
- **Never copy** CrossOver code, scripts, texts, translations, icons or data. This includes its catalog
  (`crossover.tie`), its compatibility database (`compatdb-*.dat`, encrypted; never decrypt it) and its interface.
- **Code CodeWeavers publishes under the LGPL** (CrossOver's Wine tree) is used by winhub-engine, with attribution.
- **Do not commit** decompiled code, addresses, internal symbol names or analysis logs. Names that appear in public
  material (variables read by the LGPL code, file names in the bundle) may be quoted.
- **Never redistribute Apple's D3DMetal.**
- **No third-party binaries in the repository.** Components are downloaded at run time from the official source,
  with their SHA-256 in the manifest, and listed in [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md).

By opening a pull request you state that the contribution is yours and follows these rules.

## Development

See [Development](docs/development.md). Before a pull request:

- `swift build` and `swift test` pass;
- a UI change was checked in the packaged app (`./scripts/package-app.sh`, `open dist/WinHub.app`);
- changes to the published JSON (`catalog.json`, `runtimes.json`, `components.json`) stay decodable by older app
  versions.

## Catalog recipes

Recipes (how to install a program) live in `Sources/WinHub/Resources/catalog.json`. Describe only steps you tested
yourself and use only the vendor's official download URLs. A game's rating and Direct3D recommendation should come
with a [compatibility report](docs/compat/README.md).

## Documentation

English and Brazilian Portuguese are kept in step: every page in `docs/` has its mirror in `docs/pt-BR/`, and
every root page its `.pt-BR.md`. Change both in the same pull request.

## Commits

Small and focused, with an English subject in the imperative mood.
