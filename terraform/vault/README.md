# Propuesta Terraform aislada para Vault

Esta carpeta es una configuración Terraform separada para la Fase III. Declara una instancia EC2 dedicada, un grupo de seguridad, un volumen raíz cifrado y un volumen EBS gp3 separado para los datos Raft. El volumen de datos tiene `prevent_destroy` para evitar que una eliminación accidental de Terraform lo borre. Consulta la VPC y subnet existentes; no administra ni cambia EKS, ECR, sus roles o sus grupos de seguridad. No declara backend remoto: el estado local deberá permanecer fuera del control de versiones y protegerse como archivo sensible de infraestructura.

## Requisitos antes de planificar

1. Confirmar en Learner Lab el presupuesto disponible, la VPC/subred seleccionadas, las rutas y permisos para EC2, EBS y Security Groups.
2. Obtener la salida `cluster_security_group_id` del Terraform existente y confirmar que puede usarse como origen de tráfico.
3. Elegir acceso administrativo. `assign_public_ip` y `enable_ssh` quedan `false` por defecto. Si SSM no está disponible, la alternativa Ansible es habilitar ambos solo en subnet pública, fijar `admin_cidr` a la IP actual del administrador con `/32` y proporcionar el nombre de un key pair ya existente. Nunca se añade la clave privada al repositorio.
4. Preparar un archivo local de variables basado en variables no secretas; no guardar credenciales, tokens ni claves privadas en Git. No se provee un `tfvars` con IDs porque deben verificarse en la cuenta.
5. El host no instala Vault desde user-data: la instalación y el montaje XFS del volumen de datos se realizan desde el rol idempotente `ansible/roles/vault_server`.

## Validación local y ejecución futura

La configuración se formateó con Terraform 1.16.5 y pasó `terraform fmt -check` y `terraform validate` con Terraform 1.14.9. `terraform init -backend=false` descargó el provider AWS 5.100.0. La ejecución inicial de `validate` dentro del sandbox no pudo iniciar el proceso local del provider; al repetirla con permisos locales ampliados pasó. `.terraform-version` fija la versión que sí se validó. La inicialización fue local, sin backend remoto ni llamadas a AWS.

No se ejecutó `terraform plan`: sus data sources necesitan consultar la cuenta y la subnet de AWS, información no disponible sin conexión/credenciales del Learner Lab. Por inspección, este módulo declara solo un Security Group nuevo, una EC2, un volumen EBS y su attachment. No declara ni administra recursos EKS o ECR. Revisa el plan real antes de cualquier `apply`.

Comandos de validación local ya ejecutados desde esta carpeta:

```sh
terraform fmt
terraform init -backend=false
terraform validate
```

Cuando se autorice una consulta de planificación, con credenciales temporales válidas del Learner Lab:

```sh
terraform plan -out=vault.tfplan
```

Revisar el plan y confirmar que solo crea el Security Group, EC2, volumen EBS de datos y attachment previstos. `terraform init` descarga el provider y `plan` consulta AWS; ninguno debe ejecutarse hasta que se autorice esa comprobación. `terraform apply` no forma parte de esta propuesta y requerirá aprobación explícita posterior.

## Límites deliberados

- No se crea VPC, NAT Gateway, balanceador, endpoint privado, rol IAM, Instance Profile ni runner.
- No se configura SSM automáticamente porque la disponibilidad de roles/permisos de Learner Lab no está confirmada.
- La regla administrativa y la regla desde el SG de EKS se limitan a TCP/8200. Vault deberá escuchar con TLS antes de aceptar clientes. SSH solo se añade con `enable_ssh=true` y el mismo `/32` aprobado.
- El origen SG del clúster es una propuesta inicial; verificar el camino real de red de nodos/pods antes de integrar Vault. No se modifica el SG existente.
- La salida HTTPS y DNS permite instalar paquetes y resolver servicios. Revisar si el Lab ofrece una ruta de salida existente; no añadir NAT como solución automática.
