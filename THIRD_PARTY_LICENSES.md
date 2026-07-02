# Third-Party Licenses

Hash Bags' own application code is licensed under the **MIT License** (see
[`LICENSE.md`](LICENSE.md)), inherited from its upstream project,
[Cake Wallet](https://github.com/cake-tech/cake_wallet).

The Hash Bags app, however, **bundles and links third-party open-source
software under other licenses**. The app as a whole is therefore *not* solely
MIT-licensed. The most significant non-MIT components are listed below. All of
these licenses permit commercial redistribution; several (BSD-3-Clause,
Apache-2.0, LGPL-3.0) carry attribution/notice obligations that this file, the
per-package `LICENSE` files in the repository, and the in-app "Open-source
licenses" screen are intended to satisfy.

This list is representative, not exhaustive. For a complete, generated
inventory of every transitive dependency, run a tool such as
[`flutter_oss_licenses`](https://pub.dev/packages/flutter_oss_licenses) and/or
consult the in-app licenses screen (Flutter's `showLicensePage`).

| Component | Role | License |
|---|---|---|
| Monero wallet core (via [`monero_c`](https://github.com/mrcyjanek/monero_c)) | XMR wallet/crypto core compiled into the app | BSD-3-Clause (The Monero Project) |
| Wownero wallet core (via `monero_c`) | WOW wallet/crypto core compiled into the app | BSD-3-Clause (The Wownero Project) |
| `torch_dart` (`scripts/torch_dart/`) | Tor integration | LGPL-3.0 |
| `reown_walletkit` / reown Flutter (`scripts/reown_flutter/`) | WalletConnect connectivity | Apache-2.0 (Copyright 2024 Reown, Inc.) |
| Assorted Dart/Flutter packages (e.g. `bitcoin_base`, `blockchain_utils`, `on_chain`) | Chain support libraries | Apache-2.0 |
| `cw_*` fork modules (`cw_core`, `cw_bitcoin`, `cw_evm`, …) | First-party fork packages | MIT (Cake Technologies LLC; Such Software LLC) |

## Notices

- **The Monero / Wownero cores (BSD-3-Clause)** require that the copyright
  notice and disclaimer be reproduced in binary distributions. Their license
  texts are carried in the `monero_c` submodules fetched by
  `scripts/prepare_moneroc.sh`.
- **`torch_dart` (LGPL-3.0)** is used as a library; its full license is at
  `scripts/torch_dart/LICENSE`.
- **`reown_walletkit` (Apache-2.0)** — see `scripts/reown_flutter/LICENSE`.

Hash Bags and Such Software LLC names, branding, and logos are **not** covered
by any of these open-source licenses and remain the property of Such Software
LLC.
