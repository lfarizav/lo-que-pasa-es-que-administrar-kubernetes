#!/usr/bin/env bash
# lab-part-01 step 5 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

cd ~/cka-comico-lab/p01
KC="$HOME/cka-comico-lab/p01/kubeconfig"
K="kubectl --kubeconfig $KC --context kind-cka-comico-p01"

kubectl --kubeconfig "$KC" config view --raw \
  -o jsonpath='{range .contexts[*]}{.name}{" -> cluster="}{.context.cluster}{" user="}{.context.user}{"\n"}{end}'

TOKEN=$($K -n la-casa create token la-empleada --duration=24h)
echo "longitud del token: ${#TOKEN}"

kubectl --kubeconfig "$KC" config set-credentials la-empleada --token="$TOKEN"

kubectl --kubeconfig "$KC" config set-context la-empleada \
  --cluster=kind-cka-comico-p01 \
  --user=la-empleada \
  --namespace=la-casa

kubectl --kubeconfig "$KC" config get-contexts

E="kubectl --kubeconfig $KC --context la-empleada"

$E auth whoami
$E get pods
$E delete pod la-alarma --dry-run=server
$E get pods -n la-finca-vecina

$K -n la-casa get pod la-alarma

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p01"
SALIDA=$($E delete pod la-alarma --dry-run=server 2>&1 || true)
cat > "$D/05-respuesta.txt" <<EOF
CONTEXTO_NUEVO=la-empleada
USUARIO_DEL_CONTEXTO=$(kubectl --kubeconfig "$KC" config view --raw -o jsonpath='{.contexts[?(@.name=="la-empleada")].context.user}')
CLUSTER_DEL_CONTEXTO=$(kubectl --kubeconfig "$KC" config view --raw -o jsonpath='{.contexts[?(@.name=="la-empleada")].context.cluster}')
PALABRA_DEL_RECHAZO=$(printf '%s\n' "$SALIDA" | sed -n 's/^Error from server (\([A-Za-z]*\)).*/\1/p' | head -1)
EOF
cat "$D/05-respuesta.txt"
