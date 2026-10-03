#!/usr/bin/env bash
# lab-part-02 - setup
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

mkdir -p ~/cka-comico-lab/p02
cd ~/cka-comico-lab/p02

for tool in kind kubectl docker; do
  command -v "$tool" >/dev/null 2>&1 || echo "FALTA: $tool - instalelo antes de continuar."
done

kind version
kubectl version --client

cat > ~/cka-comico-lab/p02/kind-p02.yaml <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cka-comico-p02
nodes:
- role: control-plane
  image: kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5
- role: worker
  image: kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5
- role: worker
  image: kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5
YAML

kind create cluster --name cka-comico-p02 \
  --kubeconfig ~/cka-comico-lab/p02/kubeconfig \
  --config ~/cka-comico-lab/p02/kind-p02.yaml

kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig \
  wait --for=condition=Ready nodes --all --timeout=300s

kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig create namespace cuchara-de-oro

kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig get nodes -o wide

echo "espacio de trabajo listo en ~/cka-comico-lab/p02"
echo "recuerde: TODO comando de este laboratorio lleva --kubeconfig ~/cka-comico-lab/p02/kubeconfig"
