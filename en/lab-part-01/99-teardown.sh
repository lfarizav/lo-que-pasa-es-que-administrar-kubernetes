#!/usr/bin/env bash
# lab-part-01 - teardown
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

kind delete cluster --name cka-comico-p01 \
  --kubeconfig ~/cka-comico-lab/p01/kubeconfig

rm -rf ~/cka-comico-lab/p01

echo "cluster cka-comico-p01 eliminado y workspace borrado"
echo "sus otros clusteres de kind siguen intactos:"
kind get clusters
