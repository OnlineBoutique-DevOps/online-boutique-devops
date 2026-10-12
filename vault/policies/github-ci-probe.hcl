# CI smoke-test identity can read only a non-sensitive probe document.
path "kv/data/ci/probe" {
  capabilities = ["read"]
}
