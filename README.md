# Hash Wallet

**Hash Wallet** (`#`) is an open-source, non-custodial, multi-currency crypto wallet for Android, iOS, macOS, Linux, and Windows. It is a fork of [Cake Wallet](https://github.com/cake-tech/cake_wallet) maintained by [Such Software LLC](https://github.com/Such-Software).

## Why a fork?

Cake Wallet ended Wownero support in early 2026. Hash Wallet exists to keep Wownero as a first-class mobile experience, run by the project's founder, while shipping a slimmer, more focused multi-coin wallet without the chains and integrations we don't want to maintain or recommend.

## Supported chains

* Monero (XMR)
* Wownero (WOW)
* Bitcoin (BTC)
* Litecoin (LTC), incl. MWEB
* Bitcoin Cash (BCH)
* Dogecoin (DOGE)
* Nano (XNO)
* Ethereum (ETH) + ERC-20s
* Polygon (POL)
* Base (BASE)
* Arbitrum (ARB)
* BNB Smart Chain (BSC)

Hardware wallet support: Ledger, Trezor, BitBox.

## What's different from Cake Wallet

**Removed:**
* Solana, Tron, Zano, Zcash, Decred (chain support disabled)
* Lightning Network (deferred — running Greenlight infra is out of scope for now)
* Cake Pay gift cards (Cake Labs–operated service)
* All direct swap-provider integrations except [Trocador](https://trocador.app), which already aggregates ChangeNow, FixedFloat, LetsExchange, Exolix, StealthEx, Quantex, and ~16 others under one privacy-friendly API

**Replaced or planned:**
* Default Monero/Wownero/BTC node lists augmented with community nodes (don't rely on Cake Labs–operated nodes alone)
* Fiat price API replacement (Cake's API → public source) — pending
* Tor / Arti integration improvements — pending

## Build instructions

The build system is unchanged from upstream Cake Wallet. See `docs/` for per-platform instructions:

* Android: `docs/build_android.md`
* iOS: `docs/build_ios.md`
* macOS: `docs/build_macos.md`
* Linux: `docs/build_linux.md`
* Windows: `docs/build_windows.md`

Required Flutter version is pinned in `Dockerfile` (currently 3.32.0). Before the first `flutter pub get`, you must run the prep scripts to clone external native dependencies:

```bash
./scripts/prepare_torch.sh
./scripts/prepare_moneroc.sh
./scripts/prepare_zcash.sh   # still required by build, even though Zcash is disabled
./scripts/build_bitbox_flutter.sh
# Then fetch the prebuilt reown_flutter tarball (CI does this; reproduce locally
# with the URL in .github/workflows/pr_test_build_linux.yml if you have it).
```

Then run the platform-specific configure script, e.g.:

```bash
APP_LINUX_TYPE=cakewallet ./configure_hash_wallet.sh linux
```

## Contributing

Issues and PRs welcome at https://github.com/Such-Software/hash-wallet.

## License

Hash Wallet is distributed under the [MIT License](LICENSE), inheriting from Cake Wallet.

```
Copyright (C) 2018–2023 Cake Labs LLC
Copyright (C) 2026      Such Software LLC
```

Cake Wallet, the Cake Wallet logo, and related marks are trademarks of Cake Labs LLC and are not used by Hash Wallet.
