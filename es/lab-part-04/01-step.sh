#!/usr/bin/env bash
# lab-part-04 step 1 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

KC="$HOME/cka-comico-lab/p04/kubeconfig"
cd ~/cka-comico-lab/p04
TRABAJADOR=$(kubectl --kubeconfig "$KC" get nodes \
  -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')
echo "el deposito va a quedar en el nodo: $TRABAJADOR"

cat > deposito.yaml <<YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: deposito-de-la-finca
spec:
  capacity:
    storage: 512Mi
  accessModes:
  - ReadWriteOnce
  storageClassName: ""
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /var/deposito-de-la-finca
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $TRABAJADOR
YAML

cat > contrato.yaml <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: contrato-de-la-cocina
  namespace: cuchara-de-oro
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: ""
  resources:
    requests:
      storage: 512Mi
YAML

kubectl --kubeconfig "$KC" apply -f deposito.yaml
kubectl --kubeconfig "$KC" get pv deposito-de-la-finca
kubectl --kubeconfig "$KC" apply -f contrato.yaml

for i in $(seq 1 12); do
  FPV=$(kubectl --kubeconfig "$KC" get pv deposito-de-la-finca -o jsonpath='{.status.phase}' 2>/dev/null)
  FPVC=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc contrato-de-la-cocina -o jsonpath='{.status.phase}' 2>/dev/null)
  echo "t=$((i*5))s pv=$FPV pvc=$FPVC"
  [ "$FPV" = "Bound" ] && [ "$FPVC" = "Bound" ] && break
  sleep 5
done

kubectl --kubeconfig "$KC" get pv deposito-de-la-finca
kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc contrato-de-la-cocina
kubectl --kubeconfig "$KC" get pv deposito-de-la-finca \
  -o jsonpath='claimRef={.spec.claimRef.namespace}/{.spec.claimRef.name}{"\n"}'
kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc contrato-de-la-cocina \
  -o jsonpath='volumeName={.spec.volumeName}{"\n"}'

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p04"
cat > "$D/01-respuesta.txt" <<EOF
PV_DEL_CONTRATO=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc contrato-de-la-cocina -o jsonpath='{.spec.volumeName}')
CLAIMREF_DEL_PV=$(kubectl --kubeconfig "$KC" get pv deposito-de-la-finca -o jsonpath='{.spec.claimRef.namespace}/{.spec.claimRef.name}')
EOF
cat "$D/01-respuesta.txt"
