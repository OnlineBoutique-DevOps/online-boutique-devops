# Logs de los microservicios a Amazon CloudWatch (Fase IV - Reto 3)

Fluent Bit corre como **DaemonSet** en cada nodo de EKS Auto Mode, lee `/var/log/containers/*.log`
de los pods del namespace `default`, los enriquece con metadatos de Kubernetes y los envia al
Log Group `/online-boutique/application` (un stream por microservicio: `frontend`, `reviewservice`, ...).

## Por que asi

| Decision | Motivo |
|---|---|
| El Log Group lo crea **Terraform**, no Fluent Bit (`auto_create_group false`) | El reto pide creacion desde codigo; ademas permite fijar retencion y detectar drift si alguien lo borra en la consola |
| **DaemonSet** y no sidecar por pod | Un agente por nodo cubre los 14 microservicios sin tocar el Helm chart de la app |
| `hostNetwork: true` | AWS Academy no permite crear roles IAM (sin IRSA ni Pod Identity). Fluent Bit usa el rol del nodo via IMDS; Auto Mode limita IMDS a hop 1, y con hostNetwork la llamada es local |
| Excluye `kube-system`, `amazon-cloudwatch`, `vault-secrets-operator` | Solo logs de la aplicacion; menos ruido y menos costo |
| Imagen `aws-for-fluent-bit` con version fija | Reproducible; el plugin `cloudwatch_logs` nativo es el recomendado por AWS |

## Despliegue

```bash
cd terraform && terraform apply            # crea /online-boutique/application y adopta /aws/eks/.../cluster
kubectl apply -f kubernetes/cloudwatch/
kubectl rollout status ds/fluent-bit -n amazon-cloudwatch
bash scripts/fase4/reto3-cloudwatch.sh     # trafico + aws logs tail
```

## Si el rol del nodo no tiene permisos de CloudWatch Logs

Los pods mostraran `AccessDeniedException` en `kubectl logs -n amazon-cloudwatch ds/fluent-bit`.
Como fallback (solo laboratorio) se pueden inyectar las credenciales temporales de AWS Academy
en un Secret que el DaemonSet lee de forma opcional. **Nunca se guardan en el repo** y expiran
con la sesion del lab:

```bash
kubectl -n amazon-cloudwatch create secret generic cloudwatch-credentials \
  --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  --from-literal=AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"
kubectl -n amazon-cloudwatch rollout restart ds/fluent-bit
```

## Pausa/reanudacion del laboratorio

No requiere pasos extra: al escalar los deployments a 0 los nodos desaparecen y con ellos los pods
del DaemonSet; cuando Auto Mode vuelve a crear nodos, Fluent Bit se programa solo.
