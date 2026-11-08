# 5. Observabilidad: CloudWatch Log Groups (Fase IV - Reto 3)
#
# Centralizamos dos fuentes de registros:
#   a) Plano de control de EKS: api, audit, authenticator, controllerManager y
#      scheduler (habilitados en aws_eks_cluster.enabled_cluster_log_types).
#      Terraform crea el grupo ANTES que el cluster (depends_on en
#      aws_eks_cluster) para fijar retencion y poder detectar drift si alguien
#      lo borra o modifica desde la consola.
#   b) Pods de la aplicacion: Fluent Bit (kubernetes/cloudwatch/) corre como
#      DaemonSet en cada nodo de Auto Mode y envia stdout/stderr de todos los
#      microservicios a este grupo. `auto_create_group` esta deshabilitado en
#      Fluent Bit a proposito: la creacion del grupo debe venir de Terraform.
#
# La retencion se fija explicitamente porque el valor por defecto de
# CloudWatch es "nunca expirar" y en un laboratorio con creditos limitados
# eso se traduce en costo acumulado sin valor.

resource "aws_cloudwatch_log_group" "eks_control_plane" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.log_retention_days

  tags = {
    Project   = "online-boutique"
    Component = "eks-control-plane"
    ManagedBy = "terraform"
  }
}


resource "aws_cloudwatch_log_group" "application" {
  name              = "/online-boutique/application"
  retention_in_days = var.log_retention_days

  tags = {
    Project   = "online-boutique"
    Component = "microservices"
    ManagedBy = "terraform"
  }
}
