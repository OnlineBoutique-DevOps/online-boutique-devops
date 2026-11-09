#!/usr/bin/env bash
# Reto 1 (Fase IV): detectar drift entre la consola de AWS y el estado de Terraform.
#
# Flujo:
#   1. Muestra las reglas actuales del Security Group de Vault (estado "real").
#   2. Espera a que el operador borre/modifique una regla a mano en la consola.
#   3. Ejecuta `terraform plan -detailed-exitcode`:
#        0 = sin cambios, 1 = error, 2 = HAY DRIFT (plan propone cambios)
#   4. Guarda el log del plan como evidencia en docs/evidencias/fase4/.
#
# No aplica nada. Reconciliar (terraform apply) es una decision aparte.
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash: no convertir /online-boutique/... en rutas de Windows

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT/terraform/vault}"
OUT_DIR="$ROOT/docs/evidencias/fase4"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$OUT_DIR/reto1-terraform-plan-$STAMP.log"
mkdir -p "$OUT_DIR"

SG_ID="$(cd "$TF_DIR" && terraform output -raw vault_security_group_id 2>/dev/null | tr -d '\r' || true)"
if [[ -z "$SG_ID" ]]; then
  SG_ID="$(aws ec2 describe-security-groups --filters Name=group-name,Values=online-boutique-vault-sg \
           --query 'SecurityGroups[0].GroupId' --output text)"
fi

echo "==> Security Group gestionado por Terraform: $SG_ID"
echo "==> Reglas ACTUALES en AWS (antes de la modificacion manual):"
aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$SG_ID" \
  --query 'SecurityGroupRules[?IsEgress==`false`].{Puerto:FromPort,Origen:CidrIpv4,OrigenSG:ReferencedGroupInfo.GroupId,Desc:Description}' \
  --output table

cat <<EOF

==> AHORA, en la consola web de AWS:
    EC2 > Security Groups > $SG_ID > Inbound rules > Edit
    - Borra la regla SSH (22) o cambia su CIDR, y guarda.
    - Toma la CAPTURA 1 (consola mostrando la regla eliminada/modificada).

EOF
read -r -p "Presiona ENTER cuando hayas hecho el cambio manual... "

echo "==> Ejecutando terraform plan en $TF_DIR (log: $LOG)"
set +e
( cd "$TF_DIR" && terraform plan -detailed-exitcode -no-color -input=false ) 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}
set -e

echo
case "$RC" in
  0) echo "==> Sin drift: la consola coincide con el codigo. (Revisa que el cambio manual se haya guardado.)" ;;
  2) echo "==> DRIFT DETECTADO: Terraform propone cambios para volver al estado declarado."
     echo "    Evidencia guardada en: $LOG"
     echo "    Toma la CAPTURA 2 (esta terminal o el archivo de log)."
     echo
     echo "    Para reconciliar (opcional, cuando termine la demo):"
     echo "      cd $TF_DIR && terraform apply" ;;
  *) echo "==> terraform plan fallo (rc=$RC). Revisa credenciales de AWS Academy (expiran con la sesion)."; exit "$RC" ;;
esac
