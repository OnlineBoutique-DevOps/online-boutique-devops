# FASE IV — Resultados: Retos de consola AWS Academy

**Alumno:** [Tu nombre]
**Materia:** [Nombre de la materia]
**Fecha:** [Fecha de entrega]
**Repositorio:** https://github.com/OnlineBoutique-DevOps/online-boutique-devops
**Rama:** `feature/fase3-vault-ansible`
**Cuenta AWS Academy:** `392730678728` — región `us-east-1`

---

## 0. Resumen ejecutivo

La Fase IV demuestra, sobre la infraestructura ya construida en las fases anteriores, tres comportamientos críticos pedidos por la guía:

| Reto | Qué se demuestra | Estado |
|---|---|---|
| **1. Drift de Terraform** | Un cambio manual en la consola (regla del Security Group de Vault) es detectado por `terraform plan` y puede revertirse desde código | Listo — script `scripts/fase4/reto1-drift.sh` |
| **2. Auditoría de Vault** | EC2 + SG 8200 aprovisionados por Terraform, UI web accesible por DNS/TLS, política de menor privilegio para GitHub Actions validada con OIDC | Completado en Fase III (reutilizado) |
| **3. CloudWatch** | Log Groups creados desde Terraform; Fluent Bit centraliza los logs de los 14 microservicios; tráfico real genera eventos visibles en tiempo real | Listo — `terraform/cloudwatch.tf` + `kubernetes/cloudwatch/` |

Además, en esta fase la aplicación dejó de ser una demo estática: ahora tiene **registro/login de compradores y reseñas verificadas por compra** (ver §5), lo que da sentido funcional a los logs del Reto 3 (intentos de login fallidos, reseñas rechazadas por no haber comprado, etc.).

---

## 1. Reto 1 — Drift y consistencia de estado de Terraform

### 1.1 Qué es el drift y por qué importa

Terraform guarda en el `tfstate` lo que **cree** que existe. Si alguien cambia algo a mano en la consola, la realidad y el estado divergen: eso es *drift*. Es peligroso porque la siguiente persona que haga `apply` puede revertir sin querer un cambio de emergencia, o peor, dejar un agujero de seguridad que el código ya no refleja. Detectarlo con `terraform plan` antes de aplicar es la disciplina básica de IaC.

### 1.2 Qué recurso usamos y por qué

El **Security Group de Vault** (`online-boutique-vault-sg`), declarado en `terraform/vault/main.tf`. Se eligió porque:

- Es el recurso con más valor de seguridad del proyecto: controla quién llega al puerto 8200 y al SSH.
- Sus reglas son fáciles de alterar en la consola (un clic) y el impacto es inmediato y visible.
- Terraform gestiona el SG con reglas *inline*, así que **cualquier** regla añadida, borrada o modificada aparece en el plan.

El estado vive en **S3** (`online-boutique-tfstate-392730678728`) con bloqueo en **DynamoDB**, por lo que el plan se ejecuta contra el mismo estado desde cualquier máquina.

### 1.3 Procedimiento

```bash
# Lab encendido, credenciales frescas en ~/.aws/credentials
bash scripts/fase4/reto1-drift.sh
```

El script: (1) imprime las reglas actuales del SG, (2) espera a que borres la regla SSH (22) en la consola, (3) corre `terraform plan -detailed-exitcode` y guarda el log en `docs/evidencias/fase4/reto1-terraform-plan-<fecha>.log`.

Salida esperada (código de salida **2** = hay cambios):

```
# aws_security_group.vault will be updated in-place
~ resource "aws_security_group" "vault" {
    ~ ingress = [
        + {
            + cidr_blocks = ["189.219.190.32/32"]
            + from_port   = 22
            + to_port     = 22
            + protocol    = "tcp"
            + description = "Optional Ansible SSH access from the approved administrator CIDR"
          },
        # (otras reglas sin cambios)
      ]
  }
Plan: 0 to add, 1 to change, 0 to destroy.
```

Lectura: Terraform detecta que la regla que el código declara **ya no existe** en AWS y propone **volver a crearla**. El código es la fuente de verdad; la consola es la que se desvió.

### 1.4 Entregables

- **Captura 1:** Consola EC2 > Security Groups > `online-boutique-vault-sg` > Inbound rules **sin** la regla 22.
- **Captura 2:** Terminal con el `terraform plan` mostrando `~ update in-place` y `+` en la regla faltante (o el archivo `.log`).
- **Captura 3 (opcional):** `terraform apply` reconciliando y la consola mostrando la regla restaurada.

> Variante con Log Group: borrar `/online-boutique/application` en CloudWatch y correr el plan en `terraform/` (`TF_DIR=terraform bash scripts/fase4/reto1-drift.sh`). El plan mostrará `+ aws_cloudwatch_log_group.application` → **1 to add**.

---

## 2. Reto 2 — Auditoría de accesos y seguridad de secretos (Vault)

Este reto quedó cubierto por la Fase III; aquí se referencian las evidencias y se agregan los puntos que la guía pide explícitamente.

### 2.1 EC2 y Security Group (puerto 8200)

| Elemento | Valor | Dónde está en el código |
|---|---|---|
| Instancia | `t3.small`, Amazon Linux, EBS raíz 8 GiB + datos 20 GiB gp3 **cifrados** | `terraform/vault/main.tf` |
| SG `online-boutique-vault-sg` | 8200 ← SG del clúster EKS + IP del administrador `/32`; 22 ← IP del administrador `/32`; **sin** `0.0.0.0/0` | `terraform/vault/main.tf` (bloques `ingress`) |
| IP pública / DNS | Cambia en cada stop/start; el script `vault-wake.sh` reemite el certificado TLS con el DNS nuevo | `~/vault-wake.sh` (WSL) |

**Por qué no `0.0.0.0/0` en 8200:** Vault es la raíz de confianza. Abrirlo al mundo convierte cada CVE o fuerza bruta en riesgo directo. Solo el clúster (que necesita leer secretos) y el administrador (que necesita la UI) lo alcanzan.

- **Captura 4:** Panel EC2 con la instancia `running`, IP pública y el SG asociado.
- **Captura 5:** Inbound rules del SG mostrando 8200 y 22 restringidos.

### 2.2 UI web de Vault accesible por DNS

```
https://ec2-<ip-publica>.compute-1.amazonaws.com:8200/ui
```

El navegador muestra advertencia de certificado **porque la CA es propia** (creada con OpenSSL, fuera del repo) — no es una debilidad, es control total de la cadena de confianza. VSO y GitHub Actions validan contra esa CA con `skipTLSVerify: false`.

- **Captura 6:** UI de Vault en el navegador con la barra de direcciones visible (DNS público + 8200) y `Sealed: false`.
- **Captura 7:** Pantalla de login con método **Token** y acceso con el token `ui-demo` de solo lectura (nunca el root).

### 2.3 Política de menor privilegio para el pipeline

```hcl
# vault/policies/github-ci-probe.hcl
path "kv/data/ci/probe" { capabilities = ["read"] }
```

GitHub Actions **no guarda ningún token de Vault**. En cada run, `hashicorp/vault-action` presenta el JWT OIDC de GitHub; Vault verifica el issuer, los *bound claims* (`repository`, `workflow_ref`, `ref`) y emite un token de **5 minutos** limitado a esa política.

Validación:
- **Positiva:** workflow `vault-smoke.yml` en verde leyendo `kv/ci/probe`.
- **Negativa:** otro workflow rechazado con `claim "workflow_ref" does not match any associated bound claim values`.
- **ACL:** con el mismo token, `vault kv get kv/reviewservice` → `permission denied` (403).

```bash
gh secret list      # no existe VAULT_TOKEN
gh variable list    # VAULT_ADDR y VAULT_CA_CERT son variables públicas, no secretos
```

- **Captura 8:** Run de `vault-smoke.yml` en verde + `gh secret list` sin token de Vault.
- **Captura 9:** `vault read auth/jwt/role/github-ci-probe` mostrando `bound_claims` y `token_ttl=5m`.

---

## 3. Reto 3 — Monitoreo y observabilidad con Amazon CloudWatch

### 3.1 Diseño

```
 pods (default)  ──stdout──▶ /var/log/containers/*.log  (en cada nodo Auto Mode)
                                      │
                           Fluent Bit (DaemonSet, hostNetwork)
                           filtro kubernetes → añade pod/labels
                                      │  plugin cloudwatch_logs, rol del nodo via IMDS
                                      ▼
            CloudWatch Log Group  /online-boutique/application   ← creado por Terraform
                streams:  frontend · reviewservice · cartservice · checkoutservice · ...

 EKS control plane (api, audit, authenticator, scheduler, controllerManager)
                                      ▼
            CloudWatch Log Group  /aws/eks/online-boutique-cluster/cluster  ← adoptado por Terraform (import)
```

### 3.2 Log Groups desde Terraform

Archivo `terraform/cloudwatch.tf`:

```hcl
resource "aws_cloudwatch_log_group" "application" {
  name              = "/online-boutique/application"
  retention_in_days = var.log_retention_days   # 7
}

resource "aws_cloudwatch_log_group" "eks_control_plane" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.log_retention_days
}

import {   # EKS ya lo había creado; Terraform lo adopta sin recrearlo
  to = aws_cloudwatch_log_group.eks_control_plane
  id = "/aws/eks/${var.name}/cluster"
}
```

**Decisiones y por qué:**

| Decisión | Motivo |
|---|---|
| Terraform crea el grupo, Fluent Bit tiene `auto_create_group false` | Es lo que pide el reto y evita que el agente "repare" en silencio un grupo borrado — así el borrado manual se vuelve drift detectable (enlaza con el Reto 1) |
| Retención de 7 días | El default de CloudWatch es *nunca expirar*; en un lab con créditos finitos eso es costo sin valor |
| Bloque `import` para el grupo de EKS | El grupo existía desde la Fase II (creado por EKS al habilitar `enabled_cluster_log_types`). Importarlo lo pone bajo control sin destruir historial |

### 3.3 Fluent Bit como DaemonSet (`kubernetes/cloudwatch/`)

| Decisión | Motivo |
|---|---|
| **DaemonSet** y no sidecar | Un agente por nodo cubre los 14 servicios sin modificar el Helm chart de la aplicación |
| `hostNetwork: true` | AWS Academy **no permite crear roles IAM** → no hay IRSA ni Pod Identity. Fluent Bit usa el rol del nodo (`LabEksNodeRole`) vía IMDS; Auto Mode fija hop limit 1 en IMDS, que bloquea a pods con red propia, pero con hostNetwork la petición es local al nodo |
| Un **stream por microservicio** (`log_stream_template $kubernetes['labels']['app']`) | En la consola se lee de inmediato qué servicio emitió cada evento |
| Excluye `kube-system`, `amazon-cloudwatch`, `vault-secrets-operator` | Solo logs de la aplicación: menos ruido, menos costo |
| Imagen `aws-for-fluent-bit:2.32.5` fija | Reproducible; es la distribución oficial de AWS con el plugin nativo `cloudwatch_logs` |
| Fallback con Secret `cloudwatch-credentials` **opcional** | Si el rol del nodo no tuviera `logs:PutLogEvents`, se inyectan las credenciales temporales del lab (expiran solas; nunca en el repo) |

### 3.4 Procedimiento

```bash
cd terraform && terraform apply           # crea /online-boutique/application, adopta el de EKS
bash scripts/fase4/reto3-cloudwatch.sh    # despliega Fluent Bit, genera tráfico, hace `aws logs tail`
```

El script genera ~120 solicitudes reales (home, página de producto, `/login`, y `POST /login` con credenciales **inválidas a propósito**) para que aparezcan tanto eventos normales del `frontend` como intentos fallidos de autenticación en el `reviewservice`.

Ejemplo de lo que se ve en el stream `frontend`:

```json
{"http.req.method":"GET","http.req.path":"/product/0PUK6V6EV0","http.resp.status":200,"http.resp.took_ms":14,"message":"request complete","session":"..."}
```

Y en `reviewservice` (login fallido — ver §5):

```
POST /api/login -> 401 credenciales invalidas
```

### 3.5 Entregables

- **Captura 10:** CloudWatch > Log groups mostrando `/online-boutique/application` y `/aws/eks/online-boutique-cluster/cluster` con retención **7 días**.
- **Captura 11:** Dentro de `/online-boutique/application`, la lista de streams (`frontend`, `reviewservice`, `cartservice`, ...).
- **Captura 12:** **Live tail** del grupo mientras corre `reto3-cloudwatch.sh`, con eventos llegando en tiempo real.
- **Captura 13:** Terminal con `kubectl get pods -n amazon-cloudwatch -o wide` (un Fluent Bit por nodo) y la salida de `aws logs tail`.

---

## 4. Cómo se conectan los tres retos

Los tres retos no son ejercicios aislados; cierran el ciclo DevSecOps del proyecto:

1. **Terraform** declara la red, el SG, el EC2 de Vault y los Log Groups → el Reto 1 demuestra que ese código es la fuente de verdad y que cualquier desviación es visible.
2. **Vault** guarda las credenciales que la aplicación necesita y el pipeline las obtiene sin secretos estáticos → el Reto 2 demuestra que el acceso está acotado por red (SG), transporte (TLS) e identidad (OIDC + ACL).
3. **CloudWatch** recibe lo que la aplicación hace con esas credenciales → el Reto 3 demuestra que podemos *ver* el comportamiento del sistema (incluidos logins fallidos y reseñas rechazadas) sin entrar a cada pod.

---

## 5. Funcionalidad nueva de la aplicación (contexto para la demo en vivo)

Para que la demostración tenga un flujo de negocio real y no solo una vitrina, Online Boutique ahora incluye:

| Función | Implementación | Regla de seguridad |
|---|---|---|
| Registro / login con email y contraseña | `reviewservice` (Node + PostgreSQL), hash **scrypt** con salt, sesiones opacas de 24 h | Nunca se guarda la contraseña en claro; el token de sesión viaja en cookie `HttpOnly` |
| Compra con cuenta | `frontend/handlers.go` exige sesión en el checkout y registra los productos comprados | El `user_id` lo determina el servidor a partir de la sesión, nunca el formulario |
| Comentarios y calificación 1–5 ★ | Formulario en `product.html`, API `POST /api/reviews` | **Solo quien compró el producto puede reseñarlo** — la verificación es en base de datos (`purchases`), no solo ocultando el botón: sin compra → `403` |
| Persistencia | PVC de 1 GiB en EBS (StorageClass `gp3`, driver CSI de Auto Mode) para PostgreSQL | Usuarios, compras y reseñas sobreviven al apagar/encender el laboratorio |

Flujo sugerido para la demo:

1. Abrir la tienda → "Entrar / Registrarse" → crear cuenta.
2. Intentar reseñar un producto → mensaje *"compra este producto para poder calificarlo"*.
3. Comprar (tarjeta demo `4432801561520454`) → volver al producto → ahora aparece el formulario ★.
4. Publicar reseña → se ve con nombre, estrellas y promedio.
5. Mostrar en CloudWatch los eventos que ese flujo generó (Reto 3).

---

## 6. Reproducibilidad: encender, demostrar, apagar

```powershell
# Encender (tras Start Lab y copiar credenciales nuevas)
wsl -d Ubuntu-22.04 -u palomagmt bash /home/palomagmt/vault-wake.sh
#   → EC2 on, cert TLS nuevo, Ansible si hace falta, unseal 3/5, VaultConnection al DNS actual, apps a 1

# Retos
bash scripts/fase4/reto1-drift.sh
bash scripts/fase4/reto3-cloudwatch.sh

# Apagar (para no consumir créditos)
kubectl scale deploy --all --replicas=0 -n default
kubectl scale deploy vault-secrets-operator-controller-manager --replicas=0 -n vault-secrets-operator
aws ec2 stop-instances --instance-ids <id-vault>
```

Lo único que sigue cobrando apagado es el plano de control de EKS (~$2.40/día) y los EBS (~$2/mes).

---

## 7. Índice de capturas

| # | Reto | Contenido |
|---|---|---|
| 1 | 1 | Consola: SG sin la regla 22 (cambio manual) |
| 2 | 1 | `terraform plan` detectando el drift |
| 3 | 1 | (Opcional) `terraform apply` reconciliando |
| 4 | 2 | Panel EC2: instancia, IP pública, SG |
| 5 | 2 | Inbound rules del SG (8200 y 22 restringidos) |
| 6 | 2 | UI de Vault por DNS público, `Sealed: false` |
| 7 | 2 | Login en la UI con token de solo lectura |
| 8 | 2 | `vault-smoke.yml` en verde + `gh secret list` sin `VAULT_TOKEN` |
| 9 | 2 | Rol JWT `github-ci-probe` con bound claims y TTL 5m |
| 10 | 3 | CloudWatch > Log groups con retención 7 días |
| 11 | 3 | Streams por microservicio |
| 12 | 3 | Live tail con eventos en tiempo real |
| 13 | 3 | `kubectl get pods -n amazon-cloudwatch` + `aws logs tail` |

Las capturas se guardan en `docs/evidencias/fase4/`.
