#!/usr/bin/env bash
# lab-part-05 - teardown
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

kind delete cluster --name cka-comico-p05 \
  --kubeconfig "$HOME/cka-comico-lab/p05/kubeconfig" 2>/dev/null
rm -rf "$HOME/cka-comico-lab/p05"
echo "cluster cka-comico-p05 eliminado y workspace ~/cka-comico-lab/p05 borrado"
echo "ningun otro cluster, contexto ni contenedor de la maquina fue tocado"
