#!/usr/bin/env bash
# lab-part-01 - setup
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

mkdir -p ~/cka-comico-lab/p01
cd ~/cka-comico-lab/p01

for herramienta in kind kubectl docker jq openssl; do
  command -v "$herramienta" >/dev/null 2>&1 || echo "FALTA: $herramienta - instalelo antes de continuar."
done

kind create cluster --name cka-comico-p01 \
  --kubeconfig ~/cka-comico-lab/p01/kubeconfig \
  --image kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5

KC="$HOME/cka-comico-lab/p01/kubeconfig"

kubectl --kubeconfig "$KC" --context kind-cka-comico-p01 \
  wait --for=condition=Ready nodes --all --timeout=180s

kubectl --kubeconfig "$KC" --context kind-cka-comico-p01 create namespace la-casa
kubectl --kubeconfig "$KC" --context kind-cka-comico-p01 create namespace la-finca-vecina

PAUSA=registry.k8s.io/pause:3.10@sha256:ee6521f290b2168b6e0935a181d4cff9be1ac3f505666ef0e3c98fae8199917a

kubectl --kubeconfig "$KC" --context kind-cka-comico-p01 -n la-casa \
  run la-alarma --image="$PAUSA" --restart=Never
kubectl --kubeconfig "$KC" --context kind-cka-comico-p01 -n la-casa \
  wait --for=condition=Ready pod/la-alarma --timeout=120s

kubectl config get-contexts

echo "espacio de trabajo listo en ~/cka-comico-lab/p01"
echo "si la linea de arriba menciona cka-comico-p01, el aislamiento fallo: revise el --kubeconfig"
