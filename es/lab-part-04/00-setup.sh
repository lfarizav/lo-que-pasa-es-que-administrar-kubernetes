#!/usr/bin/env bash
# lab-part-04 - setup
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

KC="$HOME/cka-comico-lab/p04/kubeconfig"
NODO_IMG="kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5"

for tool in kind kubectl docker; do
  command -v "$tool" >/dev/null 2>&1 || { echo "FALTA: $tool - instalelo antes de empezar."; exit 1; }
done

mkdir -p "$HOME/cka-comico-lab/p04"
cat > "$HOME/cka-comico-lab/p04/kind.yaml" <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
YAML

kind get clusters 2>/dev/null | grep -qx cka-comico-p04 || \
  kind create cluster --name cka-comico-p04 \
    --kubeconfig "$KC" \
    --image "$NODO_IMG" \
    --config "$HOME/cka-comico-lab/p04/kind.yaml" \
    --wait 180s

test -f "$KC" || kind export kubeconfig --name cka-comico-p04 --kubeconfig "$KC"
chmod 600 "$KC"

kubectl --kubeconfig "$KC" wait --for=condition=Ready node --all --timeout=180s

TRABAJADOR=$(kubectl --kubeconfig "$KC" get nodes \
  -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')
if [ -z "$TRABAJADOR" ]; then
  echo "ERROR SUSTRATO_SIN_WORKER: el cluster no tiene ningun nodo worker. Los Pasos 1 y 2 anclan un PV hostPath a un worker y sin el todo lo que sigue seria decoracion. Borre el cluster con kind delete cluster --name cka-comico-p04 y vuelva a correr este setup con el kind.yaml de dos nodos."
  exit 1
fi
echo "nodo worker detectado: $TRABAJADOR"

kubectl --kubeconfig "$KC" create namespace cka-sustrato >/dev/null 2>&1
kubectl --kubeconfig "$KC" apply -f - >/dev/null <<YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: sonda-estatica
spec:
  capacity:
    storage: 64Mi
  accessModes:
  - ReadWriteOnce
  storageClassName: ""
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /var/cka-sustrato/sonda
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $TRABAJADOR
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sonda-estatica
  namespace: cka-sustrato
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: ""
  resources:
    requests:
      storage: 64Mi
YAML

ENLAZADO=no
for i in $(seq 1 12); do
  FPV=$(kubectl --kubeconfig "$KC" get pv sonda-estatica -o jsonpath='{.status.phase}' 2>/dev/null)
  FPVC=$(kubectl --kubeconfig "$KC" -n cka-sustrato get pvc sonda-estatica -o jsonpath='{.status.phase}' 2>/dev/null)
  if [ "$FPV" = "Bound" ] && [ "$FPVC" = "Bound" ]; then ENLAZADO=si; break; fi
  sleep 5
done
kubectl --kubeconfig "$KC" delete namespace cka-sustrato --wait=false >/dev/null 2>&1
kubectl --kubeconfig "$KC" delete pv sonda-estatica --wait=false >/dev/null 2>&1

if [ "$ENLAZADO" != "si" ]; then
  echo "ERROR SUSTRATO_SIN_ENLACE_ESTATICO: despues de 60 segundos el controlador de PersistentVolume no habia enlazado un PV estatico con su PVC. Todo el Paso 1 y el Paso 2 de este laboratorio serian decoracion hasta que eso funcione. Revise: kubectl --kubeconfig $KC -n kube-system logs -l component=kube-controller-manager --tail=50"
  exit 1
fi
echo "prueba de sustrato 1 OK: el controlador enlaza de verdad un PV estatico con su PVC."

SC_DEF=$(kubectl --kubeconfig "$KC" get sc \
  -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | head -1)
if [ -z "$SC_DEF" ]; then
  echo "ERROR SUSTRATO_SIN_STORAGECLASS_POR_DEFECTO: ninguna StorageClass lleva la anotacion storageclass.kubernetes.io/is-default-class=true, asi que un PVC sin storageClassName no seria aprovisionado por nadie y los Pasos 3 y 4 no tendrian nada que observar. Revise: kubectl --kubeconfig $KC get sc"
  exit 1
fi
MODO=$(kubectl --kubeconfig "$KC" get sc "$SC_DEF" -o jsonpath='{.volumeBindingMode}' 2>/dev/null)
if [ "$MODO" != "WaitForFirstConsumer" ]; then
  echo "ERROR SUSTRATO_SIN_ESPERA: la StorageClass por defecto $SC_DEF tiene volumeBindingMode=$MODO, no WaitForFirstConsumer. El Paso 3 entero se trata de observar un PVC que se queda en Pending hasta que alguien lo consuma, y con Immediate ese comportamiento no existe. Revise: kubectl --kubeconfig $KC get sc $SC_DEF -o yaml"
  exit 1
fi
echo "prueba de sustrato 2 OK: la StorageClass por defecto es $SC_DEF y difiere el enlace hasta el primer consumidor."

kubectl --kubeconfig "$KC" get namespace cuchara-de-oro >/dev/null 2>&1 || \
  kubectl --kubeconfig "$KC" create namespace cuchara-de-oro

echo "espacio de trabajo listo en ~/cka-comico-lab/p04"
echo "cluster cka-comico-p04 (1 control-plane + 1 worker) con kubeconfig privado en $KC"
echo "aprovisionador por defecto: $(kubectl --kubeconfig "$KC" get sc "$SC_DEF" -o jsonpath='{.provisioner}')"
