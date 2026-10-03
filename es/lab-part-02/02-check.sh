#!/usr/bin/env bash
# lab-part-02 step 2 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/cka-comico-lab/p02"
K="kubectl --kubeconfig $D/kubeconfig"
NS=cuchara-de-oro
IMG="nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236"
test -f "$D/02-respuesta.txt" || exit 1
NODO=$(grep -oP "(?<=NODO_RESERVADO=).*" "$D/02-respuesta.txt")
test -n "$NODO" || exit 1
$K get node "$NODO" >/dev/null 2>&1 || exit 1
TAINTS=$($K get node "$NODO" -o jsonpath='{range .spec.taints[*]}{.key}{"="}{.value}{":"}{.effect}{"\n"}{end}' 2>/dev/null)
echo "$TAINTS" | grep -qxF "dedicated=cuchara-de-oro:NoSchedule" || exit 1
LLAVE=$(grep -oP "(?<=LLAVE_DEL_TAINT=).*" "$D/02-respuesta.txt")
EFECTO=$(grep -oP "(?<=EFECTO_DEL_TAINT=).*" "$D/02-respuesta.txt")
test "$LLAVE" = "dedicated" || exit 1
test "$EFECTO" = "NoSchedule" || exit 1
DESEADAS=$($K -n $NS get deployment turno-de-la-noche -o jsonpath='{.spec.replicas}' 2>/dev/null)
LISTAS=$($K -n $NS get deployment turno-de-la-noche -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
test -n "$LISTAS" || exit 1
test "$LISTAS" = "$DESEADAS" || exit 1
test "$LISTAS" -ge 2 || exit 1
NODOS=$($K -n $NS get pods -l app=turno-de-la-noche --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null | sort -u)
test "$NODOS" = "$NODO" || exit 1
TOLERA=0
while IFS='|' read -r TK TO TV TE; do
  test "$TK" = "$LLAVE" || continue
  test "$TE" = "$EFECTO" -o -z "$TE" || continue
  if [ "$TO" = "Exists" ] || [ "$TV" = "cuchara-de-oro" ]; then TOLERA=1; fi
done <<EOF
$($K -n $NS get deployment turno-de-la-noche -o jsonpath='{range .spec.template.spec.tolerations[*]}{.key}{"|"}{.operator}{"|"}{.value}{"|"}{.effect}{"\n"}{end}' 2>/dev/null)
EOF
test "$TOLERA" = "1" || exit 1
$K -n $NS delete deployment sonda-sin-brazalete --ignore-not-found >/dev/null 2>&1
cat <<YAML | $K apply -f - >/dev/null 2>&1 || exit 1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonda-sin-brazalete
  namespace: $NS
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sonda-sin-brazalete
  template:
    metadata:
      labels:
        app: sonda-sin-brazalete
    spec:
      nodeSelector:
        kubernetes.io/hostname: $NODO
      containers:
      - name: nginx
        image: $IMG
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
YAML
MENSAJE=""
for _ in $(seq 1 20); do
  MENSAJE=$($K -n $NS get pods -l app=sonda-sin-brazalete -o jsonpath='{.items[0].status.conditions[?(@.type=="PodScheduled")].message}' 2>/dev/null)
  test -n "$MENSAJE" && break
  sleep 3
done
FASE=$($K -n $NS get pods -l app=sonda-sin-brazalete -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
$K -n $NS delete deployment sonda-sin-brazalete --ignore-not-found --wait=false >/dev/null 2>&1
test "$FASE" = "Pending" || exit 1
echo "$MENSAJE" | grep -qF "untolerated taint" || exit 1
echo ok
