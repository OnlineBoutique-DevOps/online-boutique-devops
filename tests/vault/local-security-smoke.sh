#!/usr/bin/env bash
set -Eeuo pipefail
set +x

for tool in vault openssl jq; do
  command -v "$tool" >/dev/null || { echo "$tool is required for the local Vault smoke test." >&2; exit 2; }
done

test_dir="$(mktemp -d "${TMPDIR:-/tmp}/vault-local-test.XXXXXX")"
server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi
  unset VAULT_TOKEN root_token unseal_key test_token init_json token_json
  rm -rf "$test_dir"
}
trap cleanup EXIT INT TERM
chmod 700 "$test_dir"
mkdir -p "$test_dir/data"
chmod 700 "$test_dir/data"

openssl req -x509 -newkey rsa:2048 -nodes -keyout "$test_dir/vault.key" \
  -out "$test_dir/vault.crt" -days 1 -subj "/CN=localhost" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,digitalSignature,keyEncipherment" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" >/dev/null 2>&1
chmod 600 "$test_dir/vault.key"
cat >"$test_dir/vault.hcl" <<EOF
ui = false
disable_mlock = true
api_addr = "https://127.0.0.1:18200"
cluster_addr = "https://127.0.0.1:18201"
storage "raft" {
  path = "$test_dir/data"
  node_id = "local-test"
}
listener "tcp" {
  address = "127.0.0.1:18200"
  cluster_address = "127.0.0.1:18201"
  tls_cert_file = "$test_dir/vault.crt"
  tls_key_file = "$test_dir/vault.key"
  tls_min_version = "tls12"
}
EOF

export VAULT_ADDR="https://127.0.0.1:18200"
export VAULT_CACERT="$test_dir/vault.crt"
vault server -config="$test_dir/vault.hcl" >"$test_dir/server.log" 2>&1 &
server_pid=$!
ready=false
for _ in $(seq 1 40); do
  status_probe="$(vault status -format=json 2>/dev/null || true)"
  if [[ -n "$status_probe" ]]; then ready=true; unset status_probe; break; fi
  unset status_probe
  sleep 0.25
done
if [[ "$ready" != true ]]; then
  echo "Local Vault did not start; sanitized startup diagnostics follow." >&2
  tail -n 8 "$test_dir/server.log" \
    | sed -E 's#(token|key|secret|password)([=: ]+)[^ ,"]+#\1\2<redacted>#Ig' >&2
  exit 1
fi

# The only init output is held in process memory and is never printed or saved.
init_json="$(vault operator init -key-shares=1 -key-threshold=1 -format=json 2>/dev/null)"
root_token="$(jq -r '.root_token' <<<"$init_json")"
unseal_key="$(jq -r '.unseal_keys_b64[0] // .keys_base64[0]' <<<"$init_json")"
unset init_json
vault operator unseal "$unseal_key" >/dev/null
export VAULT_TOKEN="$root_token"
unset root_token unseal_key

vault secrets enable -path=kv -version=2 kv >/dev/null
vault policy write github-ci-probe "$(cd "$(dirname "$0")/../.." && pwd)/vault/policies/github-ci-probe.hcl" >/dev/null
vault kv put kv/ci/probe status=ready >/dev/null

token_json="$(vault token create -policy=github-ci-probe -ttl=1m -format=json)"
test_token="$(jq -r '.auth.client_token' <<<"$token_json")"
unset token_json
VAULT_TOKEN="$test_token" vault kv get kv/ci/probe >/dev/null 2>&1
[[ "$(VAULT_TOKEN="$test_token" vault token capabilities kv/data/ci/probe)" == *read* ]]
[[ "$(VAULT_TOKEN="$test_token" vault token capabilities kv/data/reviewservice)" == "deny" ]]
if VAULT_TOKEN="$test_token" vault kv get kv/reviewservice >/dev/null 2>&1; then
  echo "Least-privilege check failed: probe identity read the application path." >&2
  exit 1
fi

cat >"$test_dir/revoked-policy.hcl" <<'EOF'
path "kv/data/ci/probe" {
  capabilities = ["deny"]
}
EOF
vault policy write github-ci-probe "$test_dir/revoked-policy.hcl" >/dev/null
if VAULT_TOKEN="$test_token" vault kv get kv/ci/probe >/dev/null 2>&1; then
  echo "Policy-change check failed: updated deny policy did not take effect." >&2
  exit 1
fi
if VAULT_TOKEN=invalid-local-test-token vault token lookup >/dev/null 2>&1; then
  echo "Invalid-token check failed." >&2
  exit 1
fi
token_json="$(vault token create -policy=github-ci-probe -ttl=2s -format=json)"
test_token="$(jq -r '.auth.client_token' <<<"$token_json")"
unset token_json
sleep 3
if VAULT_TOKEN="$test_token" vault token lookup >/dev/null 2>&1; then
  echo "Expired-token check failed." >&2
  exit 1
fi
unset test_token

vault operator seal >/dev/null
set +e
sealed_json="$(vault status -format=json 2>/dev/null)"
set -e
[[ "$(jq -r '.sealed' <<<"$sealed_json")" == true ]]
unset sealed_json
if vault kv get kv/ci/probe >/dev/null 2>&1; then
  echo "Sealed-state check failed: read succeeded while sealed." >&2
  exit 1
fi
echo "PASS: TLS listener, allowed/denied paths, policy change, invalid/expired token, sealed-state denial."
