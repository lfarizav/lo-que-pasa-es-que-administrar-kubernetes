#!/usr/bin/env bash
# lab-part-03 step 3 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

cd ~/cka-comico-lab/p03
K="kubectl --kubeconfig $HOME/cka-comico-lab/p03/kubeconfig"
IMG=nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de
BB=busybox:1.37@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0

$K -n el-conjunto run casa-vecina --image=$IMG --labels=rol=servidor --port=80
$K -n el-conjunto run visita-autorizada --image=$BB --labels=acceso=permitido --command -- sleep 36000
$K -n el-conjunto run visita-colada     --image=$BB --labels=acceso=negado    --command -- sleep 36000
$K -n el-conjunto wait --for=condition=Ready pod --all --timeout=300s

DESTINO=$($K -n el-conjunto get pod casa-vecina -o jsonpath='{.status.podIP}')
echo "casa-vecina vive en $DESTINO"

echo "--- LINEA BASE, sin ninguna politica ---"
$K -n el-conjunto exec visita-autorizada -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1
echo "autorizada antes: $?"
$K -n el-conjunto exec visita-colada -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1
echo "colada antes: $?"

cat > politicas.yaml <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: negar-todo-lo-que-entra
  namespace: el-conjunto
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dejar-entrar-la-visita-autorizada
  namespace: el-conjunto
spec:
  podSelector:
    matchLabels:
      rol: servidor
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          acceso: permitido
    ports:
    - protocol: TCP
      port: 80
YAML

$K apply -f politicas.yaml
$K -n el-conjunto get networkpolicies
sleep 5

echo "--- DESPUES DE PONER AL CELADOR ---"
$K -n el-conjunto exec visita-autorizada -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1
echo "autorizada despues: $?"
$K -n el-conjunto exec visita-colada -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1
echo "colada despues: $?"

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p03"
AUTORIZADA=0
$K -n el-conjunto exec visita-autorizada -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1 || AUTORIZADA=$?
COLADA=0
$K -n el-conjunto exec visita-colada -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1 || COLADA=$?
cat > "$D/03-respuesta.txt" <<EOF
SALIDA_AUTORIZADA=$AUTORIZADA
SALIDA_COLADA=$COLADA
EOF
cat "$D/03-respuesta.txt"
