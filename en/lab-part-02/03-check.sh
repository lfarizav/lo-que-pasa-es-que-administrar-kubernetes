#!/usr/bin/env bash
# lab-part-02 step 3 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/cka-comico-lab/p02"
K="kubectl --kubeconfig $D/kubeconfig"
NS=cuchara-de-oro
IMG="nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236"
a_bytes() {
  case "$1" in
    *Ki) echo $(( ${1%Ki} * 1024 )) ;;
    *Mi) echo $(( ${1%Mi} * 1048576 )) ;;
    *Gi) echo $(( ${1%Gi} * 1073741824 )) ;;
    *Ti) echo $(( ${1%Ti} * 1099511627776 )) ;;
    *k|*K) echo $(( ${1%[kK]} * 1000 )) ;;
    *M) echo $(( ${1%M} * 1000000 )) ;;
    *G) echo $(( ${1%G} * 1000000000 )) ;;
    *T) echo $(( ${1%T} * 1000000000000 )) ;;
    *[0-9]) echo "$1" ;;
    *) echo 0 ;;
  esac
}
test -f "$D/03-respuesta.txt" || exit 1
DESEADAS=$($K -n $NS get deployment pedido-gigante -o jsonpath='{.spec.replicas}' 2>/dev/null)
LISTAS=$($K -n $NS get deployment pedido-gigante -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
test -n "$LISTAS" || exit 1
test "$LISTAS" = "$DESEADAS" || exit 1
test "$LISTAS" -ge 1 || exit 1
FASES=$($K -n $NS get pods -l app=pedido-gigante -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | sort -u)
test "$FASES" = "Running" || exit 1
PEDIDO=$($K -n $NS get deployment pedido-gigante -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
test -n "$PEDIDO" || exit 1
test "$(a_bytes "$PEDIDO")" -le 268435456 || exit 1
TECHO_KI=$($K get nodes -o jsonpath='{range .items[*]}{.status.allocatable.memory}{"\n"}{end}' 2>/dev/null | sed 's/Ki$//' | sort -n | tail -1)
test -n "$TECHO_KI" || exit 1
INICIAL=$(grep -oP "(?<=MEMORIA_PEDIDA_INICIAL=).*" "$D/03-respuesta.txt")
test -n "$INICIAL" || exit 1
test "$(a_bytes "$INICIAL")" -gt $(( TECHO_KI * 1024 )) || exit 1
$K -n $NS delete deployment sonda-de-memoria --ignore-not-found >/dev/null 2>&1
cat <<YAML | $K apply -f - >/dev/null 2>&1 || exit 1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonda-de-memoria
  namespace: $NS
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sonda-de-memoria
  template:
    metadata:
      labels:
        app: sonda-de-memoria
    spec:
      containers:
      - name: nginx
        image: $IMG
        resources:
          requests:
            cpu: 10m
            memory: "$(( TECHO_KI * 4 ))Ki"
YAML
MENSAJE=""
RAZON=""
for _ in $(seq 1 20); do
  POD=$($K -n $NS get pods -l app=sonda-de-memoria -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$POD" ]; then
    MENSAJE=$($K -n $NS get pod "$POD" -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")].message}' 2>/dev/null)
    RAZON=$($K -n $NS get events --field-selector involvedObject.name="$POD" -o jsonpath='{range .items[?(@.reason=="FailedScheduling")]}{.reason}{"\n"}{end}' 2>/dev/null | head -1)
  fi
  test -n "$MENSAJE" -a -n "$RAZON" && break
  sleep 3
done
FASE=$($K -n $NS get pods -l app=sonda-de-memoria -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
$K -n $NS delete deployment sonda-de-memoria --ignore-not-found --wait=false >/dev/null 2>&1
test "$FASE" = "Pending" || exit 1
test -n "$RAZON" || exit 1
grep -qxF "RAZON_DEL_EVENTO=$RAZON" "$D/03-respuesta.txt" || exit 1
MOTIVO=$(grep -oP "(?<=MOTIVO_EXACTO=).*" "$D/03-respuesta.txt")
test -n "$MOTIVO" || exit 1
test "${#MOTIVO}" -ge 10 || exit 1
echo "$MENSAJE" | grep -qF "$MOTIVO" || exit 1
echo ok
