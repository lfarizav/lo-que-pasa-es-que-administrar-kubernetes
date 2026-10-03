#!/usr/bin/env bash
# lab-part-02 step 2 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

cd ~/cka-comico-lab/p02
KC="$HOME/cka-comico-lab/p02/kubeconfig"

VIEJA=nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236

kubectl --kubeconfig "$KC" get nodes
kubectl --kubeconfig "$KC" get nodes \
  -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.taints}{"\n"}{end}'

NODO=cka-comico-p02-worker

kubectl --kubeconfig "$KC" taint node "$NODO" dedicated=cuchara-de-oro:NoSchedule
kubectl --kubeconfig "$KC" label node "$NODO" puesto=cuchara-de-oro

kubectl --kubeconfig "$KC" get node "$NODO" \
  -o jsonpath='{range .spec.taints[*]}{.key}{"="}{.value}{":"}{.effect}{"\n"}{end}'

cat > turno-de-la-noche.yaml <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: turno-de-la-noche
  namespace: cuchara-de-oro
spec:
  replicas: 2
  selector:
    matchLabels:
      app: turno-de-la-noche
  template:
    metadata:
      labels:
        app: turno-de-la-noche
    spec:
      nodeSelector:
        puesto: cuchara-de-oro
      tolerations:
      - key: dedicated
        operator: Equal
        value: cuchara-de-oro
        effect: NoSchedule
      containers:
      - name: nginx
        image: $VIEJA
        resources:
          requests:
            cpu: 20m
            memory: 32Mi
YAML

kubectl --kubeconfig "$KC" apply -f turno-de-la-noche.yaml
kubectl --kubeconfig "$KC" -n cuchara-de-oro rollout status deployment/turno-de-la-noche --timeout=300s

kubectl --kubeconfig "$KC" -n cuchara-de-oro get pods -l app=turno-de-la-noche -o wide

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p02"
cat > "$D/02-respuesta.txt" <<EOF
NODO_RESERVADO=$NODO
LLAVE_DEL_TAINT=$(kubectl --kubeconfig "$KC" get node "$NODO" -o jsonpath='{.spec.taints[?(@.key=="dedicated")].key}')
EFECTO_DEL_TAINT=$(kubectl --kubeconfig "$KC" get node "$NODO" -o jsonpath='{.spec.taints[?(@.key=="dedicated")].effect}')
EOF
cat "$D/02-respuesta.txt"
