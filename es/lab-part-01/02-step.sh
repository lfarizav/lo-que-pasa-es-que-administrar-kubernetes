#!/usr/bin/env bash
# lab-part-01 step 2 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

cd ~/cka-comico-lab/p01
KC="$HOME/cka-comico-lab/p01/kubeconfig"
K="kubectl --kubeconfig $KC --context kind-cka-comico-p01"

$K -n la-casa create serviceaccount la-empleada

$K -n la-casa create role lector-de-pods \
  --verb=get --verb=list --resource=pods

$K -n la-casa create rolebinding entrega-de-llave \
  --role=lector-de-pods \
  --serviceaccount=la-casa:la-empleada

$K -n la-casa get serviceaccount,role,rolebinding
$K -n la-casa get role lector-de-pods -o jsonpath='{.rules}{"\n"}'
$K -n la-casa get rolebinding entrega-de-llave \
  -o jsonpath='{.roleRef.kind}{" -> "}{.roleRef.name}{"\n"}'

SUJETO=system:serviceaccount:la-casa:la-empleada

$K auth can-i get    pods -n la-casa         --as="$SUJETO"
$K auth can-i list   pods -n la-casa         --as="$SUJETO"
$K auth can-i delete pods -n la-casa         --as="$SUJETO"
$K auth can-i get    pods -n la-finca-vecina --as="$SUJETO"
$K auth can-i '*' '*' -n la-casa             --as="$SUJETO"

$K auth can-i --list -n la-casa --as="$SUJETO"

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p01"
cat > "$D/02-respuesta.txt" <<EOF
PUEDE_LEER_EN_LA_CASA=$($K auth can-i get pods -n la-casa --as="$SUJETO" || true)
PUEDE_BORRAR_EN_LA_CASA=$($K auth can-i delete pods -n la-casa --as="$SUJETO" || true)
PUEDE_LEER_EN_LA_VECINA=$($K auth can-i get pods -n la-finca-vecina --as="$SUJETO" || true)
TIPO_DE_ENTREGA=$($K -n la-casa get rolebinding entrega-de-llave -o jsonpath='{.kind}')
EOF
cat "$D/02-respuesta.txt"
