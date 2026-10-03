#!/usr/bin/env bash
# lab-part-05 step 2 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
W="$HOME/cka-comico-lab/p05"; K="kubectl --kubeconfig $W/kubeconfig"; R="$W/02-respuesta.txt"
test -f "$R" || exit 1
grep -qxF "NODO_CAIDO=cka-comico-p05-worker2" "$R" || exit 1
grep -qxF "RAZON_CONDICION=NodeStatusUnknown" "$R" || exit 1
grep -qxF "SERVICIO_CULPABLE=kubelet" "$R" || exit 1
test "$($K get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep -c .)" -eq 3 || exit 1
test "$($K get nodes -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c '^True$')" -eq 3 || exit 1
for n in cka-comico-p05-control-plane cka-comico-p05-worker cka-comico-p05-worker2; do
  docker exec "$n" systemctl is-active kubelet 2>/dev/null | grep -qx active || exit 1
done
test -z "$($K get node cka-comico-p05-worker2 -o jsonpath='{.spec.unschedulable}' 2>/dev/null)" || exit 1
echo ok
