# Vault Secrets Operator para ReviewService

Estos manifiestos conectan el VSO (instalado por separado en una fase autorizada) al Vault externo y sincronizan `kv/reviewservice` a `default/reviewservice-secrets`. El Deployment y PostgreSQL siguen usando las mismas claves `DB_PASSWORD` y `ADMIN_SECRET_KEY`; solo cambia quién crea/actualiza el Secret.

## Preparación controlada

1. Revisa versiones con `helm search repo hashicorp/vault-secrets-operator --versions`; el comando de validación debe fijar una versión concreta. La guía oficial consultada muestra chart `1.6.0`; verifica que siga disponible y compatible antes de usarla. Ejecuta primero `helm upgrade --install --dry-run --debug --version 1.6.0 --namespace vault-secrets-operator --create-namespace vault-secrets-operator hashicorp/vault-secrets-operator`. Solo después de revisar RBAC, CRDs, recursos Auto Mode y costo, una autorización aparte permitiría el mismo comando sin `--dry-run`. No se ha ejecutado.
2. Sustituye en `10-vault-connection.yaml` el nombre reservado `.example.invalid` por el FQDN real cubierto por el certificado TLS. No actives `skipTLSVerify`.
3. Crea el Secret `vault-ca` en `default` desde el certificado CA público de confianza (`ca.crt`); la clave privada TLS no se copia a Kubernetes.
4. Configura el issuer OIDC del EKS en Vault mediante `scripts/vault/configure-vso-auth.sh`; usa el ServiceAccount y audience definidos aquí.
5. Haz el handoff en etapas: mantén `VAULT_SECRETS_ENABLED=false`, pon `VAULT_PRESERVE_SECRET_ON_REMOVAL=true` y ejecuta un upgrade para registrar `helm.sh/resource-policy: keep` en el Secret Helm. Aplica el `VaultStaticSecret` con `overwrite: true`, espera `Ready=True` y verifica las claves sin imprimir sus valores. Solo entonces cambia a `VAULT_SECRETS_ENABLED=true` y `VAULT_PRESERVE_SECRET_ON_REMOVAL=false`. Helm omitirá el Secret y preservará el objeto marcado por la revisión previa; VSO queda como único escritor. La anotación deja el objeto fuera de la gestión de Helm. Si Vault está sellado o inaccesible antes de sincronizar, detén la migración; después de una sincronización correcta, VSO reintenta y conserva la última copia de Kubernetes, que puede quedar obsoleta. Pausa CD, recupera Vault/TLS/JWT/política y no uses `helm rollback` ni borres el `VaultStaticSecret` sin un procedimiento probado para devolver la propiedad a Helm.

El acceso de lectura de Vault queda limitado por JWT al ServiceAccount `default/reviewservice-vault-reader`, audience `vault` y una sola ruta KV. Vault debe poder salir por HTTPS al issuer/JWKS público de EKS; EKS y Vault deben tener ruta privada mutua al TCP/8200. Estas rutas requieren comprobación en Learner Lab. El Secret sincronizado se materializa en etcd; restringe RBAC y habilita cifrado de Secrets en reposo si la plataforma lo permite.

No se incluyen valores de secretos ni el certificado CA. No ejecutar `kubectl apply` hasta confirmar endpoint, CA, CRDs, permisos, sincronización previa y ventana de cambio.
