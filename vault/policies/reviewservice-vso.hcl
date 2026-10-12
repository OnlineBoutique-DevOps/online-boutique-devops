# VSO may synchronize only the ReviewService application's KV v2 document.
path "kv/data/reviewservice" {
  capabilities = ["read"]
}
