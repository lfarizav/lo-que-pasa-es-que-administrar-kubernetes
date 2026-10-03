#!/usr/bin/env bash
# lab-part-04 - teardown
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

kind delete cluster --name cka-comico-p04
rm -rf "$HOME/cka-comico-lab/p04"
echo "cluster cka-comico-p04 eliminado y workspace borrado; ningun otro cluster de kind fue tocado y su kubeconfig de siempre nunca se modifico"
