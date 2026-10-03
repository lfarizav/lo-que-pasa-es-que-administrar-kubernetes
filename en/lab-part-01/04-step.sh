#!/usr/bin/env bash
# lab-part-01 step 4 (10 pts)
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

docker exec "$NODO" grep -E -- '--(cert-file|key-file|trusted-ca-file|listen-client-urls)=' \
  /etc/kubernetes/manifests/etcd.yaml

$K -n kube-system exec "etcd-${NODO}" -- etcdctl version

$K -n kube-system exec "etcd-${NODO}" -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  snapshot save /var/lib/etcd/respaldo-de-la-finca.db

$K -n kube-system exec "etcd-${NODO}" -- etcdctl snapshot --help

$K -n kube-system exec "etcd-${NODO}" -- etcdutl \
  snapshot status /var/lib/etcd/respaldo-de-la-finca.db --write-out=table

docker cp "${NODO}:/var/lib/etcd/respaldo-de-la-finca.db" \
  ~/cka-comico-lab/p01/respaldo-de-la-finca.db

ls -l ~/cka-comico-lab/p01/respaldo-de-la-finca.db

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p01"
ESTADO=$($K -n kube-system exec "etcd-${NODO}" -- etcdutl snapshot status /var/lib/etcd/respaldo-de-la-finca.db --write-out=json | tail -1)
cat > "$D/04-respuesta.txt" <<EOF
RUTA_DEL_CERT_DE_SERVIDOR=$(docker exec "$NODO" grep -oE -- '--cert-file=[^[:space:]]+' /etc/kubernetes/manifests/etcd.yaml | head -1 | cut -d= -f2 | tr -d '\r')
REVISION_DEL_RESPALDO=$(echo "$ESTADO" | jq -r '.revision')
TOTAL_DE_LLAVES=$(echo "$ESTADO" | jq -r '.totalKey')
EOF
cat "$D/04-respuesta.txt"
