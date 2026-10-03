#!/usr/bin/env bash
# lab-part-04 step 1 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
KC="$HOME/cka-comico-lab/p04/kubeconfig"
D="$HOME/cka-comico-lab/p04"
test -f "$D/01-respuesta.txt" || exit 1
FPV=$(kubectl --kubeconfig "$KC" get pv deposito-de-la-finca -o jsonpath='{.status.phase}' 2>/dev/null)
test "$FPV" = "Bound" || exit 1
FPVC=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc contrato-de-la-cocina -o jsonpath='{.status.phase}' 2>/dev/null)
test "$FPVC" = "Bound" || exit 1
REF=$(kubectl --kubeconfig "$KC" get pv deposito-de-la-finca -o jsonpath='{.spec.claimRef.namespace}/{.spec.claimRef.name}' 2>/dev/null)
test "$REF" = "cuchara-de-oro/contrato-de-la-cocina" || exit 1
VOL=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc contrato-de-la-cocina -o jsonpath='{.spec.volumeName}' 2>/dev/null)
test "$VOL" = "deposito-de-la-finca" || exit 1
SCPV=$(kubectl --kubeconfig "$KC" get pv deposito-de-la-finca -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
test -z "$SCPV" || exit 1
SCPVC=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc contrato-de-la-cocina -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
test -z "$SCPVC" || exit 1
POR=$(kubectl --kubeconfig "$KC" get pv deposito-de-la-finca -o jsonpath='{.metadata.annotations.pv\.kubernetes\.io/provisioned-by}' 2>/dev/null)
test -z "$POR" || exit 1
RUTA=$(kubectl --kubeconfig "$KC" get pv deposito-de-la-finca -o jsonpath='{.spec.hostPath.path}' 2>/dev/null)
test -n "$RUTA" || exit 1
CAP=$(kubectl --kubeconfig "$KC" get pv deposito-de-la-finca -o jsonpath='{.spec.capacity.storage}' 2>/dev/null)
test "$CAP" = "512Mi" || exit 1
PED=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc contrato-de-la-cocina -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
test "$PED" = "512Mi" || exit 1
MODOS=$(kubectl --kubeconfig "$KC" get pv deposito-de-la-finca -o jsonpath='{.spec.accessModes[*]}' 2>/dev/null)
test "$MODOS" = "ReadWriteOnce" || exit 1
TRABAJADOR=$(kubectl --kubeconfig "$KC" get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
ANCLA=$(kubectl --kubeconfig "$KC" get pv deposito-de-la-finca -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[*].matchExpressions[?(@.key=="kubernetes.io/hostname")].values[*]}' 2>/dev/null)
echo "$ANCLA" | grep -qw "$TRABAJADOR" || exit 1
grep -qxF "PV_DEL_CONTRATO=$VOL" "$D/01-respuesta.txt" || exit 1
grep -qxF "CLAIMREF_DEL_PV=$REF" "$D/01-respuesta.txt" || exit 1
echo ok
