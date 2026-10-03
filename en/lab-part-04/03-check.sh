#!/usr/bin/env bash
# lab-part-04 step 3 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
KC="$HOME/cka-comico-lab/p04/kubeconfig"
D="$HOME/cka-comico-lab/p04"
test -f "$D/03-respuesta.txt" || exit 1
SC_DEF=$(kubectl --kubeconfig "$KC" get sc -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | head -1)
test -n "$SC_DEF" || exit 1
PROV=$(kubectl --kubeconfig "$KC" get sc "$SC_DEF" -o jsonpath='{.provisioner}' 2>/dev/null)
test -n "$PROV" || exit 1
MODO=$(kubectl --kubeconfig "$KC" get sc "$SC_DEF" -o jsonpath='{.volumeBindingMode}' 2>/dev/null)
test "$MODO" = "WaitForFirstConsumer" || exit 1
kubectl --kubeconfig "$KC" -n cuchara-de-oro delete pvc sonda-espera --ignore-not-found --wait=true >/dev/null 2>&1
kubectl --kubeconfig "$KC" apply -f - >/dev/null 2>&1 <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sonda-espera
  namespace: cuchara-de-oro
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 64Mi
YAML
sleep 20
SONDA_FASE=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc sonda-espera -o jsonpath='{.status.phase}' 2>/dev/null)
SONDA_VOL=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc sonda-espera -o jsonpath='{.spec.volumeName}' 2>/dev/null)
kubectl --kubeconfig "$KC" -n cuchara-de-oro delete pvc sonda-espera --ignore-not-found --wait=false >/dev/null 2>&1
test "$SONDA_FASE" = "Pending" || exit 1
test -z "$SONDA_VOL" || exit 1
FASE=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc lote-por-encargo -o jsonpath='{.status.phase}' 2>/dev/null)
test "$FASE" = "Bound" || exit 1
PVNAME=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc lote-por-encargo -o jsonpath='{.spec.volumeName}' 2>/dev/null)
test -n "$PVNAME" || exit 1
POR=$(kubectl --kubeconfig "$KC" get pv "$PVNAME" -o jsonpath='{.metadata.annotations.pv\.kubernetes\.io/provisioned-by}' 2>/dev/null)
test "$POR" = "$PROV" || exit 1
SCPV=$(kubectl --kubeconfig "$KC" get pv "$PVNAME" -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
test "$SCPV" = "$SC_DEF" || exit 1
PODFASE=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pod constructor -o jsonpath='{.status.phase}' 2>/dev/null)
test "$PODFASE" = "Running" || exit 1
PODVOL=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pod constructor -o jsonpath='{.spec.volumes[?(@.persistentVolumeClaim.claimName=="lote-por-encargo")].name}' 2>/dev/null)
test -n "$PODVOL" || exit 1
grep -qxF "APROVISIONADOR=$PROV" "$D/03-respuesta.txt" || exit 1
grep -qxF "MODO_DE_ENLACE=$MODO" "$D/03-respuesta.txt" || exit 1
grep -qxF "FASE_SIN_CONSUMIDOR=Pending" "$D/03-respuesta.txt" || exit 1
echo ok
