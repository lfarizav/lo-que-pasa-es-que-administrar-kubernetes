#!/usr/bin/env bash
# lab-part-05 step 3 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
W="$HOME/cka-comico-lab/p05"; K="kubectl --kubeconfig $W/kubeconfig"; R="$W/03-respuesta.txt"
test -f "$R" || exit 1
grep -qxF "EVENTO=FailedScheduling" "$R" || exit 1
CPUV=$($K get node cka-comico-p05-worker -o jsonpath='{.status.allocatable.cpu}' 2>/dev/null)
MEMV=$($K get node cka-comico-p05-worker -o jsonpath='{.status.allocatable.memory}' 2>/dev/null)
test -n "$CPUV" || exit 1
test -n "$MEMV" || exit 1
grep -qxF "CPU_ASIGNABLE=$CPUV" "$R" || exit 1
grep -qxF "MEMORIA_ASIGNABLE=$MEMV" "$R" || exit 1
test "$($K -n la-bodega get deploy arroz -o jsonpath='{.spec.replicas}' 2>/dev/null)" = "1" || exit 1
test "$($K -n la-bodega get deploy arroz -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "1" || exit 1
RC=$($K -n la-bodega get deploy arroz -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
RM=$($K -n la-bodega get deploy arroz -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
test -n "$RC" || exit 1
test -n "$RM" || exit 1
POD=$($K -n la-bodega get pod -l app=arroz --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
test -n "$POD" || exit 1
NODO=$($K -n la-bodega get pod "$POD" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
AC=$($K get node "$NODO" -o jsonpath='{.status.allocatable.cpu}' 2>/dev/null)
AM=$($K get node "$NODO" -o jsonpath='{.status.allocatable.memory}' 2>/dev/null)
python3 - "$RC" "$RM" "$AC" "$AM" <<'PY' || exit 1
import sys
SUF = {"": 1, "m": 0.001, "k": 1e3, "M": 1e6, "G": 1e9, "T": 1e12,
       "Ki": 2 ** 10, "Mi": 2 ** 20, "Gi": 2 ** 30, "Ti": 2 ** 40}
def q(s):
    s = s.strip()
    for suf in ("Ki", "Mi", "Gi", "Ti", "m", "k", "M", "G", "T"):
        if s.endswith(suf):
            return float(s[:-len(suf)]) * SUF[suf]
    return float(s)
rc, rm, ac, am = [q(x) for x in sys.argv[1:5]]
if not (0.1 <= rc <= ac):
    sys.exit(1)
if not (64 * 2 ** 20 <= rm <= am):
    sys.exit(1)
sys.exit(0)
PY
echo ok
