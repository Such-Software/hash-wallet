#!/usr/bin/env bash
# Demo-wallet secret retrieval from the self-hosted Vaultwarden.
#
# The demo wallet is a REAL wallet with a REAL balance -- that is what makes
# the screenshots honest. Its seed therefore never lands in this repo, in
# .secrets.g.dart, in a shell history, or in a committed env file. It is
# fetched at capture time, held in a shell variable for the life of one
# capture run, and passed to the app as a --dart-define.
#
# Sourced by capture.sh; not meant to be run directly.
#
# Configuration lives in tools/demo/demo.env (gitignored). Copy
# demo.env.example and fill it in. Per ~/src/docs/engineering/
# developer-workstations.md: human credentials in Vaultwarden, ignored
# development values beside the worktree, only reviewed templates committed.

# ---------------------------------------------------------------------------
# bw CLI bootstrap
# ---------------------------------------------------------------------------
demo_secrets_check() {
  if ! command -v bw >/dev/null 2>&1; then
    cat >&2 <<'EOF'
ERROR: the Bitwarden CLI (`bw`) is not installed, so the demo wallet seed
cannot be fetched from Vaultwarden.

Install one of:
    npm install -g @bitwarden/cli
    sudo snap install bw

Then point it at the self-hosted server and log in (do this once):
    bw config server "$VAULTWARDEN_SERVER"     # value lives in tools/demo/demo.env
    bw login
    export BW_SESSION=$(bw unlock --raw)

Alternatively, for a one-off run you can bypass Vaultwarden entirely:
    DEMO_WALLET_SEED='word word ...' tools/demo/capture.sh record core_store_set

...but do not put that in a file, and do not leave it in your shell history
(prefix the command with a space if HISTCONTROL=ignorespace).
EOF
    return 1
  fi
  return 0
}

# demo_secret <field-name>
#
# Resolution order:
#   1. An already-exported env var of the same name (CI / one-off override).
#   2. A custom field on the Vaultwarden item named $VAULTWARDEN_ITEM.
#   3. The item's password/notes, when the field name is `seed`.
demo_secret() {
  local field="$1"
  local envname
  envname="$(echo "$field" | tr '[:lower:]-' '[:upper:]_')"

  # 1. explicit override
  local existing="${!envname:-}"
  if [[ -n "$existing" ]]; then
    printf '%s' "$existing"
    return 0
  fi

  demo_secrets_check || return 1

  if [[ -z "${BW_SESSION:-}" ]]; then
    echo "ERROR: BW_SESSION is not set. Unlock the vault first:" >&2
    echo "    export BW_SESSION=\$(bw unlock --raw)" >&2
    return 1
  fi

  local item="${VAULTWARDEN_ITEM:-hash-bags-demo-wallet}"
  local json
  if ! json="$(bw get item "$item" 2>/dev/null)"; then
    echo "ERROR: no Vaultwarden item named '$item'." >&2
    echo "Create it and store the demo wallet seed there, or set" >&2
    echo "VAULTWARDEN_ITEM in tools/demo/demo.env." >&2
    return 1
  fi

  # Prefer an explicitly named custom field.
  local value
  value="$(printf '%s' "$json" | python3 -c '
import json, sys
field = sys.argv[1]
data = json.load(sys.stdin)
for f in (data.get("fields") or []):
    if (f.get("name") or "").lower() == field.lower():
        print(f.get("value") or "", end="")
        sys.exit(0)
# fall back to notes / password for the seed itself
if field.lower() in ("seed", "demo_wallet_seed"):
    print((data.get("notes") or (data.get("login") or {}).get("password") or ""), end="")
' "$field")"

  if [[ -z "$value" ]]; then
    echo "ERROR: Vaultwarden item '$item' has no field '$field'." >&2
    return 1
  fi
  printf '%s' "$value"
}

# Load the gitignored local config if present.
demo_load_env() {
  local envfile="$1"
  if [[ -f "$envfile" ]]; then
    # shellcheck disable=SC1090
    set -a; source "$envfile"; set +a
  fi
}
