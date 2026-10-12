#!/usr/bin/env bash
set -Eeuo pipefail
set +x

: "${VAULT_ADDR:?Set the HTTPS Vault address}"
: "${VAULT_CACERT:?Set path to the trusted CA certificate}"
: "${VAULT_TOKEN:?Set a short-lived Vault operator token}"
: "${EKS_OIDC_ISSUER:?Set the issuer URL from the existing EKS cluster description}"
for tool in vault jq; do
  command -v "$tool" >/dev/null || { echo "$tool is required." >&2; exit 2; }
done
export VAULT_CACERT
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

if ! vault auth list -format=json | jq -e 'has("jwt-eks/")' >/dev/null; then
  vault auth enable -path=jwt-eks jwt
fi
vault write auth/jwt-eks/config \
  oidc_discovery_url="$EKS_OIDC_ISSUER" \
  bound_issuer="$EKS_OIDC_ISSUER"
vault policy write reviewservice-vso "${repo_root}/vault/policies/reviewservice-vso.hcl"

jq -n \
  '{role_type:"jwt",bound_audiences:["vault"],user_claim:"sub",bound_claims:{sub:"system:serviceaccount:default:reviewservice-vault-reader"},token_policies:["reviewservice-vso"],token_ttl:"5m",token_max_ttl:"5m",token_type:"service"}' \
  | vault write auth/jwt-eks/role/reviewservice-vso -

echo "VSO JWT role configured for one service account and one KV path."
