# Contributing to Hash Bags

Thanks for the interest. Before opening a PR, please read this.

## Project shape

Hash Bags is a **friendly fork** of [Cake Wallet](https://github.com/cake-tech/cake_wallet). We periodically merge upstream changes and try to keep our divergence narrow. Every change you propose should be evaluated through that lens: will this make future upstream syncs harder, and if so, is the value worth the cost?

## Branch model

- `dev` is the integration branch — open PRs against `dev`.
- `main` is reserved for tagged releases.
- We do not use long-lived feature branches. Iterate on `dev` directly via small focused PRs.

## Build environment

See the build section of [`README.md`](README.md). Flutter version is pinned (`.tool-versions` + `Dockerfile`). Don't use a newer Flutter SDK — Cake's `hive_generator` / `build_resolvers` deps fail on Dart 3.10+ because the `_macros` pseudo-package was removed.

If you use `mise` or `asdf`, the right Flutter version will activate automatically.

## Generated code

Several layers use code generation (MobX stores, Hive type adapters, JSON serializers, configure.dart-generated wallet entry points). Regenerate with:

```bash
dart pub run build_runner build --delete-conflicting-outputs
```

For the wallet-types and pubspec generation:

```bash
dart run tool/configure.dart --monero --wownero --bitcoin --bitcoinCash \
  --ethereum --polygon --base --arbitrum --bsc --nano --dogecoin
```

(That's the canonical Hash Bags build flag set. Don't pass `--solana`, `--tron`, `--zano`, `--decred`, or `--zcash` — those packages were deleted.)

## Code style

- Match the surrounding style. We have not introduced new lints beyond Cake's.
- New observable state goes through MobX; persisted state through Hive.
- Don't add new top-level analytics. Hash Bags ships with no telemetry by design.
- Don't import `package:cw_zano/`, `package:cw_tron/`, `package:cw_solana/`, `package:cw_decred/` — those packages are deleted. The corresponding `WalletType.*` enum values still exist in `cw_core/lib/wallet_type.dart` for backwards-compat but are never instantiated.
- Avoid adding `cake_*`-prefixed file or symbol names in new code. Use `hash_wallet`-prefixed where the symbol is ours, and leave Cake-prefixed names alone where they're inherited (so upstream merges still apply cleanly).

## What we generally won't accept

- Re-enabling Solana, Tron, Zano, Decred, or Zcash. The fork exists in part to drop these — opening that door defeats the purpose.
- New buy/sell provider integrations that require routing through Cake's `exchange-helper.cakewallet.com` proxy. Direct provider APIs are fine if we can register Hash Bags / Such Software LLC as the partner.
- Lightning Network integration. Greenlight (and self-hosted alternatives) require running infrastructure we're not in a position to operate yet.
- Cake Pay re-enable. The infrastructure is Cake Labs's; we can't run it.
- New defaults that point at `cakewallet.com` hosts. We're moving away from depending on Cake's infrastructure — community nodes, our own proxies (`exchange-helper.such.software`, `prices.neroswap.com`), or both, are preferred.
- Anything that adds telemetry, push notifications via third-party SDKs, or remote bulletin services that the user can't audit.

## What we want

- Wownero polish (every paper cut counts — it's the reason this fork exists).
- Build reproducibility improvements (especially Docker / CI parity).
- Privacy-leaning defaults (own-node guidance, Tor/I2P integration improvements, fewer outbound calls).
- Wallet-core bug fixes — these we will happily upstream to Cake.
- Documentation, especially around the build pipeline and the Cake → Hash Bags diff.

## Reporting bugs

Open an issue at https://github.com/Such-Software/hash-wallet/issues. Please include:

- Build artifact ID (the CI workflow names the artifact by commit SHA).
- Platform + OS version.
- Terminal output if you built and ran from a terminal — many error popups don't print to stderr; check `<appDir>/error.txt` (typically `~/.config/hash_wallet/error.txt` on Linux).
- Whether the bug also reproduces in the latest Cake Wallet build (so we know whether it's a Cake-upstream bug or a Hash Bags regression).

## Security disclosures

See [`docs/SECURITY.md`](docs/SECURITY.md). Email `support@such.software` for anything sensitive; do not open a public issue for unpatched vulnerabilities.

## License

By contributing, you agree your contribution is licensed under the [MIT License](LICENSE.md), the same as the rest of Hash Bags.
