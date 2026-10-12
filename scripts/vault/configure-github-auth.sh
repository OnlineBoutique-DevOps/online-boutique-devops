#!/usr/bin/env bash
set -Eeuo pipefail
set +x

: "${VAULT_ADDR:?Set the HTTPS Vault address}"
: "${VAULT_CACERT:?Set path to the trusted CA certificate}"
: "${VAULT_TOKEN:?Set a short-lived operator token without placing it in shell history}"
for tool in vault jq; do
  command -v "$tool" >/dev/null || { echo "$tool is required." >&2; exit 2; }
done
export VAULT_CACERT

repo="OnlineBoutique-DevOps/online-boutique-devops"
audience="https://github.com/OnlineBoutique-DevOps"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

if ! vault secrets list -format=json | jq -e 'has("kv/")' >/dev/null; then
  vault secrets enable -path=kv -version=2 kv
fi
vault policy write reviewservice-read "${repo_root}/vault/policies/reviewservice-read.hcl"
vault policy write github-ci-probe "${repo_root}/vault/policies/github-ci-probe.hcl"

if ! vault auth list -format=json | jq -e 'has("jwt/")' >/dev/null; then
  vault auth enable -path=jwt jwt
fi
vault write auth/jwt/config \
  oidc_discovery_url="https://token.actions.githubusercontent.com" \
  bound_issuer="https://token.actions.githubusercontent.com"

jq -n --arg audience "$audience" --arg repo "$repo" \
  --arg workflow "${repo}/.github/workflows/vault-smoke.yml@refs/heads/main" \
  '{role_type:"jwt",bound_audiences:[$audience],user_claim:"repository",bound_claims:{repository:$repo,ref:"refs/heads/main",workflow_ref:$workflow},token_policies:["github-ci-probe"],token_ttl:"5m",token_max_ttl:"5m",token_type:"service"}' \
  | vault write auth/jwt/role/github-ci-probe -

echo "GitHub JWT auth and read-only probe policy configured."
echo "The optional smoke workflow requires a reachable Vault endpoint and a connected runner."
echo "A harmless probe can be initialized separately with: vault kv put kv/ci/probe status=ready"
