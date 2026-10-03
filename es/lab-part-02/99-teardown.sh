#!/usr/bin/env bash
# lab-part-02 - teardown
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

kind delete cluster --name cka-comico-p02
rm -rf ~/cka-comico-lab/p02
echo "cluster cka-comico-p02 eliminado y workspace borrado"
echo "sus otros clusters y su ~/.kube/config quedaron intactos: este laboratorio nunca los tocó"
