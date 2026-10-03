#!/usr/bin/env bash
# lab-part-04 step 3 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

KC="$HOME/cka-comico-lab/p04/kubeconfig"
cd ~/cka-comico-lab/p04

kubectl --kubeconfig "$KC" get sc
SC_DEF=$(kubectl --kubeconfig "$KC" get sc \
  -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' | head -1)
echo "storageclass por defecto: $SC_DEF"
kubectl --kubeconfig "$KC" get sc "$SC_DEF" \
  -o jsonpath='provisioner={.provisioner}{"\n"}volumeBindingMode={.volumeBindingMode}{"\n"}reclaimPolicy={.reclaimPolicy}{"\n"}allowVolumeExpansion={.allowVolumeExpansion}{"\n"}'

cat > lote.yaml <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: lote-por-encargo
  namespace: cuchara-de-oro
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
YAML
kubectl --kubeconfig "$KC" apply -f lote.yaml
sleep 15
echo "--- sin consumidor ---"
kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc lote-por-encargo
kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc lote-por-encargo \
  -o jsonpath='fase={.status.phase}{"\n"}volumeName=[{.spec.volumeName}]{"\n"}'
kubectl --kubeconfig "$KC" -n cuchara-de-oro describe pvc lote-por-encargo | tail -6

cat > constructor.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: constructor
  namespace: cuchara-de-oro
spec:
  containers:
  - name: constructor
    image: busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0
    command: ["sh", "-c", "sleep 86400"]
    volumeMounts:
    - name: lote
      mountPath: /lote
  volumes:
  - name: lote
    persistentVolumeClaim:
      claimName: lote-por-encargo
YAML
kubectl --kubeconfig "$KC" apply -f constructor.yaml
kubectl --kubeconfig "$KC" -n cuchara-de-oro wait --for=condition=Ready pod/constructor --timeout=180s
echo "--- con consumidor ---"
kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc lote-por-encargo
PVNAME=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc lote-por-encargo -o jsonpath='{.spec.volumeName}')
echo "PV creado por el aprovisionador: $PVNAME"
kubectl --kubeconfig "$KC" get pv "$PVNAME" \
  -o jsonpath='provisioned-by={.metadata.annotations.pv\.kubernetes\.io/provisioned-by}{"\n"}storageClassName={.spec.storageClassName}{"\n"}reclaimPolicy={.spec.persistentVolumeReclaimPolicy}{"\n"}'

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p04"
cat > "$D/03-respuesta.txt" <<EOF
APROVISIONADOR=$(kubectl --kubeconfig "$KC" get sc "$SC_DEF" -o jsonpath='{.provisioner}')
MODO_DE_ENLACE=$(kubectl --kubeconfig "$KC" get sc "$SC_DEF" -o jsonpath='{.volumeBindingMode}')
FASE_SIN_CONSUMIDOR=Pending
EOF
cat "$D/03-respuesta.txt"
