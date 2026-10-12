#!/usr/bin/env bash
set -Eeuo pipefail
set +x

if [[ $# -ne 1 || -z "$1" ]]; then
  echo "Usage: $0 vault-dns-name" >&2
  exit 2
fi
command -v openssl >/dev/null || { echo "openssl is required." >&2; exit 2; }

dns_name="$1"
if [[ ! "$dns_name" =~ ^[A-Za-z0-9.-]+$ || "$dns_name" == *.example.invalid ]]; then
  echo "Provide the real DNS name that will appear in the Vault TLS certificate." >&2
  exit 2
fi

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
pki_dir="${VAULT_PKI_DIR:-${HOME}/.config/online-boutique-vault/pki}"
case "${pki_dir}/" in
  "${repo_root}/"*) echo "Refusing to write private keys inside the repository." >&2; exit 2 ;;
esac
requested_parent="$(dirname "$pki_dir")"
missing_parent_parts=()
while [[ ! -d "$requested_parent" ]]; do
  missing_parent_parts=("$(basename "$requested_parent")" "${missing_parent_parts[@]}")
  requested_parent="$(dirname "$requested_parent")"
done
parent_dir="$(cd "$requested_parent" && pwd -P)"
for part in "${missing_parent_parts[@]}"; do parent_dir="${parent_dir}/${part}"; done
pki_dir="${parent_dir}/$(basename "$pki_dir")"
case "${pki_dir}/" in
  "${repo_root}/"*) echo "Refusing to write private keys inside the repository." >&2; exit 2 ;;
esac
if [[ -e "$pki_dir" ]]; then
  echo "Refusing to overwrite existing PKI material at the selected path." >&2
  exit 2
fi

umask 077
mkdir -p "$pki_dir"
chmod 700 "$pki_dir"
openssl genpkey -algorithm RSA -aes-256-cbc -pkeyopt rsa_keygen_bits:3072 \
  -out "$pki_dir/ca.key"
openssl req -x509 -new -key "$pki_dir/ca.key" -sha256 -days 365 \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -subj "/CN=Online Boutique Vault Lab CA" -out "$pki_dir/ca.crt"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 \
  -out "$pki_dir/vault.key"
openssl req -new -key "$pki_dir/vault.key" -subj "/CN=${dns_name}" \
  -out "$pki_dir/vault.csr"
cat >"$pki_dir/vault.ext" <<EOF
[v3_server]
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:${dns_name}
EOF
openssl x509 -req -in "$pki_dir/vault.csr" -CA "$pki_dir/ca.crt" \
  -CAkey "$pki_dir/ca.key" -CAcreateserial -out "$pki_dir/vault.crt" \
  -days 90 -sha256 -extfile "$pki_dir/vault.ext" -extensions v3_server
chmod 600 "$pki_dir/ca.key" "$pki_dir/vault.key"
chmod 644 "$pki_dir/ca.crt" "$pki_dir/vault.crt"
echo "TLS material created outside the repository at $pki_dir."
echo "Protect ca.key and vault.key; provide their paths only through local environment variables."
