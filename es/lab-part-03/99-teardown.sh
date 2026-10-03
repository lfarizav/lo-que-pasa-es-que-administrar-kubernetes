#!/usr/bin/env bash
# lab-part-03 - teardown
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

kind delete cluster --name cka-comico-p03
rm -rf ~/cka-comico-lab/p03
echo "cluster cka-comico-p03 eliminado y workspace borrado; ningun otro cluster fue tocado"
