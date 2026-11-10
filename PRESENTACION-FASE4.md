# Guion de exposición Fase IV — Online Boutique en AWS con DevSecOps

> **Cómo usar este documento:** cada lámina tiene 4 bloques:
> - **Título y contenido** → lo que va en la diapositiva (copia y pega a PowerPoint/Slides).
> - **📷 Imágenes que debe llevar** → qué poner en cada lámina y de dónde sale.
> - **🧠 Lo que debes aprender/saber para exponerla** → repasa esto antes de presentar; si te lo preguntan, esto es la respuesta.
> - **🗣️ Qué decir** → texto sugerido, máx. ~45 seg por lámina.
>
> Al final: **resumen de la rúbrica** (qué califica exactamente) y **plan de preguntas**.

---

## PREPARACIÓN PREVIA — Lo que debes saber de memoria

La rúbrica califica **dominio del tema**, no la lectura. Estas 12 ideas debes poder decirlas sin notas:

1. **"Todo sale del repositorio."** La infraestructura es código (Terraform + Ansible); el código es la fuente de verdad.
2. **La app son 11 microservicios** que se hablan por gRPC; el frontend es la puerta de entrada.
3. **Terraform** crea VPC/EKS/ECR/EC2/EBS/SG/Log Groups. El **state vive en S3 + DynamoDB** (candado para no aplicar dos veces).
4. **EKS Auto Mode** → AWS crea y destruye los nodos; por eso "pausar" = escalar a 0.
5. **Helm** empaqueta los 14 servicios; el `values.yaml` permite apagar el Secret propio y que **VSO** lo escriba.
6. **GitHub Actions**: `ci.yml` construye 13 imágenes → ECR; `deploy.yml` despliega; `vault-smoke.yml` prueba OIDC.
7. **Vault** está **fuera** de EKS (EC2 + EBS cifrado + EIP). Se abre con **3 de 5 llaves** (Shamir). Guarda `kv/reviewservice` y `kv/ci/probe`.
8. **Autenticación sin secretos guardados**: GitHub y los pods presentan **JWT** (OIDC) y Vault verifica issuer + bound claims → token de **5 min**. No existe `VAULT_TOKEN` en GitHub.
9. **Reto 1 (drift)**: si alguien toca la consola, `terraform plan` lo detecta → el plan propone volver al código.
10. **Reto 2**: SG de Vault solo abre 8200 al clúster y a tu IP, 22 solo a tu IP; UI por DNS con TLS de CA propia.
11. **Reto 3**: Fluent Bit (DaemonSet) envía stdout de los pods a CloudWatch, un stream por microservicio; los log groups los crea Terraform con retención 7 días.
12. **App**: registro/login con scrypt; reseñas 1–5★ y comentarios **solo para quien compró** el producto (verificación en la DB, no solo en la UI).

**Mínimo técnico que no puedes inventar si te lo preguntan:**
- `scrypt` = hash de contraseñas con salt (nunca texto plano).
- JWT/OIDC = credencial firmada que *demuestra identidad*; Vault comprueba la firma y los *claims* (repo, rama, workflow).
- Shamir threshold 3/5 = la bóveda solo se abre con 3 llaves de las 5.
- `-detailed-exitcode` de terraform = 0 sin cambios, 2 hay drift.
- DaemonSet = un agente por nodo; `hostNetwork` = comparte la red del nodo (para IMDS).

---

## DIAPOSITIVA 1 — Portada

**Contenido:**
> **Online Boutique en AWS: del código a producción con DevSecOps**
> Proyecto Integrador DevOps · Fase IV: Resultados
> [Tu nombre] · [Materia] · [Fecha]
> Repositorio · rama de trabajo

**📷 Imágenes:**
- Logo Online Boutique (o captura de la tienda funcionando) como fondo difuminado.
- QR o URL corta del repo en una esquina.
- Nombre/materia/fecha abajo, bien legibles.

**🧠 Saber:**
- Nombre de la materia, nombre del profesor si aplica.
- Decir en voz alta el tema completo: "del código a producción" = el flujo `código → GitHub → Actions → Docker → ECR → EKS → Helm → app`.

**🗣️ Qué decir (30 seg):**
> "Soy [nombre]. Presento el resultado del proyecto integrador: una tienda completa, Online Boutique, corriendo en AWS, construida solo con código y con una capa de seguridad que se demuestra en tres retos de consola."

---

## DIAPOSITIVA 2 — Objetivo y los 3 retos

**Contenido:**
> **La pregunta:** ¿puedes operar una app real sin tocar nada a mano y demostrar que el sistema es seguro y observable?
>
> **Los 3 retos que la guía pide en consola AWS:**
> 1. **Drift de Terraform** — ¿qué pasa si alguien cambia algo a mano?
> 2. **Vault** — ¿dónde viven las contraseñas y quién las lee?
> 3. **CloudWatch** — ¿podemos ver qué hace el sistema desde un solo lugar?

**📷 Imágenes:**
- Tres íconos grandes (⚠️ drift / 🔐 Vault / 📊 CloudWatch) o las **capturas reales** de cada reto en miniatura.
- Arriba: URL de la tienda funcionando en una captura.

**🧠 Saber:**
- Por qué eliges esos 3 retos (son los de mayor impacto: seguridad + control de cambios + observabilidad).
- Link al PDF de la guía si te lo piden.

**🗣️ Qué decir (40 seg):**
> "El objetivo no era 'que funcione', era que funcione **de forma reproducible y auditable**. Los tres retos son las tres preguntas que se hace un equipo DevOps: ¿mi infraestructura sigue siendo la que yo escribí?, ¿quién tiene las llaves?, ¿puedo ver el sistema funcionando?"

---

## DIAPOSITIVA 3 — Arquitectura

**Contenido:** el diagrama de la lámina 3 original (pipeline + EKS + Vault + CloudWatch).

**📷 Imágenes:**
- **El diagrama hecho por ti en draw.io/Excalidraw** (no un diagrama genérico de internet).
- Incluye: GitHub → Actions → ECR → EKS; Vault EC2 con flechas a EKS y a GitHub; Fluent Bit → CloudWatch.
- Opcional: captura real de la tienda y del panel de EKS.

**🧠 Saber:**
- Dirección del flujo: datos **y** secretos.
- "Terraform despliega la infraestructura; GitHub Actions despliega la aplicación; Vault entrega secretos a ambos."
- Los **dos planos**: infraestructura (Terraform/Ansible) vs aplicación (CI/CD/Helm).

**🗣️ Qué decir (60 seg):**
> "Dos planos. El plano de infraestructura: Terraform levanta EKS, ECR, el EC2 de Vault y sus volúmenes. El plano de aplicación: GitHub Actions construye las 13 imágenes, las sube a ECR, y Helm las instala en el clúster. Vault conecta ambos: le da al pipeline un token temporal para leer un canary, y a los pods su contraseña de base de datos — sin que nadie copie nada."

---

## DIAPOSITIVA 4 — Herramientas (mapa de qué usa qué)

**Contenido:** la tabla de la lámina 4 original.

**📷 Imágenes:**
- Logos de las herramientas en una fila (Terraform, Ansible, Vault, Kubernetes, Helm, Docker, ECR, EKS, GitHub Actions, CloudWatch, Fluent Bit) — solo si aporta; si no, la tabla limpia basta.
- Columna derecha vacía de la tabla no hace falta llenar.

**🧠 Saber:**
- **No memorices los 13 ítems**; agrupa: *IaC* (Terraform, Ansible), *Secretos* (Vault, VSO), *Compute* (EKS, EC2, EBS), *Entrega* (GitHub Actions, Docker, ECR, Helm), *Observabilidad* (CloudWatch, Fluent Bit), *Seguridad de red* (Security Groups), *Identidad* (OIDC/JWT).
- Si te preguntan "¿para qué Docker?": es cómo cada microservicio se vuelve imagen portable que corre igual en cualquier lado.
- "Terraform = infraestructura; Ansible = configuración; Helm = paquete de aplicación; Actions = automatización; Vault = secretos."

**🗣️ Qué decir (45 seg):**
> "Cada herramienta resuelve una capa distinta: Terraform declara la infraestructura, Ansible la configura por SSH, Helm empaqueta los servicios de la app, Actions automatiza build y deploy, Vault centraliza secretos, y CloudWatch centraliza los registros."

---

## DIAPOSITIVA 5 — El pipeline en 4 pasos

**Contenido:** los 4 pasos del push a la tienda.

**📷 Imágenes:**
- **Captura real del run de GitHub Actions** (lista de jobs o un job verde).
- **Captura de `kubectl get pods`** con los 14 pods Running.
- **Captura del `helm list`** o el release `onlineboutique`.

**🧠 Saber:**
- `ci.yml` corre una **matriz** de 13 servicios en paralelo (~6 min).
- `deploy.yml` solo corre si el commit es el actual en la rama (hay un paso `prepare` que compara el SHA).
- Tag de imagen = SHA del commit → trazabilidad imagen↔código.
- "No hay paso manual de copiar imágenes ni SSH a servidores."

**🗣️ Qué decir (45 seg):**
> "Un push dispara todo: build paralelo de las 13 imágenes, push a ECR con el SHA del commit, Helm upgrade atómico al clúster y despliegue de la observabilidad. Si un paso falla, nada queda a medias."

---

## DIAPOSITIVA 6 — RETO 1: Drift

**Contenido:** definición + qué hicimos + el log del plan.

**📷 Imágenes:**
- **Captura de la consola AWS** con el SG y la regla SSH **eliminada** (Captura 1).
- **Captura de la terminal** con `Plan: 0 to add, 1 to change, 0 to destroy` y el bloque `+ from_port = 22` (Captura 2) — la que ya tienes.
- Si hay espacio: captura tras el `apply` mostrando la regla restaurada (Captura 3).

**🧠 Saber:**
- **Drift = diferencia entre el código (tfstate) y la realidad (consola).**
- Por qué usamos el SG de Vault: es el recurso de mayor valor de seguridad y fácil de tocar.
- `-detailed-exitcode`: 0 = sin cambios, 1 = error, 2 = hay drift.
- Terraform **no detecta** cambios que no están en su state — por eso el SG completo debe ser recurso Terraform, no regla suelta.
- "Antes del cambio `plan` daba exit 0; después exit 2."

**🗣️ Qué decir (60 seg):**
> "Borré la regla de SSH a mano en la consola. Terraform no se enteró hasta que corrí plan — y me dijo: 'este Security Group debería tener una regla que ya no existe, la voy a volver a crear'. Eso es drift: la consola y el código se separaron y el código gana."

---

## DIAPOSITIVA 7 — RETO 2a: aprovisionamiento de Vault

**Contenido:** la tabla de la lámina 7 original.

**📷 Imágenes:**
- **Captura del panel EC2** con `online-boutique-vault`, estado `running`, **EIP `3.229.76.82`** visible (Captura 4).
- **Captura de Inbound rules** del SG `online-boutique-vault-sg`: 8200 desde SG del clúster + tu IP, 22 solo tu IP (Captura 5).
- Opcional: captura de los volúmenes (root 8 GiB + datos 20 GiB cifrados).

**🧠 Saber:**
- Por qué **fuera de EKS**: la raíz de confianza no debe depender del clúster que protege; si EKS cae, Vault sigue sirviendo a VSO.
- Por qué **EBS separado**: la instancia es desechable (la recreamos varias veces); el disco persiste → mismo `Cluster ID`.
- Por qué **Elastic IP**: stop/start cambia la IP pública → obligaba a reemitir el cert TLS y tocar 6 scripts; con EIP el endpoint es estable.
- Por qué **SG**: 8200 solo al clúster y a ti; 22 solo a ti; cero `0.0.0.0/0` entrante.

**🗣️ Qué decir (60 seg):**
> "Vault corre en su propia máquina: un EBS cifrado de 20 GB guarda el estado, una IP elástica fija el DNS, y el firewall solo deja entrar al puerto 8200 desde el clúster o desde mi IP. Nadie en internet puede ni adivinar que existe."

---

## DIAPOSITIVA 8 — RETO 2b: UI y menor privilegio

**Contenido:** UI + política + prueba negativa.

**📷 Imágenes:**
- **Captura de la UI de Vault** en el navegador con la URL `https://ec2-3-229-76-82.compute-1.amazonaws.com:8200/ui` visible y `Sealed: false` (Captura 6).
- **Captura del login** con token `ui-demo` (Captura 7).
- **Captura del run de `vault-smoke.yml`** en verde + `gh secret list` sin `VAULT_TOKEN` (Captura 8).
- **Captura de `vault read auth/jwt/role/github-ci-probe`** mostrando `bound_claims` y `token_ttl=5m` (Captura 9).

**🧠 Saber:**
- **Shamir 5/3**: 5 shares generadas, 3 necesarias para abrir — ninguna sola llave abre nada.
- **Token de 5 min**: se emite por OIDC, expira solo; si lo roban no sirve.
- **Bound claims**: Vault solo acepta tokens de *este repo*, *esta rama* (`main` y `feature/**`) y *este workflow*.
- **Por qué el warning del navegador**: la CA es nuestra (OpenSSL, fuera del repo); VSO y CI la validan — no es debilidad, es control.
- "Antes había `VAULT_TOKEN` en GitHub Secrets; ahora hay **cero**."

**🗣️ Qué decir (60 seg):**
> "En GitHub no hay ningún token de Vault. Cada ejecución del pipeline se presenta con su credencial OIDC — GitHub la firma — y Vault la verifica contra el repo, la rama y el workflow exactos. Emite un token de cinco minutos que solo puede leer un canary sin valor. Probamos que otro workflow es rechazado."

---

## DIAPOSITIVA 9 — RETO 3: Observabilidad

**Contenido:** el diagrama de la lámina 9 original + tabla de decisiones.

**📷 Imágenes:**
- **Captura de CloudWatch > Log groups** con los dos grupos y retención **1 semana** (Captura 10).
- **Captura de los streams** dentro de `/online-boutique/application` (Captura 11).
- **Captura de Live tail** con miles de eventos (Captura 12 — la que ya tienes, 4,533).
- **Captura de terminal** `kubectl get pods -n amazon-cloudwatch -o wide` (Captura 13).

**🧠 Saber:**
- **Fluent Bit** = agente que lee `/var/log/containers` de cada nodo y lo manda a CloudWatch; el filtro `kubernetes` añade nombre de pod y labels.
- **DaemonSet** = corre en todos los nodos automáticamente (Auto Mode crea nodos → Fluent Bit aparece solo).
- **`hostNetwork: true`**: AWS Academy no permite crear roles IAM → sin IRSA/Pod Identity; Fluent Bit usa credenciales temporales del lab en un Secret opcional que `vault-wake.sh` renueva.
- **Por qué Terraform crea el log group**: si alguien lo borra en consola, `terraform plan` lo detecta (enlaza con Reto 1); `auto_create_group false` en Fluent Bit.
- **Retención 7 días**: el default es "nunca expira" → costo; en lab con créditos, 7 días es suficiente.
- "Un stream por microservicio" = ves `frontend`, `cartservice`, `reviewservice`… por separado.

**🗣️ Qué decir (60 seg):**
> "Los 14 microservicios escriben logs a disco en cada nodo. Un agente por nodo los recoge y los centraliza en CloudWatch, separados por servicio. Los log groups no los crea el agente sino Terraform — así si alguien los borra, lo vemos como drift. Y en la demo en vivo se ven los logins fallidos y las reseñas rechazadas en tiempo real."

---

## DIAPOSITIVA 10 — La aplicación: negocio real

**Contenido:** la tabla de la lámina 10 original.

**📷 Imágenes:**
- **Captura del header** con "Entrar / Registrarse".
- **Captura de la página de login/registro**.
- **Captura del formulario de reseña** con el selector ★.
- **Captura de una reseña publicada** (nombre + ★★★★★ + comentario + promedio).
- **Captura del mensaje "solo puedes calificar productos que compraste"**.

**🧠 Saber:**
- **scrypt**: hash de contraseña con salt aleatorio — no es reversible; se verifica con `timingSafeEqual`.
- **Sesiones**: token opaco de 24 h en Postgres + cookie `HttpOnly` (el navegador no la lee por JS → anti-XSS).
- **La regla de negocio**: `purchases` (user_id, product_id, order_id) se llena **en el servidor** al completar el checkout; `POST /api/reviews` hace `SELECT` en esa tabla antes de insertar → 403 si no compró. **No es solo ocultar el botón** — es autorización de servidor.
- **PVC gp3**: los datos sobreviven a pausar/reanudar; antes la DB era efímera y se perdía todo.
- "El usuario no puede inventarse una compra: el `user_id` lo pone el servidor desde la sesión."

**🗣️ Qué decir (60 seg):**
> "La tienda ahora tiene cuentas reales. La contraseña se guarda con scrypt — nunca en claro. Para comprar hay que estar logueado, y el servidor registra qué compraste. Para reseñar, el servidor verifica en la base de datos que compraste ese producto; si no, responde 403 aunque manipules el formulario. Y los datos están en un volumen persistente: apagar y prender no los pierde."

---

## DIAPOSITIVA 11 — Explicación del código (mapa rápido)

**Contenido:** tabla archivo → qué hace.

**📷 Imágenes:**
- Mini-capturas de los archivos en el editor/IDE: `terraform/cloudwatch.tf`, `vault/policies/github-ci-probe.hcl`, `src/reviewservice/app.js` (la función `hasPurchased`), `kubernetes/cloudwatch/20-fluent-bit-daemonset.yaml`.
- Una captura del árbol del repo.

**🧠 Saber (repasa antes de presentar):**
- `terraform/main.tf`: EKS Auto Mode + `depends_on` al log group.
- `terraform/vault/main.tf`: SG inline, EBS `prevent_destroy`, `aws_eip`.
- `ansible/roles/vault_server/`: tareas idempotentes + handler de restart.
- `vault/policies/*.hcl`: una ruta por consumidor — *menor privilegio*.
- `kubernetes/vault-secrets-operator/`: Connection → Auth → StaticSecret (orden importa).
- `helm-chart/templates/secret.yaml`: `{{ if not .Values.vaultSecrets.enabled }}` → handoff por etapas.
- `src/reviewservice/app.js`: `hasPurchased()` antes de `INSERT`; `CHECK (rating BETWEEN 1 AND 5)`; `UNIQUE(user_id,product_id)` para upsert.
- `.github/workflows/ci.yml`: matriz 13 servicios, `IMAGE_TAG=$GITHUB_SHA`.

**🗣️ Qué decir (45 seg):**
> "Puedo explicar cada archivo si me lo preguntan: Terraform declara, Ansible configura, las políticas de Vault acotan a una ruta por consumidor, el operador traduce Vault a Secrets de Kubernetes, y el frontend solo es un puente HTTP — la autorización real vive en el reviewservice contra la base de datos."

---

## DIAPOSITIVA 12 — Prueba de fuego: cambio de cuenta

**Contenido:** la tabla de reproducibilidad + frase final.

**📷 Imágenes:**
- **Captura del `terraform apply`** del clúster nuevo (o del `vault apply` con los 4 recursos).
- **Captura de `kubectl get pods`** con los 14 Running en la cuenta nueva.
- **Captura de VSO `True/True/True`** (si la tienes) o del `vault-staticsecret`.

**🧠 Saber:**
- La cuenta vieja `392730678728` **agotó créditos**; la nueva `532727285947` se levantó **solo con el repositorio**.
- Tiempos reales: EKS 12 min, imágenes 6 min, Vault EC2+EBS+SG+EIP 1 min, Vault configurado 5 min, VSO `True/True/True` a la primera, app+Fluent Bit 8 min.
- Lo único que **no** se recupera: los datos (vivían en EBS de la otra cuenta) — por diseño.
- Dos bugs que la migración destapó y quedaron corregidos: IP pública cambiante → **EIP**; StorageClass inexistente en Auto Mode → **`gp3` dentro del chart**.

**🗣️ Qué decir (60 seg):**
> "La cuenta de AWS Academy se quedó sin créditos. En vez de rehacer a mano, corrí el repositorio en la cuenta nueva: Terraform levantó el clúster y Vault, Ansible lo configuró, el pipeline construyó las imágenes y la tienda volvió en dos horas. Eso es lo que significa infraestructura como código — perder la cuenta fue un inconveniente, no un desastre."

---

## DIAPOSITIVA 13 — Seguridad: dónde está cada llave

**Contenido:** la tabla de la lámina 13 original.

**📷 Imágenes:**
- **Captura de `ls -la` del `.gpg`** (`-rw-------`, un solo archivo) — la "cajita con candado".
- **Captura de `gh secret list`** mostrando solo nombres de AWS, sin `VAULT_TOKEN`.
- **Captura de `kubectl get secret reviewservice-secrets`** con valores tapados.
- **Captura de `git grep` dando 0** o del `vault-acl-demo.sh` mostrando permitida/denegada.

**🧠 Saber:**
- **Regla de oro**: nada permanente en el repo; todo lo que usa Vault *se fabrica en el momento*.
- Root token + shares → GPG fuera del repo; pods y GitHub → tokens de minutos por JWT; app → VSO con JWT del ServiceAccount.
- Las llaves TLS y SSH viven en `~/.config` y `~/.ssh` de WSL — fuera del repo.
- "Lo único estático en GitHub son las credenciales temporales de AWS Academy, que expiran solas."

**🗣️ Qué decir (45 seg):**
> "No hay tokens estáticos de Vault en ningún lado: el root vive cifrado con GPG fuera del repositorio; GitHub y los pods no tienen token — lo ganan en cada ejecución presentando su identidad OIDC. En el código no hay ninguna llave escrita: cero resultados."

---

## DIAPOSITIVA 14 — Costos y operación

**Contenido:** la lámina 14 original.

**📷 Imágenes:**
- **Captura del `vault-wake.sh`** corriendo o de su salida con las URLs (si la tienes).
- Opcional: captura de `kubectl get deploy -n default` con réplicas en 0 (evidencia de pausa).

**🧠 Saber:**
- Escalar a 0 ≠ destruir: los datos (PVC, EBS de Vault, state de Terraform) persisten.
- `vault-wake.sh` hace todo: EC2 on, unseal 3/5, VaultConnection al DNS actual, apps a 1, credenciales de Fluent Bit.
- Lo que sigue cobrando apagado: control plane EKS (~$2.40/día) y EBS (~$3/mes). La EIP asociada **no cobra**.
- "Pausar no es apagar la cuenta; es poner la carga a cero y conservar el estado."

**🗣️ Qué decir (30 seg):**
> "El laboratorio consume créditos, así que aprendimos a dormirlo y despertarlo: deployments a cero y EC2 detenido; un script lo reactiva en seis minutos sin tocar nada a mano. Los datos —usuarios, reseñas, secretos— están en volúmenes persistentes y sobreviven."

---

## DIAPOSITIVA 15 — Conclusiones

**Contenido:** las 5 conclusiones + frase de cierre.

**📷 Imágenes:**
- **Captura de la tienda funcionando** (la página de producto con reseñas) — la imagen más bonita del proyecto.
- Frase de cierre grande abajo: *"Infraestructura como código + secretos sin contraseñas + todo observable."*

**🧠 Saber:**
- 5 conclusiones ya redactadas (ver contenido).
- Cierre honesto: límites de Academy (sin roles IAM → fallback de credenciales para Fluent Bit; runner self-hosted se retira).
- "En producción real cambiaría: IRSA/Pod Identity, Vault HA, auto-unseal con KMS, ALB con TLS, snapshots programados."

**🗣️ Qué decir (30 seg + cierre):**
> "En resumen: todo sale del repositorio, no hay secretos estáticos de Vault, el drift se detecta antes de doler, y podemos ver el sistema completo desde CloudWatch. La tienda funciona, está segura y es reproducible — y eso es exactamente lo que el DevOps promete. Gracias."

---

## Resumen de la rúbrica de la exposición

La rúbrica tiene **4 criterios de 25%** cada uno:

| Criterio | Qué evalúa | Dónde lo cubres en la presentación |
|---|---|---|
| **1. Formalidad, imagen y lenguaje** | Vestimenta business casual (camisa/blusa, pantalón oscuro), postura firme, contacto visual, vocabulario técnico preciso sin muletillas | Toda la exposición; léete el vocabulario de la sección "PREPARACIÓN" |
| **2. Diseño de diapositivas** | Claridad visual, poco texto, imágenes/capturas reales, no saturadas | Cada lámina indica sus imágenes — usa las capturas reales, no fondos genéricos |
| **3. Demostración** | App funcionando en vivo, integración con la infra | Demo en vivo de 5 min (Anexo A) + capturas de la tienda |
| **4. Dominio del tema** | Explicar con claridad la lógica del código y justificar decisiones | Láminas 11 y 15 + las preguntas del Anexo B |

**Formato exigido:** **12–15 minutos** de presentación + **5 minutos** de preguntas. Entregable: **PDF/PPTX** antes de la fecha.

## Anexo A — Guion de la demo en vivo (5 min)

```powershell
# Antes de la clase (lab encendido, credenciales nuevas):
wsl -d Ubuntu-22.04 -u palomagmt bash /home/palomagmt/vault-wake.sh

# 1. Tienda: Registrarse → producto → intento de reseña (rechazo) → compra → ★★★★★ → publicar
#    tarjeta demo: 4432801561520454 · 01/2030 · CVV 672

# 2. CloudWatch: Log groups → /online-boutique/application → Empezar a seguir → ver los eventos del paso 1

# 3. Vault UI: https://ec2-3-229-76-82.compute-1.amazonaws.com:8200/ui
wsl -d Ubuntu-22.04 -u palomagmt bash ~/vault-ui-token.sh    # token al portapapeles

# 4. (Opcional) Drift en vivo:
& "C:\Program Files\Git\bin\bash.exe" scripts/fase4/reto1-drift.sh
cd terraform\vault; terraform apply -auto-approve; cd ..\..
```

## Anexo B — Preguntas probables y respuestas cortas

- **¿Por qué Vault fuera de EKS?** La raíz de confianza no depende del clúster que protege; si EKS cae, Vault sigue; si Vault cae, la app sigue con el último Secret sincronizado.
- **¿Qué pasa si roban un token de CI?** Vive 5 min y solo lee un canary sin valor — daño acotado por diseño.
- **¿Por qué el navegador dice "no seguro" en Vault?** CA propia que el navegador no conoce; VSO y CI sí la validan — es control, no debilidad.
- **¿Por qué no IRSA para Fluent Bit?** Academy prohíbe crear roles IAM y proveedores OIDC; se documenta el fallback con credenciales temporales.
- **¿Qué es Auto Mode?** AWS crea y destruye los nodos según carga; nosotros solo declaramos pods. Es lo que permite "pausar".
- **¿Cómo sabes que Ansible es idempotente?** Segunda y tercera corrida `changed=0`.
- **¿Qué harías distinto en producción?** IRSA/Pod Identity, Vault HA (3 nodos Raft), auto-unseal con KMS, ALB con TLS público, snapshots de Raft programados, retención de logs mayor.
- **¿Por qué scrypt y no bcrypt?** scrypt es builtin de Node (sin dependencia nativa que compile en Alpine) y resistente a GPU; se eligió por portabilidad del contenedor.
- **¿Cómo evitas que alguien falsee la compra?** El `user_id` lo pone el servidor desde la sesión; el cliente nunca envía user_id; `purchases` se escribe solo desde el handler de checkout tras `PlaceOrder` exitoso.
- **¿Qué pasa si Vault está sellado?** La app sigue con el último Secret sincronizado por VSO; VSO marca `HEALTHY=False` hasta que Vault vuelva — probado en Fase III.

## Anexo C — Checklist de capturas (índice en `EVIDENCIA-FASE4.md` §7)

| # | Reto | Estado |
|---|---|---|
| 1 | SG sin regla 22 (consola) | ☐ |
| 2 | `terraform plan` con drift | ✅ |
| 3 | `apply` + regla restaurada | ☐ |
| 4 | Panel EC2 Vault con EIP | ☐ |
| 5 | Inbound rules del SG | ☐ |
| 6 | UI Vault por DNS, Sealed=false | ☐ |
| 7 | Login UI con token ui-demo | ☐ |
| 8 | `vault-smoke.yml` verde + `gh secret list` | ☐ (requiere lab) |
| 9 | Rol JWT con bound_claims | ☐ |
| 10 | Log groups con retención 7d | ✅ |
| 11 | Streams por microservicio | ✅ |
| 12 | Live tail con eventos | ✅ |
| 13 | `kubectl get pods -n amazon-cloudwatch` + `aws logs tail` | ☐ |

## Anexo D — Estado actual y pasos pendientes (al 10-nov-2026)

| Reto | Técnico | Evidencia |
|---|---|---|
| 1 Drift | ✅ Ejecutado y reconciliado | Capturas 2 ✅; faltan 1 y 3 |
| 2 Vault | ✅ EC2/SG/EIP/UI/OIDC listos | Faltan 4–9 |
| 3 CloudWatch | ✅ 12 streams, 4,533 eventos | Capturas 10–12 ✅; falta 13 |

Lo único que requiere lab encendido: el run verde de `vault-smoke.yml` (Captura 8) con `scripts/fase4/prepare-ci-smoke.sh`, y las capturas de consola pendientes.

### Datos fijos de la cuenta nueva

| Dato | Valor |
|---|---|
| Cuenta AWS Academy | `532727285947` · `us-east-1` |
| Clúster EKS | `online-boutique-cluster` |
| EC2 Vault | `i-0fde5de9d19943f97` · EIP `3.229.76.82` · privada `172.31.25.113` |
| SG Vault | `sg-0de7e2476e4dd4d17` |
| SG clúster EKS | `sg-0abec498002fb777e` (NodePort `32655`) |
| Log groups | `/online-boutique/application` · `/aws/eks/online-boutique-cluster/cluster` |
| Backend Terraform | S3 `online-boutique-tfstate-532727285947` + DynamoDB `online-boutique-tflocks` |
| Init de Vault (GPG) | `~/.local/state/online-boutique-vault/init-20261109T174743Z.json.gpg` (WSL) |
| Tarjeta de prueba | `4432801561520454` · 01/2030 · CVV 672 |
