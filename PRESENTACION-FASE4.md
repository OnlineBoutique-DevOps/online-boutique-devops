# Presentación Fase IV — Online Boutique en AWS con DevSecOps

> Guion listo para pasar a diapositivas (una sección = una lámina). Tiempo objetivo: **12–15 min de exposición + 5 min de demo en vivo + preguntas**. Cada lámina trae: qué mostrar, qué decir (en lenguaje claro) y la captura o comando que la respalda.

---

## Lámina 1 — Portada

**Online Boutique en AWS: del código a producción con DevSecOps**
Proyecto Integrador DevOps — Fase IV: Resultados
[Nombre] · [Materia] · [Fecha]
Repositorio: `github.com/OnlineBoutique-DevOps/online-boutique-devops` · rama `feature/fase3-vault-ansible`

---

## Lámina 2 — El problema y el objetivo

**Qué decir:**
> "Tomamos Online Boutique —una tienda de 11 microservicios de Google— y la llevamos a AWS con una regla: **nada se hace a mano**. Red, clúster, servidor de secretos, pipeline, monitoreo… todo sale del repositorio. Hoy muestro los resultados y tres pruebas de que el sistema se comporta como se espera."

**Tres preguntas que la fase responde:**
1. ¿Qué pasa si alguien cambia algo a mano en la consola? → **Reto 1: Drift**
2. ¿Dónde viven las contraseñas y quién puede leerlas? → **Reto 2: Vault**
3. ¿Podemos ver qué hace el sistema sin entrar a cada servidor? → **Reto 3: CloudWatch**

---

## Lámina 3 — Arquitectura (diagrama)

```
 Desarrollador ──push──▶ GitHub ──Actions──▶ Docker build ──▶ Amazon ECR (13 repos)
                            │                                       │
                            │ OIDC/JWT (sin tokens guardados)       │ Helm deploy
                            ▼                                       ▼
                      HashiCorp Vault ◀──JWT (VSO)──  Amazon EKS Auto Mode (14 pods)
                      EC2 + EBS cifrado                 │  frontend · cart · checkout · reviews · postgres…
                      Elastic IP · TLS propio           │
                            ▲                           └──Fluent Bit──▶ CloudWatch Logs
                            │                                              (1 stream por microservicio)
                      Terraform + Ansible ─────────── Terraform (EKS, ECR, Log Groups, S3 state)
```

**Qué decir:** "Dos planos: el de **infraestructura** (Terraform + Ansible) y el de **aplicación** (GitHub Actions → ECR → Helm → EKS). Vault cruza los dos: le da secretos al pipeline y a los pods sin que nadie copie una contraseña."

---

## Lámina 4 — Herramientas y para qué usamos cada una

| Capa | Herramienta | Uso concreto en el proyecto |
|---|---|---|
| IaC | **Terraform** | VPC/EKS/ECR/Log Groups (`terraform/`) y EC2/EBS/SG/EIP de Vault (`terraform/vault/`); estado en **S3 + DynamoDB** |
| Configuración | **Ansible** | Rol `vault_server`: instala Vault, monta EBS, TLS, systemd — idempotente (`changed=0` en 2ª corrida) |
| Secretos | **Vault** + **VSO** | KV v2, políticas de mínimo privilegio, JWT para GitHub y para pods; VSO sincroniza a un Secret de Kubernetes |
| Orquestación | **EKS Auto Mode** + **Helm** + **kubectl** | 14 microservicios en un chart; nodos los crea AWS según carga |
| Registro | **ECR** | 13 repositorios, escaneo al push |
| CI/CD | **GitHub Actions** | `ci.yml` construye y publica; `deploy.yml` despliega con Helm; `vault-smoke.yml` prueba OIDC |
| Identidad | **OIDC / JWT** | GitHub y los pods *demuestran quiénes son* y reciben tokens de 5 min |
| Transporte | **TLS** con CA propia | Vault solo habla HTTPS; VSO y CI validan la CA (`skipTLSVerify: false`) |
| Observabilidad | **CloudWatch** + **Fluent Bit** | Log Groups desde Terraform; DaemonSet envía logs de todos los pods |
| Seguridad de red | **Security Groups** | Vault: 8200 solo desde EKS y el admin; 22 solo admin; nada abierto al mundo |

---

## Lámina 5 — Cómo funciona el pipeline (de un `git push` a la tienda)

1. `git push` → **CI** construye 13 imágenes en paralelo y las sube a ECR con el SHA del commit como tag (6 min).
2. **CD** (`deploy.yml`) toma esa imagen, corre `helm upgrade --install --atomic` y luego aplica la observabilidad.
3. **VSO** entrega a `reviewservice` y `postgres` su contraseña desde Vault; Helm **no** crea ese Secret (`vaultSecrets.enabled=true`).
4. La tienda responde en un NodePort del clúster.

**Qué decir:** "No hay paso manual. Si hoy borramos todo, el repositorio lo vuelve a levantar — y de hecho lo hicimos (lámina 12)."

---

## Lámina 6 — RETO 1: Drift de Terraform

**Qué es:** Terraform guarda en el *state* lo que cree que existe. Si alguien toca la consola, realidad y código divergen = *drift*.

**Qué hicimos:**
1. `terraform plan -detailed-exitcode` → **exit 0** (todo coincide)
2. En la consola borramos la regla **SSH/22** del Security Group de Vault → *Captura 1*
3. `terraform plan` → **exit 2**, propone recrear la regla → *Captura 2*
4. `terraform apply` → la regla vuelve; la consola la muestra otra vez → *Captura 3*

**Evidencia en pantalla (del log real):**
```
~ resource "aws_security_group" "vault" {
    ~ ingress = [
        + { from_port = 22, to_port = 22, protocol = "tcp",
            cidr_blocks = ["189.219.190.32/32"],
            description = "Optional Ansible SSH access from the approved administrator CIDR" }
Plan: 0 to add, 1 to change, 0 to destroy.
```

**Frase clave:** "El código es la fuente de verdad. La consola se desvió y Terraform lo detectó antes de que nadie aplicara nada por accidente."

---

## Lámina 7 — RETO 2: Vault — aprovisionamiento y red

| Elemento | Cómo está |
|---|---|
| Servidor | EC2 `t3.small` dedicado, **fuera** de EKS, creado por Terraform |
| Datos | EBS 20 GiB **cifrado**; Raft integrado. La instancia es desechable, el disco no |
| IP | **Elastic IP** `3.229.76.82` → `ec2-3-229-76-82.compute-1.amazonaws.com` (estable entre apagados) |
| Puerto 8200 | Solo desde el SG del clúster EKS y desde la IP del administrador `/32` |
| Puerto 22 | Solo la IP del administrador `/32` |
| Apertura | 5 llaves Shamir, se necesitan **3** para abrir; las 5 + el root token viven cifrados con GPG fuera del repo |

*Capturas 4 y 5*: panel EC2 con la instancia e IP; Inbound rules del SG.

**Analogía para la clase:** "Vault es la recepción del hotel: nadie entra a un cuarto sin pasar por ahí y demostrar quién es."

---

## Lámina 8 — RETO 2: UI web y menor privilegio para el pipeline

**UI:** `https://ec2-3-229-76-82.compute-1.amazonaws.com:8200/ui` → *Captura 6*. El navegador avisa del certificado **porque la CA es nuestra** — es control, no debilidad. Login con token `ui-demo` de solo lectura → *Captura 7*.

**Pipeline sin contraseñas guardadas:**
```hcl
path "kv/data/ci/probe" { capabilities = ["read"] }      # única ruta que CI puede leer
```
- GitHub presenta su **JWT OIDC** → Vault valida *issuer*, repo, rama y workflow → emite token de **5 min**.
- `gh secret list` → **no existe `VAULT_TOKEN`**. Solo hay credenciales temporales de AWS Academy.
- Prueba negativa: otro workflow fue rechazado con `claim "workflow_ref" does not match`.

*Captura 8*: run verde de `vault-smoke.yml` + `gh secret list`. *Captura 9*: `vault read auth/jwt/role/github-ci-probe` con `bound_claims` y `token_ttl=5m`.

**Frase clave:** "No hay llaves pegadas en la puerta: cada robot gana una tarjeta que caduca en minutos y solo abre su cuarto."

---

## Lámina 9 — RETO 3: Observabilidad con CloudWatch

```
pods (default) → /var/log/containers → Fluent Bit (DaemonSet, 1 por nodo) → CloudWatch
                                                                           /online-boutique/application
                                                                             streams: frontend · reviewservice · cartservice · …
EKS control plane (api, audit, scheduler…) ─────────────────────────────▶ /aws/eks/online-boutique-cluster/cluster
```

**Decisiones:**
- Los Log Groups los crea **Terraform** (retención 7 días); Fluent Bit tiene `auto_create_group false` → si alguien borra el grupo, es drift detectable (enlaza con Reto 1).
- Un **stream por microservicio** (`log_stream_template $kubernetes['labels']['app']`).
- AWS Academy no permite crear roles IAM → sin IRSA. Se intentó el rol del nodo (hostNetwork + IMDS) → `AccessDenied`; se usa un Secret **opcional** con credenciales temporales del lab que `vault-wake.sh` renueva. Nunca en el repo.

*Capturas 10–13*: Log groups con retención 7d · 12 streams · Live tail con 4,533 eventos · terminal con `kubectl get pods -n amazon-cloudwatch` + `aws logs tail`.

**Frase clave:** "Podemos ver logins fallidos y reseñas rechazadas de todos los servicios desde un solo lugar, sin entrar a ningún pod."

---

## Lámina 10 — La aplicación: lo que agregamos al negocio

| Función | Cómo | Regla de seguridad |
|---|---|---|
| Registro / login (email + contraseña) | `reviewservice` Node + PostgreSQL, hash **scrypt** con salt | Contraseña nunca en claro; sesión en cookie `HttpOnly` |
| Compra con cuenta | Checkout exige sesión; registra qué productos compró el usuario | El usuario lo decide el servidor, no el formulario |
| Comentarios y 1–5 ★ | Formulario en la página del producto | **Solo quien compró puede reseñar** — se verifica en la base de datos; sin compra → `403` |
| Persistencia | PVC 1 GiB en EBS (StorageClass `gp3` en el chart) | Datos sobreviven a pausar/reanudar |

**Demo en vivo (5 min):** registrarse → intentar reseñar (rechazo) → comprar → reseñar (★★★★★) → mostrar el evento en CloudWatch.

---

## Lámina 11 — Explicación del código (lo que el profe puede preguntar)

| Archivo | Qué hace y por qué así |
|---|---|
| `terraform/main.tf` | EKS **Auto Mode** (AWS gestiona nodos); roles IAM vienen del lab como variables porque `voclabs` no puede crearlos |
| `terraform/cloudwatch.tf` | Log groups con retención; `depends_on` para que existan antes que el clúster |
| `terraform/vault/main.tf` | SG con reglas *inline* (cualquier cambio es drift), EBS con `prevent_destroy`, **EIP** |
| `ansible/roles/vault_server/` | Tareas idempotentes: paquete fijo 1.21.4, TLS, `vault.hcl` desde template, handler de reinicio |
| `vault/policies/*.hcl` | Una ruta por consumidor: `github-ci-probe`, `reviewservice-vso`, `reviewservice-read` |
| `kubernetes/vault-secrets-operator/` | `VaultConnection` (CA, sin skip-verify) → `VaultAuth` (JWT, SA, audience) → `VaultStaticSecret` |
| `kubernetes/cloudwatch/` | DaemonSet con `hostNetwork`, filtro `kubernetes`, output `cloudwatch_logs` |
| `helm-chart/templates/secret.yaml` | `{{ if not .Values.vaultSecrets.enabled }}` → handoff Helm → VSO por etapas |
| `.github/workflows/ci.yml` | Matriz de 13 servicios, tag = SHA, publica solo en push del repo propio |
| `src/reviewservice/app.js` | `hasPurchased()` antes de `INSERT INTO reviews`; `CHECK (rating BETWEEN 1 AND 5)` |

---

## Lámina 12 — Prueba de fuego de reproducibilidad

> "El 8 de noviembre la cuenta de AWS Academy agotó sus créditos. **Reconstruimos todo en una cuenta nueva solo con el repositorio, en ~2 horas.**"

| Paso | Herramienta | Tiempo |
|---|---|---|
| EKS + ECR + Log Groups (17 recursos) | `terraform apply` | 12 min |
| 13 imágenes | GitHub Actions | 6 min |
| EC2 + EBS + SG + EIP de Vault | `terraform apply` | 1 min |
| Vault instalado y configurado | Ansible + scripts | 5 min |
| VSO sincronizando | Helm + kubectl | 3 min — `True/True/True` a la primera |
| Tienda con 14 pods + Fluent Bit | Helm | 8 min |

Lo único no recuperable: los **datos** (usuarios/reseñas), que vivían en EBS de la cuenta anterior — por diseño.

**Frase clave:** "Esto es lo que significa infraestructura como código: perder la cuenta fue un inconveniente, no un desastre."

---

## Lámina 13 — Seguridad: dónde está cada llave

| Llave | Dónde vive | Qué se enseña |
|---|---|---|
| Root token + 5 shares | Archivo **GPG** fuera del repo (`~/.local/state/…/init-*.json.gpg`, `-rw-------`) | `ls -la` + script que muestra 5 shares enmascaradas |
| Token de GitHub Actions | **No existe guardado** — se emite por OIDC en cada run, vive 5 min | `gh secret list` sin `VAULT_TOKEN` |
| Token de los pods | Solo en memoria de VSO, renovado con JWT del ServiceAccount | `kubectl get sa reviewservice-vault-reader` (`automountServiceAccountToken: false`) |
| Secretos de la app | Vault `kv/reviewservice` → Secret K8s (dueño: VSO) | `kubectl get secret` con valores tapados |
| CA y llaves TLS, llave SSH | `~/.config/…/pki/`, `~/.ssh/vault-admin` fuera del repo | `ls` de los directorios |
| Credenciales AWS | GitHub Secrets — únicas estáticas, expiran con la sesión del lab | Settings → Secrets (solo nombres) |

`git grep -iE "hvs\.|PRIVATE KEY" | wc -l` → **0**

---

## Lámina 14 — Costos y operación

- Pausar: deployments a **0** (Auto Mode retira nodos), EC2 de Vault **stopped**.
- Reanudar: `vault-wake.sh` → enciende, unseal 3/5, escala, renueva credenciales de Fluent Bit (~6 min, sin intervención gracias a la EIP).
- Lo que sigue costando apagado: control plane EKS (~$2.40/día) y EBS (~$3/mes). La EIP asociada no cobra.

---

## Lámina 15 — Conclusiones

1. **Todo sale del repositorio**: red, clúster, Vault, pipeline, observabilidad y la app. Se demostró reconstruyendo desde cero.
2. **Cero secretos estáticos de Vault**: identidad (OIDC/JWT) en lugar de contraseñas copiadas; tokens de minutos; una ruta por consumidor.
3. **El drift se ve antes de doler**: Terraform detectó un cambio manual y lo revirtió.
4. **Observabilidad centralizada**: 14 microservicios en un Log Group, un stream por servicio, creado desde código.
5. **Límites honestos**: AWS Academy no permite roles IAM (sin IRSA → credenciales temporales para Fluent Bit); el runner self-hosted se retira tras la demo; la restauración desde snapshot está documentada, no ensayada.

---

## Anexo A — Guion de la demo en vivo (5 min)

```powershell
# 0. Antes de la clase (lab encendido, credenciales nuevas):
wsl -d Ubuntu-22.04 -u palomagmt bash /home/palomagmt/vault-wake.sh      # ~6 min, imprime la URL de la tienda

# 1. Tienda (navegador): URL que imprimió el script → Registrarse → producto → "Compra este producto para calificarlo"
#    → Add to cart → Place order (tarjeta 4432801561520454) → volver al producto → ★★★★★ → Publicar

# 2. CloudWatch (navegador): Log groups → /online-boutique/application → Empezar a seguir → se ven los eventos del paso 1

# 3. Vault UI (navegador): https://ec2-3-229-76-82.compute-1.amazonaws.com:8200/ui
wsl -d Ubuntu-22.04 -u palomagmt bash ~/vault-ui-token.sh                 # copia token ui-demo al portapapeles

# 4. (Si hay tiempo) Drift en vivo:
& "C:\Program Files\Git\bin\bash.exe" scripts/fase4/reto1-drift.sh       # borras la regla 22 en consola, plan la detecta
cd terraform\vault; terraform apply -auto-approve                        # la restaura
```

## Anexo B — Preguntas probables y respuestas cortas

- **¿Por qué Vault fuera de EKS?** Para que la raíz de confianza no dependa del clúster que protege; si EKS cae, Vault sigue; si Vault cae, la app sigue con el último Secret sincronizado.
- **¿Qué pasa si se roban un token de CI?** Vive 5 min y solo lee un canary sin valor.
- **¿Por qué el navegador dice "no seguro" en Vault?** CA propia que el navegador no conoce; VSO y CI sí la validan.
- **¿Por qué no IRSA para Fluent Bit?** Academy prohíbe crear roles IAM y proveedores OIDC; se documenta el fallback y sus límites.
- **¿Qué es Auto Mode?** AWS crea y destruye los nodos; nosotros solo declaramos pods. Es lo que permite "pausar" escalando a 0.
- **¿Cómo sabes que Ansible es idempotente?** Segunda corrida `changed=0`; tercera también.
- **¿Qué harías distinto en producción real?** IRSA/Pod Identity, Vault en HA (3 nodos Raft), auto-unseal con KMS, ALB con TLS público, snapshots de Raft programados.

## Anexo C — Checklist de capturas (índice en `EVIDENCIA-FASE4.md` §7)

| # | Reto | Estado |
|---|---|---|
| 1 | SG sin regla 22 (consola) | ☐ |
| 2 | `terraform plan` con drift | ✅ (terminal del 9-nov) |
| 3 | `apply` + regla restaurada | ☐ |
| 4 | Panel EC2 Vault con EIP | ☐ |
| 5 | Inbound rules del SG | ☐ |
| 6 | UI Vault por DNS, Sealed=false | ☐ |
| 7 | Login UI con token ui-demo | ☐ |
| 8 | `vault-smoke.yml` verde + `gh secret list` | ☐ (requiere `scripts/fase4/prepare-ci-smoke.sh` con lab encendido) |
| 9 | Rol JWT con bound_claims | ☐ |
| 10 | Log groups con retención 7d | ✅ |
| 11 | Streams por microservicio | ✅ (12 flujos) |
| 12 | Live tail con eventos | ✅ (4,533 registros) |
| 13 | `kubectl get pods -n amazon-cloudwatch` + `aws logs tail` | ☐ |

## Anexo D — Estado actual y pasos pendientes (al 10-nov-2026)

### Estado de los 3 retos

| Reto | Técnico | Evidencia |
|---|---|---|
| 1 Drift | ✅ Ejecutado y reconciliado (`exit 0` → regla borrada → `exit 2` → `apply` la restauró) | Captura 2 tomada; faltan **1** (consola sin regla 22) y **3** (regla restaurada por Terraform) |
| 2 Vault | ✅ EC2 + SG + EIP + UI + roles OIDC configurados en la cuenta nueva | Faltan capturas **4–9** |
| 3 CloudWatch | ✅ 2 log groups con retención 7 d, 12 streams, 4,533 eventos en Live tail | Capturas 10, 11 y 12 tomadas; falta **13** (terminal con `kubectl get pods -n amazon-cloudwatch` + `aws logs tail`) |

Todo lo anterior está en el repositorio (rama `feature/fase3-vault-ansible`, commit `82df632c`): código, scripts, logs de evidencia y este documento.

### Lo único que requiere el lab encendido

El **run en verde de `vault-smoke.yml`** en la cuenta nueva (Captura 8). El script `scripts/fase4/prepare-ci-smoke.sh` instala el runner self-hosted en el EC2 de Vault y amplía el rol JWT para aceptar `main` y la rama de trabajo.

### Secuencia completa para la próxima sesión

```powershell
# 1. AWS Academy → Start Lab → AWS Details → copiar las 3 credenciales a ~/.aws/credentials

# 2. Despertar todo (EC2 on, unseal 3/5, apps a 1, credenciales de Fluent Bit renovadas) — ~6 min
wsl -d Ubuntu-22.04 -u palomagmt bash /home/palomagmt/vault-wake.sh

# 3. Preparar y lanzar el smoke test de CI (Captura 8)
wsl -d Ubuntu-22.04 -u palomagmt bash /mnt/c/Users/LaMamalona/Documents/GitHub/online-boutique-google/microservices-demo/scripts/fase4/prepare-ci-smoke.sh
gh workflow run vault-smoke.yml --ref feature/fase3-vault-ansible
gh run watch
gh secret list          # misma captura: no existe VAULT_TOKEN

# 4. Capturas de consola pendientes
#    EC2 > Instancias > online-boutique-vault (IP 3.229.76.82)                      → Captura 4
#    EC2 > Security Groups > online-boutique-vault-sg > Inbound rules               → Captura 5
#    https://ec2-3-229-76-82.compute-1.amazonaws.com:8200/ui (Sealed: false)       → Captura 6
wsl -d Ubuntu-22.04 -u palomagmt bash ~/vault-ui-token.sh    # token ui-demo al portapapeles → login → Captura 7
wsl -d Ubuntu-22.04 -u palomagmt bash ~/vault-acl-demo.sh    # muestra el rol con bound_claims y TTL 5m → Captura 9

# 5. Reto 1 en consola (Capturas 1 y 3)
#    Borrar la regla SSH 22 en la consola → Captura 1
& "C:\Program Files\Git\bin\bash.exe" scripts/fase4/reto1-drift.sh
cd terraform\vault; terraform apply -auto-approve; cd ..\..     # refrescar consola → Captura 3

# 6. Reto 3 terminal (Captura 13)
kubectl get pods -n amazon-cloudwatch -o wide
& "C:\Program Files\Git\bin\bash.exe" scripts/fase4/reto3-cloudwatch.sh

# 7. Al terminar: retirar el runner (repo público) y pausar
#    (el comando exacto lo imprime prepare-ci-smoke.sh al final)
kubectl scale deploy --all --replicas=0 -n default
kubectl scale deploy vault-secrets-operator-controller-manager --replicas=0 -n vault-secrets-operator
aws ec2 stop-instances --instance-ids i-0aaee309d5d0c5fcf
```

### Datos fijos de la cuenta nueva (para no buscarlos)

| Dato | Valor |
|---|---|
| Cuenta AWS Academy | `532727285947` · `us-east-1` |
| Clúster EKS | `online-boutique-cluster` |
| EC2 Vault | `i-0aaee309d5d0c5fcf` · EIP `3.229.76.82` · privada `172.31.31.7` |
| SG Vault | `sg-0de7e2476e4dd4d17` |
| SG clúster EKS | `sg-0abec498002fb777e` (NodePort `32655` abierto) |
| Log groups | `/online-boutique/application` · `/aws/eks/online-boutique-cluster/cluster` |
| Backend Terraform | S3 `online-boutique-tfstate-532727285947` + DynamoDB `online-boutique-tflocks` |
| Init de Vault (GPG) | `~/.local/state/online-boutique-vault/init-20261109T174743Z.json.gpg` (WSL) |
| Tarjeta de prueba | `4432801561520454` · 01/2030 · CVV 672 |
