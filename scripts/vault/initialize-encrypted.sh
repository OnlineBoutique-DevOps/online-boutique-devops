#!/usr/bin/env bash
set -Eeuo pipefail
set +x

: "${VAULT_ADDR:?Set the HTTPS Vault address}"
: "${VAULT_CACERT:?Set the trusted CA certificate path}"
: "${GPG_RECIPIENT:?Set a preconfigured GPG public-key recipient}"
for tool in vault gpg jq; do
  command -v "$tool" >/dev/null || { echo "$tool is required." >&2; exit 2; }
done

umask 077
state_dir="${VAULT_INIT_STATE_DIR:-${HOME}/.local/state/online-boutique-vault}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd -P)"
export VAULT_CACERT
case "${state_dir}/" in
  "${repo_root}/"*) echo "Refusing to write recovery material inside the repository." >&2; exit 2 ;;
esac
requested_parent="$(dirname "$state_dir")"
missing_parent_parts=()
while [[ ! -d "$requested_parent" ]]; do
  missing_parent_parts=("$(basename "$requested_parent")" "${missing_parent_parts[@]}")
  requested_parent="$(dirname "$requested_parent")"
done
parent_dir="$(cd "$requested_parent" && pwd -P)"
for part in "${missing_parent_parts[@]}"; do parent_dir="${parent_dir}/${part}"; done
state_dir="${parent_dir}/$(basename "$state_dir")"
case "${state_dir}/" in
  "${repo_root}/"*) echo "Refusing to write recovery material inside the repository." >&2; exit 2 ;;
esac
mkdir -p "$state_dir"
state_dir="$(cd "$state_dir" && pwd -P)"
case "${state_dir}/" in
  "${repo_root}/"*) echo "Refusing to write recovery material inside the repository." >&2; exit 2 ;;
esac
chmod 700 "$state_dir"
output_file="${state_dir}/init-$(date -u +%Y%m%dT%H%M%SZ).json.gpg"
if [[ -e "$output_file" ]]; then
  echo "Encrypted output already exists for this timestamp; refusing to overwrite it." >&2
  exit 1
fi
if ! printf 'vault-init-encryption-preflight' \
  | gpg --batch --yes --trust-model always --encrypt --recipient "$GPG_RECIPIENT" --output /dev/null; then
  echo "GPG recipient preflight failed; Vault was not initialized." >&2
  exit 1
fi

set +e
status_json="$(vault status -format=json 2>/dev/null)"
set -e
if [[ -z "$status_json" ]]; then
  echo "Could not read Vault status. Check endpoint, TLS trust, and network." >&2
  exit 1
fi
if [[ "$(jq -r '.initialized // false' <<<"$status_json")" == "true" ]]; then
  echo "Vault is already initialized; no action taken."
  exit 0
fi

# Init JSON contains unseal shares and the initial root token. Pipe directly
# into GPG: never display or persist the plaintext response.
if vault operator init -format=json \
  | gpg --batch --yes --trust-model always --encrypt --recipient "$GPG_RECIPIENT" \
      --output "$output_file"; then
  chmod 600 "$output_file"
  echo "Vault initialized; encrypted recovery material is outside the repository."
  echo "Transfer it to an approved password manager and remove the local encrypted copy when safe."
else
  rm -f "$output_file"
  echo "Initialization/encryption failed; inspect Vault status before retrying." >&2
  exit 1
fi
