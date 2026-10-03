#!/usr/bin/env bash
# lab-part-04 step 2 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
KC="$HOME/cka-comico-lab/p04/kubeconfig"
D="$HOME/cka-comico-lab/p04"
test -f "$D/02-respuesta.txt" || exit 1
FASE=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pod despensero -o jsonpath='{.status.phase}' 2>/dev/null)
test "$FASE" = "Running" || exit 1
VOLNAME=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pod despensero -o jsonpath='{.spec.volumes[?(@.persistentVolumeClaim.claimName=="contrato-de-la-cocina")].name}' 2>/dev/null)
test -n "$VOLNAME" || exit 1
VACIOS=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pod despensero -o jsonpath='{.spec.volumes[*].emptyDir}' 2>/dev/null)
test -z "$VACIOS" || exit 1
RUTA=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pod despensero -o jsonpath='{.spec.containers[*].volumeMounts[?(@.name=="'"$VOLNAME"'")].mountPath}' 2>/dev/null)
test "$RUTA" = "/deposito" || exit 1
MARCA=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro exec despensero -- cat /deposito/marca.txt 2>/dev/null | tr -d '\r\n')
test -n "$MARCA" || exit 1
test "${#MARCA}" -ge 8 || exit 1
MTIME=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro exec despensero -- stat -c '%Y' /deposito/marca.txt 2>/dev/null | tr -d '\r\n')
echo "$MTIME" | grep -qE '^[0-9]+$' || exit 1
ARRANQUE=$(date -u -d "$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pod despensero -o jsonpath='{.status.startTime}' 2>/dev/null)" +%s 2>/dev/null)
echo "$ARRANQUE" | grep -qE '^[0-9]+$' || exit 1
test "$MTIME" -lt "$ARRANQUE" || exit 1
VOL=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pvc contrato-de-la-cocina -o jsonpath='{.spec.volumeName}' 2>/dev/null)
test "$VOL" = "deposito-de-la-finca" || exit 1
FPV=$(kubectl --kubeconfig "$KC" get pv deposito-de-la-finca -o jsonpath='{.status.phase}' 2>/dev/null)
test "$FPV" = "Bound" || exit 1
grep -qxF "MARCA=$MARCA" "$D/02-respuesta.txt" || exit 1
grep -qxF "VOLUMEN_DEL_POD=contrato-de-la-cocina" "$D/02-respuesta.txt" || exit 1
echo ok
