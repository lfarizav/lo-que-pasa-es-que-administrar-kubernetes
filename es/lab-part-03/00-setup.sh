#!/usr/bin/env bash
# lab-part-03 - setup
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

mkdir -p ~/cka-comico-lab/p03
cd ~/cka-comico-lab/p03

for tool in kind kubectl docker curl base64; do
  command -v "$tool" >/dev/null 2>&1 || echo "FALTA: $tool - instalelo antes de continuar."
done

for p in 8080; do
  ss -ltn "sport = :$p" 2>/dev/null | grep -q LISTEN && echo "OCUPADO: el puerto $p del host esta en uso; cambielo en kind-p03.yaml."
done

cat > kind-p03.yaml <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: "10.244.0.0/16"
nodes:
- role: control-plane
  image: kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
YAML

kind create cluster --name cka-comico-p03 \
  --kubeconfig ~/cka-comico-lab/p03/kubeconfig \
  --config kind-p03.yaml

K="kubectl --kubeconfig $HOME/cka-comico-lab/p03/kubeconfig"

echo "instalando Calico v3.32.1 (un cluster armado con kubeadm arranca sin CNI y usted instala uno)"

# Los CRD van primero y explicitos. El operador tambien los instala solo al
# arrancar, pero lo hace unos segundos DESPUES de que su Deployment queda
# rolled out, asi que aplicar el recurso Installation enseguida falla con
# "no matches for kind Installation" y el resto se cae en cascada.
$K apply --server-side \
  -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/operator-crds.yaml
$K wait --for=condition=established --timeout=300s crd/installations.operator.tigera.io

$K apply --server-side \
  -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/tigera-operator.yaml
$K -n tigera-operator rollout status deploy/tigera-operator --timeout=300s

cat > calico-installation.yaml <<'YAML'
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - name: default-ipv4-ippool
      blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
YAML
$K apply -f calico-installation.yaml

echo "esperando a que Calico quede disponible..."
LISTO=""
for _ in $(seq 1 45); do
  LISTO=$($K get tigerastatus calico -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || true)
  [ "$LISTO" = "True" ] && break
  sleep 10
done
if [ "$LISTO" != "True" ]; then
  echo "ERROR SUSTRATO-SIN-CNI: Calico nunca quedo disponible en este cluster."
  echo "Sin un CNI que aplique NetworkPolicy, el Paso 3 no probaria nada y los Pods"
  echo "no consiguen direccion IP. Revise: \$K get tigerastatus; \$K -n calico-system get pods"
  echo "NO continue con el laboratorio hasta que esto quede en True."
  exit 1
fi
$K wait --for=condition=Ready nodes --all --timeout=300s

echo "instalando ingress-nginx controller-v1.15.1 (ultima version del proyecto, ya retirado)"
$K apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml
$K wait --namespace ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=300s

for ns in el-barrio el-conjunto el-edificio; do
  $K create namespace "$ns"
done

cat > directorio-viejo.b64 <<'B64'
YXBpVmVyc2lvbjogdjEKa2luZDogU2VydmljZQptZXRhZGF0YToKICBuYW1lOiBkaXJlY3Rvcmlv
LXZpZWpvCiAgbmFtZXNwYWNlOiBlbC1iYXJyaW8Kc3BlYzoKICB0eXBlOiBDbHVzdGVySVAKICBz
ZWxlY3RvcjoKICAgIGFwcDogZG9uYS1yb3NhCiAgICBjYXNhOiB2ZXJkZQogIHBvcnRzOgogIC0g
bmFtZTogaHR0cAogICAgcG9ydDogODAKICAgIHRhcmdldFBvcnQ6IDgwCiAgICBwcm90b2NvbDog
VENQCg==
B64
base64 -d directorio-viejo.b64 | $K apply -f -

echo "espacio de trabajo listo en ~/cka-comico-lab/p03"
echo "kubeconfig privado: ~/cka-comico-lab/p03/kubeconfig (su ~/.kube/config no fue tocado)"
