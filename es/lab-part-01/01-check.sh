#!/usr/bin/env bash
# lab-part-01 step 1 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/cka-comico-lab/p01"
K="kubectl --kubeconfig $D/kubeconfig --context kind-cka-comico-p01"
test -f "$D/01-respuesta.txt" || exit 1
NODO=$($K get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
test -n "$NODO" || exit 1
docker inspect "$NODO" >/dev/null 2>&1 || exit 1
MANIF=$(docker exec "$NODO" sh -c 'ls -1 /etc/kubernetes/manifests 2>/dev/null | wc -l' | tr -d '[:space:]')
test -n "$MANIF" || exit 1
test "$MANIF" -ge 4 || exit 1
grep -qxF "MANIFIESTOS_ESTATICOS=$MANIF" "$D/01-respuesta.txt" || exit 1
for ARCHIVO in $(docker exec "$NODO" sh -c 'ls -1 /etc/kubernetes/manifests' | tr -d '\r'); do
  COMPONENTE="${ARCHIVO%.yaml}"
  DUENO=$($K -n kube-system get pod "${COMPONENTE}-${NODO}" -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null)
  test "$DUENO" = "Node" || exit 1
  FUENTE=$($K -n kube-system get pod "${COMPONENTE}-${NODO}" -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.source}' 2>/dev/null)
  test "$FUENTE" = "file" || exit 1
done
DUENO_API=$($K -n kube-system get pod "kube-apiserver-${NODO}" -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null)
test "$DUENO_API" = "Node" || exit 1
grep -qxF "DUENO_DEL_APISERVER=$DUENO_API" "$D/01-respuesta.txt" || exit 1
FUENTE_API=$($K -n kube-system get pod "kube-apiserver-${NODO}" -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.source}' 2>/dev/null)
test "$FUENTE_API" = "file" || exit 1
grep -qxF "FUENTE_DE_CONFIG=$FUENTE_API" "$D/01-respuesta.txt" || exit 1
POD_PROXY=$($K -n kube-system get pods -l k8s-app=kube-proxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
test -n "$POD_PROXY" || exit 1
DUENO_PROXY=$($K -n kube-system get pod "$POD_PROXY" -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null)
test "$DUENO_PROXY" = "DaemonSet" || exit 1
grep -qxF "DUENO_DEL_KUBE_PROXY=$DUENO_PROXY" "$D/01-respuesta.txt" || exit 1
docker exec "$NODO" sh -c 'test -f /etc/kubernetes/manifests/kube-proxy.yaml' && exit 1
$K -n kube-system get daemonset kube-proxy >/dev/null 2>&1 || exit 1
echo ok
