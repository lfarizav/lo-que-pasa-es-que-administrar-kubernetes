#!/usr/bin/env bash
# lab-part-01 step 5 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/cka-comico-lab/p01"
KC="$D/kubeconfig"
K="kubectl --kubeconfig $KC --context kind-cka-comico-p01"
CASA=la-casa
CUENTA=la-empleada
test -f "$D/05-respuesta.txt" || exit 1
CTX=$(grep -oP '(?<=^CONTEXTO_NUEVO=).*' "$D/05-respuesta.txt")
test -n "$CTX" || exit 1
test "$CTX" != "kind-cka-comico-p01" || exit 1
CFG=$(kubectl --kubeconfig "$KC" config view --raw -o json 2>/dev/null)
USUARIO=$(echo "$CFG" | jq -r --arg c "$CTX" '.contexts[]? | select(.name == $c) | .context.user // empty')
CLUSTER=$(echo "$CFG" | jq -r --arg c "$CTX" '.contexts[]? | select(.name == $c) | .context.cluster // empty')
test -n "$USUARIO" || exit 1
test -n "$CLUSTER" || exit 1
USUARIO_ADMIN=$(echo "$CFG" | jq -r '.contexts[]? | select(.name == "kind-cka-comico-p01") | .context.user // empty')
CLUSTER_ADMIN=$(echo "$CFG" | jq -r '.contexts[]? | select(.name == "kind-cka-comico-p01") | .context.cluster // empty')
test "$CLUSTER" = "$CLUSTER_ADMIN" || exit 1
test "$USUARIO" != "$USUARIO_ADMIN" || exit 1
TOKEN=$(echo "$CFG" | jq -r --arg u "$USUARIO" '.users[]? | select(.name == $u) | .user.token // empty')
test -n "$TOKEN" || exit 1
grep -qxF "USUARIO_DEL_CONTEXTO=$USUARIO" "$D/05-respuesta.txt" || exit 1
grep -qxF "CLUSTER_DEL_CONTEXTO=$CLUSTER" "$D/05-respuesta.txt" || exit 1
QUIEN=$(kubectl --kubeconfig "$KC" --context "$CTX" auth whoami -o jsonpath='{.status.userInfo.username}' 2>/dev/null)
test "$QUIEN" = "system:serviceaccount:${CASA}:${CUENTA}" || exit 1
FASE=$($K -n "$CASA" get pod la-alarma -o jsonpath='{.status.phase}' 2>/dev/null)
test "$FASE" = "Running" || exit 1
kubectl --kubeconfig "$KC" --context "$CTX" -n "$CASA" get pods >/dev/null 2>&1 || exit 1
SALIDA=$(kubectl --kubeconfig "$KC" --context "$CTX" -n "$CASA" delete pod la-alarma --dry-run=server 2>&1) && exit 1
PALABRA=$(printf '%s\n' "$SALIDA" | sed -n 's/^Error from server (\([A-Za-z]*\)).*/\1/p' | head -1)
test "$PALABRA" = "Forbidden" || exit 1
grep -qxF "PALABRA_DEL_RECHAZO=$PALABRA" "$D/05-respuesta.txt" || exit 1
FASE2=$($K -n "$CASA" get pod la-alarma -o jsonpath='{.status.phase}' 2>/dev/null)
test "$FASE2" = "Running" || exit 1
LOCALES=$($K -n "$CASA" get rolebindings -o json 2>/dev/null | jq --arg n "$CUENTA" --arg ns "$CASA" '[.items[] | select(.subjects != null) | select(any(.subjects[]; .kind == "ServiceAccount" and .name == $n and ((.namespace == $ns) or (.namespace == null))))] | length')
test "$LOCALES" -ge 1 || exit 1
GLOBALES=$($K get clusterrolebindings -o json 2>/dev/null | jq --arg n "$CUENTA" --arg ns "$CASA" '[.items[] | select(.subjects != null) | select(any(.subjects[]; .kind == "ServiceAccount" and .name == $n and .namespace == $ns))] | length')
test "$GLOBALES" = "0" || exit 1
echo ok
