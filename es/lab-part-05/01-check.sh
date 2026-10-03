#!/usr/bin/env bash
# lab-part-05 step 1 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
W="$HOME/cka-comico-lab/p05"; K="kubectl --kubeconfig $W/kubeconfig"; R="$W/01-respuesta.txt"
test -f "$R" || exit 1
grep -qxF "RAZON_SANCOCHO=ImagePullBackOff" "$R" || exit 1
grep -qxF "RAZON_BANDEJA=CreateContainerConfigError" "$R" || exit 1
grep -qxF "RECURSO_FALTANTE=la-carta-vieja" "$R" || exit 1
grep -qxF "TAG_INEXISTENTE=1.29-alpinita" "$R" || exit 1
for d in sancocho bandeja; do
  test "$($K -n cuchara-de-oro get deploy "$d" -o jsonpath='{.spec.replicas}' 2>/dev/null)" = "2" || exit 1
  test "$($K -n cuchara-de-oro get deploy "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "2" || exit 1
done
IMG=$($K -n cuchara-de-oro get deploy sancocho -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
case "$IMG" in
  nginx:*|nginx@*|docker.io/library/nginx:*|docker.io/library/nginx@*) ;;
  *) exit 1 ;;
esac
echo "$IMG" | grep -qF "sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de" || exit 1
CMN=$($K -n cuchara-de-oro get deploy bandeja -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PRECIO_ALMUERZO")].valueFrom.configMapKeyRef.name}' 2>/dev/null)
CMK=$($K -n cuchara-de-oro get deploy bandeja -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PRECIO_ALMUERZO")].valueFrom.configMapKeyRef.key}' 2>/dev/null)
test "$CMN" = "la-carta" || exit 1
test "$CMK" = "PRECIO_ALMUERZO" || exit 1
VAL=$($K -n cuchara-de-oro get configmap la-carta -o jsonpath='{.data.PRECIO_ALMUERZO}' 2>/dev/null)
test -n "$VAL" || exit 1
POD=$($K -n cuchara-de-oro get pod -l app=bandeja --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
test -n "$POD" || exit 1
VIVO=$($K -n cuchara-de-oro exec "$POD" -- printenv PRECIO_ALMUERZO 2>/dev/null | tr -d '\r\n')
test "$VIVO" = "$VAL" || exit 1
echo ok
