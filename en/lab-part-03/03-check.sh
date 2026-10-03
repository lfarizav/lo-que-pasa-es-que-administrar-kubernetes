#!/usr/bin/env bash
# lab-part-03 step 3 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/cka-comico-lab/p03"
K="kubectl --kubeconfig $D/kubeconfig"
test -f "$D/03-respuesta.txt" || exit 1
test "$($K -n el-conjunto get netpol negar-todo-lo-que-entra -o jsonpath='{.spec.podSelector}' 2>/dev/null)" = "{}" || exit 1
$K -n el-conjunto get netpol negar-todo-lo-que-entra -o jsonpath='{.spec.policyTypes[*]}' 2>/dev/null | grep -qw Ingress || exit 1
test -z "$($K -n el-conjunto get netpol negar-todo-lo-que-entra -o jsonpath='{.spec.ingress}' 2>/dev/null)" || exit 1
$K -n el-conjunto get netpol dejar-entrar-la-visita-autorizada -o jsonpath='{.spec.podSelector.matchLabels.rol}' 2>/dev/null | grep -qx servidor || exit 1
$K -n el-conjunto get netpol dejar-entrar-la-visita-autorizada -o jsonpath='{.spec.policyTypes[*]}' 2>/dev/null | grep -qw Ingress || exit 1
$K -n el-conjunto get netpol dejar-entrar-la-visita-autorizada -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels.acceso}' 2>/dev/null | grep -qx permitido || exit 1
$K -n el-conjunto get pod casa-vecina -o jsonpath='{.metadata.labels.rol}' 2>/dev/null | grep -qx servidor || exit 1
$K -n el-conjunto get pod visita-autorizada -o jsonpath='{.metadata.labels.acceso}' 2>/dev/null | grep -qx permitido || exit 1
$K -n el-conjunto get pod visita-colada -o jsonpath='{.metadata.labels.acceso}' 2>/dev/null | grep -qx negado || exit 1
DESTINO=$($K -n el-conjunto get pod casa-vecina -o jsonpath='{.status.podIP}' 2>/dev/null)
test -n "$DESTINO" || exit 1
$K -n el-conjunto exec visita-autorizada -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1 || exit 1
if $K -n el-conjunto exec visita-colada -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1; then exit 1; fi
grep -qxF "SALIDA_AUTORIZADA=0" "$D/03-respuesta.txt" || exit 1
COLADA=$(grep -oP '(?<=SALIDA_COLADA=).*' "$D/03-respuesta.txt")
test -n "$COLADA" || exit 1
test "$COLADA" != "0" || exit 1
echo ok
