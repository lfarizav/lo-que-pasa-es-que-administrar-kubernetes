#!/usr/bin/env bash
# lab-part-04 step 4 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
KC="$HOME/cka-comico-lab/p04/kubeconfig"
D="$HOME/cka-comico-lab/p04"
test -f "$D/04-respuesta.txt" || exit 1
SC_DEF=$(kubectl --kubeconfig "$KC" get sc -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | head -1)
test -n "$SC_DEF" || exit 1
PROV=$(kubectl --kubeconfig "$KC" get sc "$SC_DEF" -o jsonpath='{.provisioner}' 2>/dev/null)
SC_POL=$(kubectl --kubeconfig "$KC" get sc "$SC_DEF" -o jsonpath='{.reclaimPolicy}' 2>/dev/null)
test "$SC_POL" = "Delete" || exit 1
kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc lote-de-rescate >/dev/null 2>&1 && exit 1
PVR=$(kubectl --kubeconfig "$KC" get pv -o jsonpath='{range .items[?(@.spec.claimRef.name=="lote-de-rescate")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | head -1)
test -n "$PVR" || exit 1
NSREF=$(kubectl --kubeconfig "$KC" get pv "$PVR" -o jsonpath='{.spec.claimRef.namespace}' 2>/dev/null)
test "$NSREF" = "cuchara-de-oro" || exit 1
FASE=$(kubectl --kubeconfig "$KC" get pv "$PVR" -o jsonpath='{.status.phase}' 2>/dev/null)
test "$FASE" = "Released" || exit 1
POL=$(kubectl --kubeconfig "$KC" get pv "$PVR" -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' 2>/dev/null)
test "$POL" = "Retain" || exit 1
POR=$(kubectl --kubeconfig "$KC" get pv "$PVR" -o jsonpath='{.metadata.annotations.pv\.kubernetes\.io/provisioned-by}' 2>/dev/null)
test "$POR" = "$PROV" || exit 1
SCPV=$(kubectl --kubeconfig "$KC" get pv "$PVR" -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
test "$SCPV" = "$SC_DEF" || exit 1
CAP=$(kubectl --kubeconfig "$KC" get pv "$PVR" -o jsonpath='{.spec.capacity.storage}' 2>/dev/null)
test "$CAP" = "128Mi" || exit 1
grep -qxF "PV_RESCATADO=$PVR" "$D/04-respuesta.txt" || exit 1
grep -qxF "POLITICA_ANTES=$SC_POL" "$D/04-respuesta.txt" || exit 1
grep -qxF "POLITICA_DESPUES=$POL" "$D/04-respuesta.txt" || exit 1
grep -qxF "FASE_FINAL=$FASE" "$D/04-respuesta.txt" || exit 1
echo ok
