#!/usr/bin/env bash
# lab-part-01 step 2 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/cka-comico-lab/p01"
K="kubectl --kubeconfig $D/kubeconfig --context kind-cka-comico-p01"
CUENTA=la-empleada
CASA=la-casa
VECINA=la-finca-vecina
test -f "$D/02-respuesta.txt" || exit 1
$K -n "$CASA" get serviceaccount "$CUENTA" >/dev/null 2>&1 || exit 1
SUJETO="system:serviceaccount:${CASA}:${CUENTA}"
LEER=$($K auth can-i get pods -n "$CASA" --as="$SUJETO" 2>/dev/null)
LISTAR=$($K auth can-i list pods -n "$CASA" --as="$SUJETO" 2>/dev/null)
BORRAR=$($K auth can-i delete pods -n "$CASA" --as="$SUJETO" 2>/dev/null)
AFUERA=$($K auth can-i get pods -n "$VECINA" --as="$SUJETO" 2>/dev/null)
TODO=$($K auth can-i '*' '*' -n "$CASA" --as="$SUJETO" 2>/dev/null)
test "$LEER" = "yes" || exit 1
test "$LISTAR" = "yes" || exit 1
test "$BORRAR" = "no" || exit 1
test "$AFUERA" = "no" || exit 1
test "$TODO" = "no" || exit 1
grep -qxF "PUEDE_LEER_EN_LA_CASA=$LEER" "$D/02-respuesta.txt" || exit 1
grep -qxF "PUEDE_BORRAR_EN_LA_CASA=$BORRAR" "$D/02-respuesta.txt" || exit 1
grep -qxF "PUEDE_LEER_EN_LA_VECINA=$AFUERA" "$D/02-respuesta.txt" || exit 1
LOCALES=$($K -n "$CASA" get rolebindings -o json 2>/dev/null | jq --arg n "$CUENTA" --arg ns "$CASA" '[.items[] | select(.subjects != null) | select(any(.subjects[]; .kind == "ServiceAccount" and .name == $n and ((.namespace == $ns) or (.namespace == null))))]')
CUANTOS=$(echo "$LOCALES" | jq 'length')
test "$CUANTOS" -ge 1 || exit 1
TIPO=$(echo "$LOCALES" | jq -r '.[0].kind')
test "$TIPO" = "RoleBinding" || exit 1
grep -qxF "TIPO_DE_ENTREGA=$TIPO" "$D/02-respuesta.txt" || exit 1
GLOBALES=$($K get clusterrolebindings -o json 2>/dev/null | jq --arg n "$CUENTA" --arg ns "$CASA" '[.items[] | select(.subjects != null) | select(any(.subjects[]; .kind == "ServiceAccount" and .name == $n and .namespace == $ns))] | length')
test "$GLOBALES" = "0" || exit 1
echo ok
