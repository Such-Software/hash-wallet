# Privacy Policy

**Effective: July 2, 2026**

The canonical, always-current version of this policy is published at
**https://hash.boats/privacy**. This file mirrors it for the source repository;
if the two ever differ, the hosted version at hash.boats/privacy controls.

Such Software LLC ("we", "us", or "our") publishes Hash Bags, a non-custodial
multi-chain wallet. Our privacy philosophy is simple: we cannot leak or misuse
data that we do not collect.

## The short version

Hash Bags is a non-custodial wallet. Your seed phrase and private keys live on
your device and never touch us. We don't run servers that store user data. We
run no analytics, no automatic telemetry, and no crash-reporting SDK — the only
diagnostic data we ever receive is an error report you choose to send us (see
"Opt-in error reports" below). There are no accounts, emails, passwords, or
logins.

Where data *does* leave your device, it goes to (a) the blockchain nodes you
query, and (b) third-party services you explicitly opt in to — Trocador for
swaps and, where available, MoonPay for buying and selling with fiat. Those
providers have their own privacy policies.

## What Hash Bags itself collects

**Nothing.** Hash Bags has no backend. There are no accounts, no servers we run
that your wallet contacts for tracking, and no analytics SDK embedded in the
app (no Sentry, Firebase Analytics, Crashlytics, Amplitude, Mixpanel, Google
Analytics, or equivalent).

The one exception is outside our control: if you install Hash Bags from the
Apple App Store or Google Play, those stores may give us aggregate, anonymized
statistics (download counts, crash rates, OS versions) based on your device's
settings. That data comes from Apple and Google, is not individually
identifying, and is not something Hash Bags collects or transmits.

## Opt-in error reports

If Hash Bags hits an unexpected error, it may ask whether you'd like to send us
a report. Nothing is sent unless you tap "Send" — which copies a technical error
trace to your clipboard and opens hash.boats/report in your browser, where you
paste it and submit. The report contains a technical stack trace, the wallet
*type* (e.g. "monero" — not an address), and your device model, OS version, and
app version. It does **not** contain your seed phrase, private keys, PIN,
addresses, or balances. We store the submitted report on our own server and
relay it to our team to fix bugs; the receiving endpoint also sees your IP
address, as any web request does. To have a report you sent deleted, email
support@such.software.

## What stays on your device

Your seed phrase/mnemonic, derived private keys and addresses, local transaction
history, wallet labels and contacts, app preferences, and your PIN/biometric
state. These are stored in your device's secure storage (Keychain on iOS/macOS,
Keystore on Android, encrypted file storage on Windows/Linux). They are not
transmitted anywhere by Hash Bags. Uninstalling the app deletes them; your seed
phrase still restores the wallet elsewhere.

## What goes over the network when you use the app

- **Blockchain node queries.** To show balances and broadcast transactions, the
  app connects to nodes. The operator of whichever node you use can see your IP
  address and the queries you make. You can switch to a node you trust or run
  your own. For maximum privacy we recommend running your own node.
- **Price data.** The app fetches exchange rates from `prices.neroswap.com`, a
  service we operate that aggregates public sources. It sees your IP and the
  currencies you display — not your addresses or balances.
- **Trocador (swaps).** When you start a swap, order details (input/output coin,
  amount, receiving address) are sent to Trocador's API. Trocador is an
  independent controller with its own policy at
  https://trocador.app/en/privacypolicy/.
- **MoonPay (buying/selling with fiat, where available).** Optional; may not be
  offered in every region or version. The flow opens in your external browser
  and the transaction is with MoonPay. MoonPay independently performs KYC/AML and
  collects your identity and payment data directly (name, date of birth, address,
  government ID, payment details, possibly a selfie, and your IP). **That data is
  held by MoonPay, not us.** To build the MoonPay link, the app calls a signing
  endpoint we operate at `exchange-helper.such.software`, which sees your IP and
  the order parameters (currencies, amount, wallet address) — not your ID or
  payment details. MoonPay's policy: https://www.moonpay.com/legal/privacy_policy
- **WalletConnect (dApps, EVM chains).** If you connect to a third-party dApp,
  your wallet address and the requests you approve are shared with that dApp and
  the WalletConnect relay; those endpoints may see your IP.

## Children

Hash Bags is not directed to people under 18 and we do not knowingly collect
data from minors. Uninstalling the app removes all local data.

## Your rights

Because we don't run accounts or store personal data about you on our servers,
there is generally nothing for us to delete or export. To the extent we ever act
as a controller of any personal data (e.g. a support email you send us), EU/UK
and California residents may contact support@such.software to exercise applicable
rights. For data held by third parties you used through the app (Trocador,
MoonPay, node operators), contact those providers directly.

## Changes

We'll post any update to this policy with a new effective date at
https://hash.boats/privacy and mirror it here.

## Contact

Privacy questions: **support@such.software**

Hash Bags is developed and maintained by Such Software LLC.
