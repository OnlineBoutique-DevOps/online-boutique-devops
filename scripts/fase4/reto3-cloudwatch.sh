#!/usr/bin/env bash
# Reto 3 (Fase IV): verificar la centralizacion de logs en CloudWatch.
#
# Flujo:
#   1. Verifica que los Log Groups creados por Terraform existan.
#   2. Despliega/actualiza Fluent Bit (kubernetes/cloudwatch) y espera a que
#      haya un pod Running por nodo.
#   3. Genera trafico real contra la tienda (home, producto, carrito, login)
#      para forzar la emision de logs del frontend y reviewservice.
#   4. Hace `aws logs tail --follow` del grupo de aplicacion: lo que se ve aqui
#      es lo mismo que la consola CloudWatch > Log groups > Live tail.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REGION="${AWS_REGION:-us-east-1}"
APP_LG="/online-boutique/application"
EKS_LG="/aws/eks/online-boutique-cluster/cluster"
REQUESTS="${REQUESTS:-30}"

echo "==> [1/4] Log Groups gestionados por Terraform"
aws logs describe-log-groups --region "$REGION" \
  --query "logGroups[?logGroupName=='$APP_LG' || logGroupName=='$EKS_LG'].{Grupo:logGroupName,RetencionDias:retentionInDays,Bytes:storedBytes}" \
  --output table
if ! aws logs describe-log-groups --region "$REGION" --log-group-name-prefix "$APP_LG" --query 'logGroups[0].logGroupName' --output text | grep -q "$APP_LG"; then
  echo "    El grupo $APP_LG no existe. Ejecuta primero: cd terraform && terraform apply"
  exit 1
fi

echo "==> [2/4] Fluent Bit (DaemonSet) -> CloudWatch"
kubectl apply -f "$ROOT/kubernetes/cloudwatch/"
kubectl rollout status daemonset/fluent-bit -n amazon-cloudwatch --timeout=180s
kubectl get pods -n amazon-cloudwatch -o wide

echo "==> [3/4] Generando $REQUESTS solicitudes contra la tienda"
URL="${APP_URL:-}"
if [[ -z "$URL" ]]; then
  NODE_IP="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')"
  URL="http://$NODE_IP:30576"
fi
echo "    URL: $URL"
PRODUCTS=(0PUK6V6EV0 1YMWWN1N4O 2ZYFJ3GM2N 66VCHSJNUP 6E92ZMYYFZ 9SIQT8TOJO L9ECAV7KIM LS4PSXUNUM OLJCESPC7Z)
for i in $(seq 1 "$REQUESTS"); do
  P="${PRODUCTS[$((RANDOM % ${#PRODUCTS[@]}))]}"
  curl -s -o /dev/null -w "    %{http_code} GET /\n"            "$URL/"
  curl -s -o /dev/null -w "    %{http_code} GET /product/$P\n"  "$URL/product/$P"
  curl -s -o /dev/null -w "    %{http_code} GET /login\n"       "$URL/login"
  curl -s -o /dev/null -w "    %{http_code} POST /login (credenciales invalidas a proposito)\n" \
       -X POST "$URL/login" --data-urlencode "email=drift@test.com" --data-urlencode "password=incorrecta"
  sleep 0.5
done

echo "==> [4/4] Streams y eventos en $APP_LG (Ctrl+C para salir)"
aws logs describe-log-streams --region "$REGION" --log-group-name "$APP_LG" \
  --order-by LastEventTime --descending --max-items 10 \
  --query 'logStreams[].{Stream:logStreamName,UltimoEvento:lastEventTimestamp}' --output table
echo "    Abre tambien: CloudWatch > Log groups > $APP_LG > Live tail  (CAPTURA)"
aws logs tail "$APP_LG" --region "$REGION" --since 5m --follow --format short
