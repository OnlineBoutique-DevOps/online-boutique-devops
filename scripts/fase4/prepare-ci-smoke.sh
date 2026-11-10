#!/usr/bin/env bash
# Reto 2 (Fase IV): dejar listo el smoke test GitHub Actions -> Vault en la cuenta nueva.
#
# Ejecutar DESDE WSL (Ubuntu-22.04, usuario palomagmt) con el lab encendido y Vault unsealed:
#   bash /mnt/c/Users/LaMamalona/Documents/GitHub/online-boutique-google/microservices-demo/scripts/fase4/prepare-ci-smoke.sh
#
# Hace dos cosas:
#   1. Instala el runner self-hosted de GitHub (etiqueta vault-network) como servicio
#      systemd en el EC2 de Vault. GitHub-hosted runners no tienen ruta al Vault
#      privado; el EC2 si (localhost) y ya tiene egress HTTPS hacia GitHub.
#   2. Actualiza el rol JWT github-ci-probe para aceptar tanto main como la rama de
#      trabajo (bound_claims admite listas): asi el run puede ser verde antes del merge
#      y sigue rechazando cualquier otra rama/workflow (prueba negativa).
#
# El runner debe retirarse tras la demo (repo publico): ver al final.
set -euo pipefail

KEY=/home/palomagmt/.ssh/vault-admin
PUBIP=3.229.76.82
STATE=/home/palomagmt/.local/state/online-boutique-vault
REPO="OnlineBoutique-DevOps/online-boutique-devops"
BRANCH="feature/fase3-vault-ansible"
RUNNER_VERSION="2.338.2"
SSH="ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new -i $KEY ec2-user@$PUBIP"
V="VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 /usr/bin/vault"
GH="/mnt/c/Program Files/GitHub CLI/gh.exe"; command -v gh >/dev/null && GH=gh

echo "==> [1/3] token de registro del runner (gh api, valido 1 h)"
REG_TOKEN=$("$GH" api -X POST "repos/$REPO/actions/runners/registration-token" --jq .token | tr -d '\r')
[[ -n "$REG_TOKEN" ]] || { echo "no se obtuvo token; revisa 'gh auth status'"; exit 1; }

echo "==> [2/3] instalando actions-runner $RUNNER_VERSION en el EC2 (servicio systemd)"
$SSH "set -e
  if [ -f ~/actions-runner/.runner ]; then echo '    runner ya configurado'; sudo systemctl is-active actions.runner.* 2>/dev/null | head -1; exit 0; fi
  sudo dnf install -y -q libicu >/dev/null 2>&1 || true
  mkdir -p ~/actions-runner && cd ~/actions-runner
  curl -sSL -o runner.tgz https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-linux-x64-$RUNNER_VERSION.tar.gz
  tar xzf runner.tgz && rm runner.tgz
  ./config.sh --unattended --url https://github.com/$REPO --token $REG_TOKEN --name vault-ec2-runner --labels vault-network --replace >/dev/null
  sudo ./svc.sh install ec2-user >/dev/null && sudo ./svc.sh start >/dev/null
  sleep 3; sudo ./svc.sh status | grep -E 'active|running' | head -1"
unset REG_TOKEN
"$GH" api "repos/$REPO/actions/runners" --jq '.runners[] | "    runner: \(.name) status=\(.status) labels=\(.labels|map(.name)|join(","))"'

echo "==> [3/3] rol github-ci-probe: aceptar main y $BRANCH (sigue negando cualquier otra rama)"
ROOT=$(gpg -d "$STATE"/init-2026110*.json.gpg 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['root_token'])")
cat > /tmp/gh-role.json <<EOF
{"role_type":"jwt","bound_audiences":["https://github.com/OnlineBoutique-DevOps"],"user_claim":"repository",
 "bound_claims":{"repository":"$REPO",
   "ref":["refs/heads/main","refs/heads/$BRANCH"],
   "workflow_ref":["$REPO/.github/workflows/vault-smoke.yml@refs/heads/main","$REPO/.github/workflows/vault-smoke.yml@refs/heads/$BRANCH"]},
 "token_policies":["github-ci-probe"],"token_ttl":"5m","token_max_ttl":"5m","token_type":"service"}
EOF
scp -q -i "$KEY" /tmp/gh-role.json ec2-user@$PUBIP:/tmp/gh-role.json && rm -f /tmp/gh-role.json
$SSH "export VAULT_TOKEN=$ROOT; $V write auth/jwt/role/github-ci-probe @/tmp/gh-role.json >/dev/null && rm -f /tmp/gh-role.json && $V read -field=bound_claims auth/jwt/role/github-ci-probe"
unset ROOT

cat <<EOF

==> LISTO. Lanza el smoke test y toma la captura del run en verde:
      gh workflow run vault-smoke.yml --ref $BRANCH
      gh run watch
    Prueba negativa (debe FALLAR con 'claim ... does not match'): lanzar cualquier otro
    workflow que intente leer Vault, o el mismo workflow desde otra rama.

==> Al terminar la demo, retira el runner (repo publico):
      ssh -i $KEY ec2-user@$PUBIP 'cd ~/actions-runner && sudo ./svc.sh stop && sudo ./svc.sh uninstall && ./config.sh remove --token \$(gh api -X POST repos/$REPO/actions/runners/remove-token --jq .token)'
EOF
