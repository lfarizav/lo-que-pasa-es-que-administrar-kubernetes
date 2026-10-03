#!/usr/bin/env bash
# lab-part-05 step 4 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
W="$HOME/cka-comico-lab/p05"; K="kubectl --kubeconfig $W/kubeconfig"; R="$W/04-respuesta.txt"
CURL="curlimages/curl@sha256:d94d07ba9e7d6de898b6d96c1a072f6f8266c687af78a74f380087a0addf5d17"
URL="http://porteria.el-barrio.svc.cluster.local"
# El Pod de calificacion se borra a la fuerza y sin periodo de gracia, no
# solo se manda a borrar: si quedara en Terminating, la siguiente corrida de
# esta misma comprobacion chocaria contra un nombre ya existente y fallaria
# un ejercicio que estaba bien. La comprobacion se puede repetir las veces
# que usted quiera.
limpiar() { $K -n el-barrio delete pod intruso-calificacion --ignore-not-found --force --grace-period=0 >/dev/null 2>&1; }
test -f "$R" || exit 1
grep -qxF "TARGETPORT_MALO=8080" "$R" || exit 1
grep -qxF "TARGETPORT_BUENO=80" "$R" || exit 1
grep -qxF "POLITICA_CULPABLE=solo-los-de-la-casa" "$R" || exit 1
test "$($K -n el-barrio get svc porteria -o jsonpath='{.spec.selector.app}' 2>/dev/null)" = "portero" || exit 1
test "$($K -n el-barrio get deploy portero -o jsonpath='{.spec.replicas}' 2>/dev/null)" = "2" || exit 1
test "$($K -n el-barrio get deploy portero -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "2" || exit 1
EP=$($K -n el-barrio get endpointslices -l kubernetes.io/service-name=porteria -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"\n"}{end}' 2>/dev/null | sort -u)
PIP=$($K -n el-barrio get pod -l app=portero --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' 2>/dev/null | sort -u)
test "$(echo "$EP" | grep -c .)" -ge 2 || exit 1
for a in $EP; do echo "$PIP" | grep -qxF "$a" || exit 1; done
$K -n el-barrio get networkpolicy solo-los-de-la-casa >/dev/null 2>&1 || exit 1
test "$($K -n el-barrio get networkpolicy solo-los-de-la-casa -o jsonpath='{.spec.podSelector.matchLabels.app}' 2>/dev/null)" = "portero" || exit 1
$K -n el-barrio get networkpolicy solo-los-de-la-casa -o jsonpath='{.spec.policyTypes[*]}' 2>/dev/null | grep -qw Ingress || exit 1
$K -n el-barrio exec visitante -- curl -sS -o /dev/null -w '%{http_code}' --max-time 8 "$URL" 2>/dev/null | grep -qx 200 || exit 1
limpiar
sleep 2
$K -n el-barrio run intruso-calificacion --image="$CURL" --restart=Never -l app=intruso-calificacion \
  --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"cka-comico-p05-worker"}}}' \
  --command -- sleep 180 >/dev/null 2>&1 || { limpiar; exit 1; }
$K -n el-barrio wait --for=condition=Ready pod/intruso-calificacion --timeout=180s >/dev/null 2>&1 || { limpiar; exit 1; }
if $K -n el-barrio exec intruso-calificacion -- curl -sS -o /dev/null --max-time 8 "$URL" >/dev/null 2>&1; then
  limpiar
  exit 1
fi
limpiar
echo ok
