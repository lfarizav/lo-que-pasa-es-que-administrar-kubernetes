#!/usr/bin/env bash
# lab-part-03 step 2 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/cka-comico-lab/p03"
K="kubectl --kubeconfig $D/kubeconfig"
JP_LISTOS='{range .items[*]}{range .endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}{end}'
test -f "$D/02-respuesta.txt" || exit 1
$K -n el-barrio get pod el-visitante -o jsonpath='{.status.phase}' 2>/dev/null | grep -qx Running || exit 1
FQDN=$(grep -oP '(?<=NOMBRE_COMPLETO=).*' "$D/02-respuesta.txt")
test "$FQDN" = "tienda-de-la-esquina.el-barrio.svc.cluster.local" || exit 1
CIP=$($K -n el-barrio get svc tienda-de-la-esquina -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
test -n "$CIP" || exit 1
test "$CIP" != "None" || exit 1
RESUELTA=$($K -n el-barrio exec el-visitante -- nslookup "$FQDN" 2>/dev/null | tr -d '\r' | awk -F'[ \t]+' '/^Address:/{print $2}' | grep -v '#' | head -1)
test "$RESUELTA" = "$CIP" || exit 1
grep -qxF "CLUSTERIP_POR_DNS=$CIP" "$D/02-respuesta.txt" || exit 1
$K -n el-barrio get svc las-casas-mismas -o jsonpath='{.spec.clusterIP}' 2>/dev/null | grep -qx None || exit 1
$K -n el-barrio get svc las-casas-mismas -o jsonpath='{.spec.selector.app}' 2>/dev/null | grep -qx dona-rosa || exit 1
LISTOS=$($K -n el-barrio get endpointslices -l kubernetes.io/service-name=las-casas-mismas -o jsonpath="$JP_LISTOS" 2>/dev/null | grep -c .)
test "$LISTOS" -ge 2 || exit 1
REGISTROS=$($K -n el-barrio exec el-visitante -- nslookup "las-casas-mismas.el-barrio.svc.cluster.local" 2>/dev/null | tr -d '\r' | awk -F'[ \t]+' '/^Address:/{print $2}' | grep -v '#' | grep -c .)
test "$REGISTROS" -eq "$LISTOS" || exit 1
grep -qxF "REGISTROS_HEADLESS=$REGISTROS" "$D/02-respuesta.txt" || exit 1
echo ok
