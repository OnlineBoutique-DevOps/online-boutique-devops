# Certificados TLS de Ansible

No guardes certificados ni claves dentro del checkout, aunque estén ignorados por Git. Usa `scripts/vault/create-local-pki.sh` para dejarlos en un directorio privado fuera del repositorio y pasa sus rutas mediante `VAULT_TLS_CERT`, `VAULT_TLS_KEY` y `VAULT_TLS_CA`. La clave de servidor se instala con permisos restringidos y la tarea que la maneja oculta su resultado (`no_log`).
