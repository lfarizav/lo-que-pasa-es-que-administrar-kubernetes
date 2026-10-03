#!/usr/bin/env bash
# lab-part-02 step 3 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

cd ~/cka-comico-lab/p02
KC="$HOME/cka-comico-lab/p02/kubeconfig"

VIEJA=nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236

kubectl --kubeconfig "$KC" get nodes \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.allocatable.memory}{"\n"}{end}'

TECHO_KI=$(kubectl --kubeconfig "$KC" get nodes \
  -o jsonpath='{range .items[*]}{.status.allocatable.memory}{"\n"}{end}' \
  | sed 's/Ki$//' | sort -n | tail -1)
echo "el nodo mas grande ofrece ${TECHO_KI}Ki"

GRANDE=$(( TECHO_KI * 4 ))
echo "vamos a pedir ${GRANDE}Ki"

cat > pedido-gigante.yaml <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pedido-gigante
  namespace: cuchara-de-oro
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pedido-gigante
  template:
    metadata:
      labels:
        app: pedido-gigante
    spec:
      containers:
      - name: nginx
        image: $VIEJA
        resources:
          requests:
            memory: "${GRANDE}Ki"
            cpu: 50m
YAML

kubectl --kubeconfig "$KC" apply -f pedido-gigante.yaml
sleep 8

kubectl --kubeconfig "$KC" -n cuchara-de-oro get pods -l app=pedido-gigante -o wide

kubectl --kubeconfig "$KC" -n cuchara-de-oro get pods -l app=pedido-gigante \
  -o jsonpath='{.items[0].status.conditions[?(@.type=="PodScheduled")].message}{"\n"}'

kubectl --kubeconfig "$KC" -n cuchara-de-oro get events \
  --field-selector reason=FailedScheduling \
  -o jsonpath='{range .items[*]}{.reason}{" | "}{.involvedObject.name}{" | "}{.message}{"\n"}{end}'

kubectl --kubeconfig "$KC" -n cuchara-de-oro set resources deployment/pedido-gigante \
  --requests=memory=64Mi,cpu=50m
kubectl --kubeconfig "$KC" -n cuchara-de-oro rollout status deployment/pedido-gigante --timeout=300s

kubectl --kubeconfig "$KC" -n cuchara-de-oro get pods -l app=pedido-gigante -o wide
kubectl --kubeconfig "$KC" -n cuchara-de-oro get deployment pedido-gigante \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}{"\n"}'

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p02"
MENSAJE=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get events --field-selector reason=FailedScheduling \
  -o jsonpath='{.items[0].message}')
cat > "$D/03-respuesta.txt" <<EOF
MEMORIA_PEDIDA_INICIAL=${GRANDE}Ki
RAZON_DEL_EVENTO=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get events --field-selector reason=FailedScheduling -o jsonpath='{.items[0].reason}')
MOTIVO_EXACTO=$(echo "$MENSAJE" | grep -oE 'Insufficient [a-z]+' | head -1)
EOF
cat "$D/03-respuesta.txt"
