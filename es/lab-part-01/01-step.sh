#!/usr/bin/env bash
# lab-part-01 step 1 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

cd ~/cka-comico-lab/p01
KC="$HOME/cka-comico-lab/p01/kubeconfig"
K="kubectl --kubeconfig $KC --context kind-cka-comico-p01"

NODO=$($K get nodes -o jsonpath='{.items[0].metadata.name}')
echo "nodo de control: $NODO"

$K -n kube-system get pods -o wide

docker exec "$NODO" ls -1 /etc/kubernetes/manifests
docker exec "$NODO" sh -c 'ls -1 /etc/kubernetes/manifests | wc -l'

$K -n kube-system get pod "kube-apiserver-${NODO}" \
  -o jsonpath='{.metadata.ownerReferences[0].kind}{"\n"}'
$K -n kube-system get pod "kube-apiserver-${NODO}" \
  -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.source}{"\n"}'

for COMPONENTE in etcd kube-apiserver kube-controller-manager kube-scheduler; do
  printf '%s -> dueno=%s fuente=%s\n' "$COMPONENTE" \
    "$($K -n kube-system get pod "${COMPONENTE}-${NODO}" -o jsonpath='{.metadata.ownerReferences[0].kind}')" \
    "$($K -n kube-system get pod "${COMPONENTE}-${NODO}" -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.source}')"
done

$K -n kube-system get daemonsets

POD_PROXY=$($K -n kube-system get pods -l k8s-app=kube-proxy \
  -o jsonpath='{.items[0].metadata.name}')
$K -n kube-system get pod "$POD_PROXY" \
  -o jsonpath='{.metadata.ownerReferences[0].kind}{"\n"}'

docker exec "$NODO" ls -l /etc/kubernetes/manifests/kube-proxy.yaml

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p01"
cat > "$D/01-respuesta.txt" <<EOF
MANIFIESTOS_ESTATICOS=$(docker exec "$NODO" sh -c 'ls -1 /etc/kubernetes/manifests | wc -l' | tr -d '[:space:]')
DUENO_DEL_APISERVER=$($K -n kube-system get pod "kube-apiserver-${NODO}" -o jsonpath='{.metadata.ownerReferences[0].kind}')
FUENTE_DE_CONFIG=$($K -n kube-system get pod "kube-apiserver-${NODO}" -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.source}')
DUENO_DEL_KUBE_PROXY=$($K -n kube-system get pod "$POD_PROXY" -o jsonpath='{.metadata.ownerReferences[0].kind}')
EOF
cat "$D/01-respuesta.txt"
