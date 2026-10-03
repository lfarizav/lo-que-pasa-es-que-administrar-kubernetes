#!/usr/bin/env bash
# lab-part-01 step 4 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/cka-comico-lab/p01"
K="kubectl --kubeconfig $D/kubeconfig --context kind-cka-comico-p01"
RESPALDO="$D/respaldo-de-la-finca.db"
test -f "$D/04-respuesta.txt" || exit 1
NODO=$($K get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
test -n "$NODO" || exit 1
CERT=$(docker exec "$NODO" sh -c "grep -oE '\-\-cert-file=[^[:space:]]+' /etc/kubernetes/manifests/etcd.yaml | head -1" | cut -d= -f2 | tr -d '\r')
test -n "$CERT" || exit 1
grep -qxF "RUTA_DEL_CERT_DE_SERVIDOR=$CERT" "$D/04-respuesta.txt" || exit 1
test -s "$RESPALDO" || exit 1
TAM=$(stat -c%s "$RESPALDO")
test "$TAM" -gt 32 || exit 1
CALCULADO=$(head -c $((TAM - 32)) "$RESPALDO" | sha256sum | cut -d' ' -f1)
GUARDADO=$(tail -c 32 "$RESPALDO" | od -An -v -tx1 | tr -d ' \n')
test "$CALCULADO" = "$GUARDADO" || exit 1
POD_ETCD="etcd-${NODO}"
$K -n kube-system get pod "$POD_ETCD" >/dev/null 2>&1 || exit 1
docker cp "$RESPALDO" "${NODO}:/var/lib/etcd/calificacion-respaldo.db" >/dev/null 2>&1 || exit 1
ESTADO=$($K -n kube-system exec "$POD_ETCD" -- etcdutl snapshot status /var/lib/etcd/calificacion-respaldo.db --write-out=json 2>/dev/null | tail -1)
docker exec "$NODO" rm -f /var/lib/etcd/calificacion-respaldo.db >/dev/null 2>&1
echo "$ESTADO" | jq -e '.revision and .totalKey' >/dev/null 2>&1 || exit 1
REVISION=$(echo "$ESTADO" | jq -r '.revision')
LLAVES=$(echo "$ESTADO" | jq -r '.totalKey')
grep -qxF "REVISION_DEL_RESPALDO=$REVISION" "$D/04-respuesta.txt" || exit 1
grep -qxF "TOTAL_DE_LLAVES=$LLAVES" "$D/04-respuesta.txt" || exit 1
echo ok
