#!/usr/bin/env bash
# lab-part-04 step 4 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

KC="$HOME/cka-comico-lab/p04/kubeconfig"
cd ~/cka-comico-lab/p04

cat > rescate.yaml <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: lote-de-rescate
  namespace: cuchara-de-oro
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 128Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: mudanza
  namespace: cuchara-de-oro
spec:
  containers:
  - name: mudanza
    image: busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0
    command: ["sh", "-c", "sleep 86400"]
    volumeMounts:
    - name: rescate
      mountPath: /rescate
  volumes:
  - name: rescate
    persistentVolumeClaim:
      claimName: lote-de-rescate
YAML
kubectl --kubeconfig "$KC" apply -f rescate.yaml
kubectl --kubeconfig "$KC" -n cuchara-de-oro wait --for=condition=Ready pod/mudanza --timeout=180s
kubectl --kubeconfig "$KC" -n cuchara-de-oro exec mudanza -- \
  sh -c 'echo "las-escrituras-de-la-casa" > /rescate/documentos.txt'

PVR=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc lote-de-rescate -o jsonpath='{.spec.volumeName}')
echo "PV aprovisionado para el rescate: $PVR"
echo "politica ANTES: $(kubectl --kubeconfig "$KC" get pv "$PVR" -o jsonpath='{.spec.persistentVolumeReclaimPolicy}')"

kubectl --kubeconfig "$KC" patch pv "$PVR" \
  -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
echo "politica DESPUES: $(kubectl --kubeconfig "$KC" get pv "$PVR" -o jsonpath='{.spec.persistentVolumeReclaimPolicy}')"

kubectl --kubeconfig "$KC" -n cuchara-de-oro delete pod mudanza --wait=true
kubectl --kubeconfig "$KC" -n cuchara-de-oro delete pvc lote-de-rescate --wait=true

for i in $(seq 1 12); do
  F=$(kubectl --kubeconfig "$KC" get pv "$PVR" -o jsonpath='{.status.phase}' 2>/dev/null)
  echo "t=$((i*5))s fase del PV=$F"
  [ "$F" = "Released" ] && break
  sleep 5
done
echo "--- el deposito sobrevivio al contrato ---"
kubectl --kubeconfig "$KC" get pv
kubectl --kubeconfig "$KC" get pv "$PVR" \
  -o jsonpath='fase={.status.phase}{"\n"}politica={.spec.persistentVolumeReclaimPolicy}{"\n"}claimRef={.spec.claimRef.namespace}/{.spec.claimRef.name}{"\n"}'
kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p04"
SC_DEF=$(kubectl --kubeconfig "$KC" get sc \
  -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' | head -1)
cat > "$D/04-respuesta.txt" <<EOF
PV_RESCATADO=$PVR
POLITICA_ANTES=$(kubectl --kubeconfig "$KC" get sc "$SC_DEF" -o jsonpath='{.reclaimPolicy}')
POLITICA_DESPUES=$(kubectl --kubeconfig "$KC" get pv "$PVR" -o jsonpath='{.spec.persistentVolumeReclaimPolicy}')
FASE_FINAL=$(kubectl --kubeconfig "$KC" get pv "$PVR" -o jsonpath='{.status.phase}')
EOF
cat "$D/04-respuesta.txt"
