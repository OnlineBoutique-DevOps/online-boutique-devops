# Evidencia de Entrega — Proyecto DevOps
## Migración de Online Boutique (Google Microservices Demo) a AWS

**Alumno:** [Tu nombre]
**Materia:** [Nombre de la materia]
**Fecha:** 25 de septiembre de 2026
**Repositorio:** https://github.com/OnlineBoutique-DevOps/online-boutique-devops

---

## 1. Objetivo y requisitos

Implementar un pipeline completo de DevOps para desplegar la aplicación de
microservicios **Online Boutique** en Amazon Web Services (AWS), siguiendo el
flujo:

```
Código → GitHub → GitHub Actions → Docker → Amazon ECR → Kubernetes/EKS → Helm → Aplicación funcionando en AWS
```

### Cumplimiento de los requisitos

| # | Requisito | Cumplimiento | Sección |
|---|-----------|--------------|---------|
| 1 | Construir la infraestructura utilizando **Terraform** | Clúster EKS Auto Mode, add-on metrics-server y 13 repositorios ECR gestionados por Terraform con estado remoto en S3/DynamoDB. `terraform plan` → **"No changes. Your infrastructure matches the configuration."** | 4.4 |
| 2 | **CI:** construir imágenes Docker e integrarlas a un container registry en la nube | Workflow `ci.yml` construye 13 imágenes en paralelo y las publica en **Amazon ECR** etiquetadas con el SHA del commit y `latest` | 4.2, 4.3 |
| 3 | **CD:** desplegar con cada cambio en `main` las imágenes del CI en Kubernetes mediante un **Helm Chart personalizado** | Workflow `deploy.yml` se dispara al terminar CI en `main` y ejecuta `helm upgrade --install` del chart `helm-chart/` en EKS con el SHA exacto construido; rollback automático si falla | 4.6, 4.7 |

---

## 2. Arquitectura implementada

```
┌──────────┐    push     ┌────────────┐   build+push   ┌───────────┐
│  Código  │ ──────────► │   GitHub   │ ─────────────► │    ECR    │
│  fuente  │             │  Actions   │   13 imágenes  │ (registro │
└──────────┘             │  (CI/CD)   │                │  Docker)  │
                         └─────┬──────┘                └─────┬─────┘
                               │ merge a main                │ pull
                               ▼                             ▼
                         ┌────────────┐               ┌────────────┐
                         │    Helm    │ ────────────► │    EKS     │
                         │  upgrade   │   despliegue  │  Cluster   │
                         └────────────┘               │  (K8s 1.34)│
                                                      └────────────┘
Infraestructura como código: Terraform (EKS Auto Mode + ECR) + backend S3/DynamoDB
```

### Servicios desplegados (13 microservicios + bases de datos)

adservice, cartservice, checkoutservice, currencyservice, emailservice,
frontend, loadgenerator, paymentservice, productcatalogservice,
recommendationservice, reviewservice, shippingservice,
shoppingassistantservice + redis-cart + postgres-review-db

---

## 3. Herramientas utilizadas

| Herramienta | Uso |
|-------------|-----|
| Git + GitHub | Control de versiones y repositorio central |
| GitHub Actions | Pipelines de CI/CD (7 workflows: CI, CD, release manual y 4 de validación) |
| Docker | Construcción de imágenes de los microservicios |
| Amazon ECR | Registro privado de imágenes de contenedor |
| Terraform | Infraestructura como código (EKS, add-ons, ECR; backend S3 + DynamoDB) |
| actionlint + ShellCheck | Validación estática de los workflows antes de cada build |
| Amazon EKS | Cluster de Kubernetes administrado (v1.34, modo Auto) |
| Helm | Empaquetado y despliegue de la aplicación |
| kubectl | Administración y verificación del cluster |

---

## 4. Evidencia por etapa

### 4.1 Repositorio en GitHub

- **URL:** https://github.com/OnlineBoutique-DevOps/online-boutique-devops
- **Rama principal:** `main` (rama por defecto; cada push dispara CI → CD)
- **Pull Request:** #2 — rama `feature/devops-cicd-implementation`, mergeado el
  25/09/2026 con todos los checks en verde
- **Commits finales de la entrega:** `7021a9b8` (corrección de workflows) y
  `e63b5325` (Terraform gestionando EKS)

**Estructura relevante del repositorio:**

```
microservices-demo/
├── .github/workflows/
│   ├── ci.yml                      # CI: actionlint + build & push de 13 imágenes a ECR
│   ├── deploy.yml                  # CD: helm upgrade en EKS tras CI exitoso en main
│   ├── make-release.yaml           # Release manual: versiona imágenes en ECR (vX.Y.Z)
│   ├── terraform-validate-ci.yaml  # terraform fmt / init / validate
│   ├── helm-chart-ci.yaml          # helm lint --strict + render de 6 variantes
│   ├── kubevious-manifests-ci.yaml # Reglas de buenas prácticas Kubernetes
│   └── kustomize-build-ci.yaml     # Validación de overlays kustomize
├── helm-chart/                     # Chart personalizado de la aplicación
│   ├── Chart.yaml                  # onlineboutique 0.11.0
│   ├── values.yaml
│   └── templates/                  # 14 microservicios + ConfigMap + Secret
├── terraform/                      # Infraestructura como código
│   ├── main.tf                     # aws_eks_cluster (Auto Mode), aws_eks_addon, aws_ecr_repository
│   ├── variables.tf                # Región, roles IAM, subredes, lista de microservicios
│   ├── output.tf                   # Endpoint, SG del clúster, URLs ECR
│   ├── moved.tf                    # Renombre seguro de recursos en el estado
│   └── providers.tf                # Provider AWS + backend S3/DynamoDB
└── src/                            # Código fuente de los 13 microservicios
```

> 📷 **CAPTURA 1:** Vista del repositorio en GitHub mostrando la estructura de carpetas.

---

### 4.2 Imágenes Docker en Amazon ECR

Se crearon **13 repositorios ECR** (uno por microservicio), definidos en
`terraform/main.tf` con escaneo de vulnerabilidades al hacer push
(`scan_on_push = true`).

**Evidencia (AWS CLI):**

```
$ aws ecr describe-repositories --query "repositories[].repositoryName"

online-boutique/paymentservice
online-boutique/shippingservice
online-boutique/recommendationservice
online-boutique/checkoutservice
online-boutique/cartservice
online-boutique/shoppingassistantservice
online-boutique/frontend
online-boutique/emailservice
online-boutique/loadgenerator
online-boutique/reviewservice
online-boutique/productcatalogservice
online-boutique/adservice
online-boutique/currencyservice
```

Registro: `532727285947.dkr.ecr.us-east-1.amazonaws.com/online-boutique/<servicio>`

Cada imagen se etiqueta con el **SHA del commit** y con `latest`.

> 📷 **CAPTURA 2:** Consola AWS → ECR → lista de repositorios `online-boutique/*`.
> 📷 **CAPTURA 3:** Detalle de un repositorio mostrando los tags de imagen (SHA + latest).

---

### 4.3 Pipeline de CI — GitHub Actions (`ci.yml`)

Al hacer push, el workflow construye las 13 imágenes Docker en paralelo
(matrix strategy) y las sube a ECR.

```yaml
strategy:
  matrix:
    service: [adservice, cartservice, checkoutservice, currencyservice,
              emailservice, frontend, loadgenerator, paymentservice,
              productcatalogservice, recommendationservice, reviewservice,
              shippingservice, shoppingassistantservice]
```

**Evidencia — ejecución exitosa en `main` (1m52s):**

```
CI - Build and Push Docker Images to ECR — main — success
  ✓ Build and Push Docker Images (adservice)           50s
  ✓ Build and Push Docker Images (cartservice)         56s
  ✓ Build and Push Docker Images (checkoutservice)     59s
  ✓ Build and Push Docker Images (currencyservice)     37s
  ✓ Build and Push Docker Images (emailservice)        40s
  ✓ Build and Push Docker Images (frontend)            51s
  ✓ Build and Push Docker Images (loadgenerator)      1m23s
  ✓ Build and Push Docker Images (paymentservice)      40s
  ✓ Build and Push Docker Images (productcatalogservice) 59s
  ✓ Build and Push Docker Images (recommendationservice) 26s
  ✓ Build and Push Docker Images (reviewservice)       17s
  ✓ Build and Push Docker Images (shippingservice)     44s
  ✓ Build and Push Docker Images (shoppingassistantservice) 2m7s
```

> 📷 **CAPTURA 4:** GitHub → Actions → corrida del workflow CI con los 13 jobs en verde.

---

### 4.4 Infraestructura como código — Terraform

El directorio `terraform/` define los repositorios ECR y el backend remoto:

```hcl
backend "s3" {
  bucket         = "online-boutique-tfstate-414931564967"
  key            = "global/s3/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "online-boutique-tflocks"
  encrypt        = true
}
```

- Estado remoto en **S3** con bloqueo de estado vía **DynamoDB**
- El workflow `terraform-validate-ci` ejecuta `terraform init` +
  `terraform validate` automáticamente en cada cambio a `terraform/**`

**Evidencia:**

```
$ terraform validate
Success! The configuration is valid.
```

> 📷 **CAPTURA 5:** Workflow terraform-validate-ci en verde / consola S3 mostrando el bucket del estado.

---

### 4.5 Cluster Kubernetes — Amazon EKS

| Propiedad | Valor |
|-----------|-------|
| Nombre | `online-boutique-cluster` |
| Estado | **ACTIVE** |
| Versión Kubernetes | 1.34 (platform eks.34) |
| Modo | EKS Auto (nodos aprovisionados automáticamente) |
| Región | us-east-1 |

**Evidencia (kubectl):**

```
$ kubectl get nodes -o wide
NAME                  STATUS   ROLES    AGE    VERSION
i-08b077865aa313bb0   Ready    <none>   12m    v1.34.9-eks-8f14419
i-0da14e0d98649f14c   Ready    <none>   100m   v1.34.9-eks-8f14419
```

> 📷 **CAPTURA 6:** Consola AWS → EKS → cluster `online-boutique-cluster` en estado Activo.

---

### 4.6 Despliegue con Helm

Chart personalizado `helm-chart/` (onlineboutique v0.11.0) que despliega los
14 microservicios con sus Deployments, Services, ServiceAccounts y ConfigMaps.

**Evidencia:**

```
$ helm list
NAME            NAMESPACE  REVISION  STATUS    CHART                APP VERSION
onlineboutique  default    3         deployed  onlineboutique-0.11.0  v0.10.6
```

---

### 4.7 Pipeline de CD — Despliegue automático (`deploy.yml`)

Al mergear a `main`, el workflow:

1. Configura credenciales AWS
2. Valida el chart (`helm lint`)
3. Actualiza kubeconfig contra EKS
4. Ejecuta `helm upgrade --install` con las imágenes del commit
5. Verifica el despliegue con `kubectl`

**Evidencia — ejecución exitosa tras el merge del PR #2:**

```
CI/CD Pipeline - Online Boutique (AWS EKS) — main — success (36s)
  ✓ Configurar credenciales de AWS
  ✓ Instalar y configurar Helm
  ✓ Validar Helm Chart (Linting)
  ✓ Actualizar Kubeconfig para Amazon EKS
  ✓ Login en Amazon ECR
  ✓ Desplegar en EKS con Helm
  ✓ Verificar despliegue
```

El frontend se expone como **NodePort** (puerto 32718) — se eligió NodePort
porque AWS Academy no provisiona Elastic Load Balancers.

> 📷 **CAPTURA 7:** GitHub → Actions → corrida del workflow de deploy en verde.

---

### 4.8 Aplicación funcionando — evidencia final

**Los 14 pods en estado Running:**

```
$ kubectl get pods
NAME                                      READY   STATUS    RESTARTS
adservice-5fbf56857d-x5tpl                1/1     Running   0
cartservice-5cddf5599d-mlvrt              1/1     Running   0
checkoutservice-69f47db8d4-64w5h          1/1     Running   0
currencyservice-68cfc98fb7-j7lf8          1/1     Running   0
emailservice-7fff848f78-7r758             1/1     Running   0
frontend-56557fcbfd-z4drg                 1/1     Running   0
loadgenerator-5f5b7d8f7-pt9fq             1/1     Running   0
paymentservice-f48947ff-65fl7             1/1     Running   0
postgres-review-db-896f47844-5tskf        1/1     Running   0
productcatalogservice-67487cb78-vtpr6     1/1     Running   0
recommendationservice-85b7464b76-glgdg    1/1     Running   0
redis-cart-799dccbf6f-84mnt               1/1     Running   0
reviewservice-6c7cb5f7f8-czwct            1/1     Running   0
shippingservice-5bf98668c6-7gsrk          1/1     Running   0
```

**Servicio frontend:**

```
$ kubectl get services frontend
NAME       TYPE       CLUSTER-IP       PORT(S)        AGE
frontend   NodePort   10.100.231.189   80:32718/TCP   57m
```

**Acceso público a la aplicación (NodePort + IP pública del nodo):**

```
http://34.229.144.187:32718   → HTTP 200 ✅
http://44.192.71.247:32718    → HTTP 200 ✅
```

Para exponer el NodePort a internet se agregó una regla de entrada al
security group del cluster (`sg-0fc7bce71ac9054cf`):

```powershell
aws ec2 authorize-security-group-ingress \
  --group-id sg-0fc7bce71ac9054cf \
  --protocol tcp --port 32718 --cidr 0.0.0.0/0
```

Nota: EKS Auto Mode reemplaza nodos periódicamente; las IPs públicas
pueden cambiar (`kubectl get nodes -o wide` para obtener las actuales).

**Acceso alternativo local (port-forward):**

```powershell
kubectl port-forward svc/frontend 8080:80
# → http://localhost:8080   (verificado: HTTP 200)
```

**Logs del frontend procesando tráfico real** (productos, carrito, cambio de
divisas USD/CAD/EUR/JPY/TRY/GBP, health checks `/_healthz`, tráfico del
loadgenerator):

```
$ kubectl logs deployment/frontend
... "GET /product/... HTTP/1.1" 200 ...
... "GET /cart HTTP/1.1" 200 ...
... "GET /_healthz HTTP/1.1" 200 ...
```

> 📷 **CAPTURA 8:** La tienda Online Boutique abierta en el navegador
> (página principal con productos).
> 📷 **CAPTURA 9:** Página de un producto / carrito funcionando.
> 📷 **CAPTURA 10:** `kubectl get pods` mostrando los 14 pods en Running.

---

## 5. Problemas encontrados y soluciones

| Problema | Causa | Solución |
|----------|-------|----------|
| `terraform init` fallaba en CI | Recursos `aws_ecr_repository` duplicados entre `main.tf` y `ecr-only.tf` | Se eliminó el archivo temporal `ecr-only.tf`; `main.tf` quedó como fuente única |
| Workflow kubevious fallaba | El Deployment de frontend referenciaba un ServiceAccount que el chart no creaba + regla anti-`latest` | Se agregó el ServiceAccount al template `frontend.yaml` y `skip_rules: container-latest-image` |
| Service `frontend` quedaba LoadBalancer `<pending>` | El template tenía `type: LoadBalancer` hardcodeado; AWS Academy no provisiona ELB | Template ahora respeta `frontend.service.type`; deploy usa NodePort |
| `helm upgrade` fallaba tras agregar el SA | El SA `frontend` existía (creado manualmente con kubectl) sin metadata de Helm | Se etiquetó/anotó el SA para que Helm lo adoptara (`meta.helm.sh/release-*`) |
| Workflow `cleanup.yaml` fallaba al cerrar PRs | Workflow heredado del repo original que intenta autenticarse al GKE de Google | Se eliminó el workflow (infra de Google, no aplica al proyecto AWS) |
| NodePort no accesible desde internet | El security group del cluster solo permitía tráfico interno | Regla ingress TCP 32718 desde 0.0.0.0/0 en `sg-0fc7bce71ac9054cf` |
| EC2 → Instances aparece vacío | EKS **Auto Mode** gestiona los nodos en infraestructura de AWS; no son instancias visibles en la cuenta | Los nodos se verifican con `kubectl get nodes` y en EKS → pestaña Compute |
| Credenciales expiran | AWS Academy emite credenciales temporales por sesión | Actualizar `~/.aws/credentials` y los secrets de GitHub al reiniciar el lab |

---

## 6. Flujo CI/CD demostrado end-to-end

1. Commit/push a `feature/**` → CI construye y sube las 13 imágenes a ECR ✅
2. Pull Request → checks automáticos: CI, terraform-validate, helm-chart-ci,
   kubevious ✅
3. Merge a `main` → CI vuelve a construir + **CD despliega a EKS con Helm** ✅
4. Rolling update de los pods con la imagen del nuevo commit ✅
5. Aplicación disponible y procesando tráfico ✅

---

## 7. Conclusiones

[Redactar: qué aprendiste, qué parte fue más difícil, qué harías diferente.
Ejemplo de puntos a mencionar:]
- Automatización completa del ciclo build → push → deploy
- IaC con Terraform y estado remoto compartido
- Helm como herramienta de empaquetado y releases versionadas
- Limitaciones de AWS Academy (sin ELB, credenciales temporales, IAM restringido)
  y cómo se resolvieron (NodePort, port-forward, adopción de recursos)

---

## 8. Anexo — comandos utilizados

```powershell
# AWS
aws sts get-caller-identity
aws eks update-kubeconfig --name online-boutique-cluster --region us-east-1
aws ecr describe-repositories
aws s3 ls s3://online-boutique-tfstate-414931564967

# Kubernetes
kubectl get nodes -o wide
kubectl get pods
kubectl get services
kubectl logs deployment/frontend
kubectl port-forward svc/frontend 8080:80
kubectl rollout status deployment/frontend

# Helm
helm lint ./helm-chart
helm list
helm template onlineboutique ./helm-chart

# Terraform
terraform init -backend=false
terraform validate
terraform fmt -check

# GitHub CLI
gh run list
gh pr checks 2
gh pr merge 2 --merge
```

---

## 9. Limpieza de recursos (para evitar costos)

Cuando el laboratorio ya no se necesite:

```powershell
# Desinstalar la aplicación
helm uninstall onlineboutique

# El cluster EKS y los nodos se eliminan al expirar el lab de AWS Academy.
# Los repositorios ECR persisten; para borrarlos:
aws ecr delete-repository --repository-name online-boutique/<servicio> --force
# (repetir por cada uno de los 13, o terraform destroy con credenciales válidas)
```1111111111111111
