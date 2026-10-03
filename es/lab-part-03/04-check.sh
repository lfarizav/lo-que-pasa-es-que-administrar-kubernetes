#!/usr/bin/env bash
# lab-part-03 step 4 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/cka-comico-lab/p03"
K="kubectl --kubeconfig $D/kubeconfig"
JP_LISTOS='{range .items[*]}{range .endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}{end}'
test -f "$D/04-respuesta.txt" || exit 1
CLASE=$($K -n el-edificio get ingress citofono -o jsonpath='{.spec.ingressClassName}' 2>/dev/null)
test "$CLASE" = "nginx" || exit 1
$K get ingressclass "$CLASE" -o jsonpath='{.spec.controller}' 2>/dev/null | grep -qx 'k8s.io/ingress-nginx' || exit 1
$K -n ingress-nginx get deploy ingress-nginx-controller -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -qE '^[1-9][0-9]*$' || exit 1
HOST=$($K -n el-edificio get ingress citofono -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
test -n "$HOST" || exit 1
B101=$($K -n el-edificio get ingress citofono -o jsonpath='{.spec.rules[0].http.paths[?(@.path=="/101")].backend.service.name}' 2>/dev/null)
B302=$($K -n el-edificio get ingress citofono -o jsonpath='{.spec.rules[0].http.paths[?(@.path=="/302")].backend.service.name}' 2>/dev/null)
test "$B101" = "apartamento-101" || exit 1
test "$B302" = "apartamento-302" || exit 1
for SVC in "$B101" "$B302"; do
  $K -n el-edificio get endpointslices -l "kubernetes.io/service-name=$SVC" -o jsonpath="$JP_LISTOS" 2>/dev/null | grep -q . || exit 1
done
R101=""
R302=""
for _ in $(seq 1 30); do
  R101=$(curl -sS --max-time 15 -H "Host: $HOST" "http://localhost:8080/101/" 2>/dev/null)
  R302=$(curl -sS --max-time 15 -H "Host: $HOST" "http://localhost:8080/302/" 2>/dev/null)
  echo "$R101" | grep -qF "APARTAMENTO 101" && echo "$R302" | grep -qF "APARTAMENTO 302" && break
  sleep 2
done
echo "$R101" | grep -qF "APARTAMENTO 101" || exit 1
echo "$R302" | grep -qF "APARTAMENTO 302" || exit 1
grep -qxF "CLASE_DEL_CITOFONO=$CLASE" "$D/04-respuesta.txt" || exit 1
grep -qxF "HOST_DEL_CITOFONO=$HOST" "$D/04-respuesta.txt" || exit 1
echo ok
