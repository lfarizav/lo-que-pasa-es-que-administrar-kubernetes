#!/usr/bin/env bash
# lab-part-02 step 1 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/cka-comico-lab/p02"
K="kubectl --kubeconfig $D/kubeconfig"
NS=cuchara-de-oro
VIEJA="nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236"
NUEVA="nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de"
test -f "$D/01-respuesta.txt" || exit 1
REV=$($K -n $NS get deployment receta-del-dia -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' 2>/dev/null)
test -n "$REV" || exit 1
test "$REV" -ge 3 || exit 1
grep -qxF "REVISION_ACTUAL=$REV" "$D/01-respuesta.txt" || exit 1
IMG=$($K -n $NS get deployment receta-del-dia -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
test "$IMG" = "$VIEJA" || exit 1
grep -qxF "IMAGEN_ACTUAL=$IMG" "$D/01-respuesta.txt" || exit 1
DESEADAS=$($K -n $NS get deployment receta-del-dia -o jsonpath='{.spec.replicas}' 2>/dev/null)
LISTAS=$($K -n $NS get deployment receta-del-dia -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
test -n "$LISTAS" || exit 1
test "$LISTAS" = "$DESEADAS" || exit 1
test "$LISTAS" -ge 3 || exit 1
grep -qxF "REPLICAS_LISTAS=$LISTAS" "$D/01-respuesta.txt" || exit 1
CONJUNTOS=$($K -n $NS get rs -l app=receta-del-dia -o jsonpath='{range .items[*]}{.spec.template.spec.containers[0].image}{"|"}{.spec.replicas}{"\n"}{end}' 2>/dev/null)
test "$(echo "$CONJUNTOS" | grep -c '|')" -ge 2 || exit 1
echo "$CONJUNTOS" | grep -qxF "$NUEVA|0" || exit 1
echo "$CONJUNTOS" | grep -qxF "$VIEJA|$DESEADAS" || exit 1
echo ok
