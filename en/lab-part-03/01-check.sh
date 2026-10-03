#!/usr/bin/env bash
# lab-part-03 step 1 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/cka-comico-lab/p03"
K="kubectl --kubeconfig $D/kubeconfig"
JP_LISTOS='{range .items[*]}{range .endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}{end}'
test -f "$D/01-respuesta.txt" || exit 1
test "$($K -n el-barrio get deploy dona-rosa -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "2" || exit 1
$K -n el-barrio get deploy dona-rosa -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null | grep -qx dona-rosa || exit 1
$K -n el-barrio get deploy dona-rosa -o jsonpath='{.spec.template.metadata.labels.casa}' 2>/dev/null | grep -qx azul || exit 1
IPS_REALES=$($K -n el-barrio get pods -l app=dona-rosa,casa=azul -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.status.podIP}{"\n"}{end}' 2>/dev/null | sort | tr '\n' ' ')
test "$(echo $IPS_REALES | wc -w)" -eq 2 || exit 1
for SVC in tienda-de-la-esquina directorio-viejo; do
  $K -n el-barrio get svc "$SVC" -o jsonpath='{.spec.selector.app}' 2>/dev/null | grep -qx dona-rosa || exit 1
  $K -n el-barrio get endpointslices -l "kubernetes.io/service-name=$SVC" -o jsonpath='{.items[0].metadata.labels.endpointslice\.kubernetes\.io/managed-by}' 2>/dev/null | grep -qx 'endpointslice-controller.k8s.io' || exit 1
  DIRS=$($K -n el-barrio get endpointslices -l "kubernetes.io/service-name=$SVC" -o jsonpath="$JP_LISTOS" 2>/dev/null | sort | tr '\n' ' ')
  test "$DIRS" = "$IPS_REALES" || exit 1
done
CLAVE=$(grep -oP '(?<=SELECTOR_ARREGLADO=)[^=]+(?==)' "$D/01-respuesta.txt")
VALOR=$(grep -oP '(?<=SELECTOR_ARREGLADO=)[^=]+=\K.*' "$D/01-respuesta.txt")
test -n "$CLAVE" || exit 1
test -n "$VALOR" || exit 1
$K -n el-barrio get svc directorio-viejo -o jsonpath="{.spec.selector.$CLAVE}" 2>/dev/null | grep -qx "$VALOR" || exit 1
$K -n el-barrio get deploy dona-rosa -o jsonpath="{.spec.template.metadata.labels.$CLAVE}" 2>/dev/null | grep -qx "$VALOR" || exit 1
N=$($K -n el-barrio get endpointslices -l kubernetes.io/service-name=tienda-de-la-esquina -o jsonpath="$JP_LISTOS" 2>/dev/null | grep -c .)
grep -qxF "ENDPOINTS_TIENDA=$N" "$D/01-respuesta.txt" || exit 1
echo ok
