#!/usr/bin/env bash
# lab-part-05 - setup
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

set -e
W="$HOME/cka-comico-lab/p05"
KC="$W/kubeconfig"
K="kubectl --kubeconfig $KC"
NODO="kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5"
NGINX="nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de"
CURL="curlimages/curl@sha256:d94d07ba9e7d6de898b6d96c1a072f6f8266c687af78a74f380087a0addf5d17"

for t in kind kubectl docker base64 python3; do
  command -v "$t" >/dev/null 2>&1 || { echo "FALTA: $t - instalelo antes de empezar."; exit 1; }
done

mkdir -p "$W"
cat > "$W/kind.yaml" <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
YAML

# El kubeconfig es PRIVADO desde el primer comando: nunca se toca el
# ~/.kube/config de la maquina, y ningun otro cluster corre riesgo.
kind delete cluster --name cka-comico-p05 --kubeconfig "$KC" >/dev/null 2>&1 || true
kind create cluster --name cka-comico-p05 --kubeconfig "$KC" \
  --image "$NODO" --config "$W/kind.yaml" --wait 300s
chmod 600 "$KC"
$K wait --for=condition=Ready nodes --all --timeout=300s

# ---------------------------------------------------------- sonda del CNI
# El Paso 4 depende de que el CNI APLIQUE NetworkPolicy de verdad. Un objeto
# puede ser aceptado por el API server y no ser aplicado por nadie, asi que
# esto se mide y nunca se supone: linea base, se pone el control, se vuelve
# a medir. Si el control no muerde, el montaje se detiene con un error con
# nombre en vez de entregarle un Paso 4 que seria pura decoracion.
$K create namespace sonda-cni >/dev/null
$K -n sonda-cni run sonda-web --image="$NGINX" --port=80 -l app=sonda-web >/dev/null
$K -n sonda-cni run sonda-cli --image="$CURL" --restart=Never -l app=sonda-cli \
  --command -- sleep 600 >/dev/null
$K -n sonda-cni wait --for=condition=Ready pod/sonda-web pod/sonda-cli --timeout=300s
SIP=$($K -n sonda-cni get pod sonda-web -o jsonpath='{.status.podIP}')
$K -n sonda-cni exec sonda-cli -- curl -sS -o /dev/null --max-time 8 "http://$SIP" \
  || { echo "ERROR SONDA-CNI-LINEA-BASE: un Pod no alcanza a otro ni siquiera sin politicas; el cluster esta roto antes de empezar."; exit 1; }
cat <<'YAML' | $K -n sonda-cni apply -f - >/dev/null
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sonda-niega-todo
spec:
  podSelector:
    matchLabels:
      app: sonda-web
  policyTypes:
  - Ingress
YAML
sleep 10
if $K -n sonda-cni exec sonda-cli -- curl -sS -o /dev/null --max-time 8 "http://$SIP" 2>/dev/null; then
  echo "ERROR SONDA-CNI-NO-APLICA: este CNI acepta objetos NetworkPolicy y no los aplica."
  echo "El Paso 4 de este laboratorio seria decoracion, asi que el montaje se detiene aqui."
  $K delete namespace sonda-cni --wait=false >/dev/null 2>&1 || true
  exit 1
fi
$K delete namespace sonda-cni --wait=false >/dev/null
echo "sonda-cni: el CNI aplica NetworkPolicy de verdad; el Paso 4 tiene piso."

# ------------------------------------------------------- las cuatro averias
# Las averias llegan codificadas en base64 A PROPOSITO. Eso no es
# criptografia y no pretende serlo: es una venda de cortesia, para que usted
# no lea la falla en el mismo script que la aplica. La respuesta completa de
# cada paso esta en el campo cmd de ese paso. La averia es identica para todo
# el mundo en todas las corridas.
mkdir -p "$W/averias"
printf '%s' 'YXBpVmVyc2lvbjogdjEKa2luZDogTmFtZXNwYWNlCm1ldGFkYXRhOgogIG5hbWU6IGN1Y2hhcmEtZGUtb3JvCi0tLQphcGlWZXJzaW9uOiB2MQpraW5kOiBDb25maWdNYXAKbWV0YWRhdGE6CiAgbmFtZTogbGEtY2FydGEKICBuYW1lc3BhY2U6IGN1Y2hhcmEtZGUtb3JvCmRhdGE6CiAgUFJFQ0lPX0FMTVVFUlpPOiAiMTUwMDAiCiAgU09QQV9ERUxfRElBOiAic2FuY29jaG8iCi0tLQphcGlWZXJzaW9uOiBhcHBzL3YxCmtpbmQ6IERlcGxveW1lbnQKbWV0YWRhdGE6CiAgbmFtZTogc2FuY29jaG8KICBuYW1lc3BhY2U6IGN1Y2hhcmEtZGUtb3JvCiAgbGFiZWxzOgogICAgYXBwOiBzYW5jb2NobwpzcGVjOgogIHJlcGxpY2FzOiAyCiAgc2VsZWN0b3I6CiAgICBtYXRjaExhYmVsczoKICAgICAgYXBwOiBzYW5jb2NobwogIHRlbXBsYXRlOgogICAgbWV0YWRhdGE6CiAgICAgIGxhYmVsczoKICAgICAgICBhcHA6IHNhbmNvY2hvCiAgICBzcGVjOgogICAgICBub2RlU2VsZWN0b3I6CiAgICAgICAga3ViZXJuZXRlcy5pby9ob3N0bmFtZTogY2thLWNvbWljby1wMDUtd29ya2VyCiAgICAgIGNvbnRhaW5lcnM6CiAgICAgIC0gbmFtZTogb2xsYQogICAgICAgIGltYWdlOiBuZ2lueDoxLjI5LWFscGluaXRhCiAgICAgICAgcG9ydHM6CiAgICAgICAgLSBjb250YWluZXJQb3J0OiA4MAotLS0KYXBpVmVyc2lvbjogYXBwcy92MQpraW5kOiBEZXBsb3ltZW50Cm1ldGFkYXRhOgogIG5hbWU6IGJhbmRlamEKICBuYW1lc3BhY2U6IGN1Y2hhcmEtZGUtb3JvCiAgbGFiZWxzOgogICAgYXBwOiBiYW5kZWphCnNwZWM6CiAgcmVwbGljYXM6IDIKICBzZWxlY3RvcjoKICAgIG1hdGNoTGFiZWxzOgogICAgICBhcHA6IGJhbmRlamEKICB0ZW1wbGF0ZToKICAgIG1ldGFkYXRhOgogICAgICBsYWJlbHM6CiAgICAgICAgYXBwOiBiYW5kZWphCiAgICBzcGVjOgogICAgICBub2RlU2VsZWN0b3I6CiAgICAgICAga3ViZXJuZXRlcy5pby9ob3N0bmFtZTogY2thLWNvbWljby1wMDUtd29ya2VyCiAgICAgIGNvbnRhaW5lcnM6CiAgICAgIC0gbmFtZTogcGxhdG8KICAgICAgICBpbWFnZTogbmdpbng6MS4yOS1hbHBpbmVAc2hhMjU2OjU2MTY4NzgyOTFhMmVlZDU5NGFlZThkYjRkYWRlNTg3OGNmN2VkY2I0NzVlNTkxOTM5MDRiMTk4ZDliODMwZGUKICAgICAgICBwb3J0czoKICAgICAgICAtIGNvbnRhaW5lclBvcnQ6IDgwCiAgICAgICAgZW52OgogICAgICAgIC0gbmFtZTogUFJFQ0lPX0FMTVVFUlpPCiAgICAgICAgICB2YWx1ZUZyb206CiAgICAgICAgICAgIGNvbmZpZ01hcEtleVJlZjoKICAgICAgICAgICAgICBuYW1lOiBsYS1jYXJ0YS12aWVqYQogICAgICAgICAgICAgIGtleTogUFJFQ0lPX0FMTVVFUlpPCg==' \
  | base64 -d > "$W/averias/paso1.yaml"
printf '%s' 'YXBpVmVyc2lvbjogdjEKa2luZDogTmFtZXNwYWNlCm1ldGFkYXRhOgogIG5hbWU6IGxhLWJvZGVnYQotLS0KYXBpVmVyc2lvbjogYXBwcy92MQpraW5kOiBEZXBsb3ltZW50Cm1ldGFkYXRhOgogIG5hbWU6IGFycm96CiAgbmFtZXNwYWNlOiBsYS1ib2RlZ2EKICBsYWJlbHM6CiAgICBhcHA6IGFycm96CnNwZWM6CiAgcmVwbGljYXM6IDEKICBzZWxlY3RvcjoKICAgIG1hdGNoTGFiZWxzOgogICAgICBhcHA6IGFycm96CiAgdGVtcGxhdGU6CiAgICBtZXRhZGF0YToKICAgICAgbGFiZWxzOgogICAgICAgIGFwcDogYXJyb3oKICAgIHNwZWM6CiAgICAgIG5vZGVTZWxlY3RvcjoKICAgICAgICBrdWJlcm5ldGVzLmlvL2hvc3RuYW1lOiBja2EtY29taWNvLXAwNS13b3JrZXIKICAgICAgY29udGFpbmVyczoKICAgICAgLSBuYW1lOiBidWx0bwogICAgICAgIGltYWdlOiBuZ2lueDoxLjI5LWFscGluZUBzaGEyNTY6NTYxNjg3ODI5MWEyZWVkNTk0YWVlOGRiNGRhZGU1ODc4Y2Y3ZWRjYjQ3NWU1OTE5MzkwNGIxOThkOWI4MzBkZQogICAgICAgIHJlc291cmNlczoKICAgICAgICAgIHJlcXVlc3RzOgogICAgICAgICAgICBjcHU6ICI4MDAiCiAgICAgICAgICAgIG1lbW9yeTogIjMwMDBHaSIK' \
  | base64 -d > "$W/averias/paso3.yaml"
printf '%s' 'YXBpVmVyc2lvbjogdjEKa2luZDogTmFtZXNwYWNlCm1ldGFkYXRhOgogIG5hbWU6IGVsLWJhcnJpbwotLS0KYXBpVmVyc2lvbjogYXBwcy92MQpraW5kOiBEZXBsb3ltZW50Cm1ldGFkYXRhOgogIG5hbWU6IHBvcnRlcm8KICBuYW1lc3BhY2U6IGVsLWJhcnJpbwogIGxhYmVsczoKICAgIGFwcDogcG9ydGVybwpzcGVjOgogIHJlcGxpY2FzOiAyCiAgc2VsZWN0b3I6CiAgICBtYXRjaExhYmVsczoKICAgICAgYXBwOiBwb3J0ZXJvCiAgdGVtcGxhdGU6CiAgICBtZXRhZGF0YToKICAgICAgbGFiZWxzOgogICAgICAgIGFwcDogcG9ydGVybwogICAgc3BlYzoKICAgICAgbm9kZVNlbGVjdG9yOgogICAgICAgIGt1YmVybmV0ZXMuaW8vaG9zdG5hbWU6IGNrYS1jb21pY28tcDA1LXdvcmtlcgogICAgICBjb250YWluZXJzOgogICAgICAtIG5hbWU6IGNhc2V0YQogICAgICAgIGltYWdlOiBuZ2lueDoxLjI5LWFscGluZUBzaGEyNTY6NTYxNjg3ODI5MWEyZWVkNTk0YWVlOGRiNGRhZGU1ODc4Y2Y3ZWRjYjQ3NWU1OTE5MzkwNGIxOThkOWI4MzBkZQogICAgICAgIHBvcnRzOgogICAgICAgIC0gY29udGFpbmVyUG9ydDogODAKICAgICAgICAgIG5hbWU6IGh0dHAKLS0tCmFwaVZlcnNpb246IHYxCmtpbmQ6IFNlcnZpY2UKbWV0YWRhdGE6CiAgbmFtZTogcG9ydGVyaWEKICBuYW1lc3BhY2U6IGVsLWJhcnJpbwpzcGVjOgogIHNlbGVjdG9yOgogICAgYXBwOiBwb3J0ZXJvCiAgcG9ydHM6CiAgLSBuYW1lOiBodHRwCiAgICBwcm90b2NvbDogVENQCiAgICBwb3J0OiA4MAogICAgdGFyZ2V0UG9ydDogODA4MAotLS0KYXBpVmVyc2lvbjogbmV0d29ya2luZy5rOHMuaW8vdjEKa2luZDogTmV0d29ya1BvbGljeQptZXRhZGF0YToKICBuYW1lOiBzb2xvLWxvcy1kZS1sYS1jYXNhCiAgbmFtZXNwYWNlOiBlbC1iYXJyaW8Kc3BlYzoKICBwb2RTZWxlY3RvcjoKICAgIG1hdGNoTGFiZWxzOgogICAgICBhcHA6IHBvcnRlcm8KICBwb2xpY3lUeXBlczoKICAtIEluZ3Jlc3MKICBpbmdyZXNzOgogIC0gZnJvbToKICAgIC0gcG9kU2VsZWN0b3I6CiAgICAgICAgbWF0Y2hMYWJlbHM6CiAgICAgICAgICBhcHA6IHJlc2lkZW50ZQogICAgcG9ydHM6CiAgICAtIHByb3RvY29sOiBUQ1AKICAgICAgcG9ydDogODAKLS0tCmFwaVZlcnNpb246IHYxCmtpbmQ6IFBvZAptZXRhZGF0YToKICBuYW1lOiB2aXNpdGFudGUKICBuYW1lc3BhY2U6IGVsLWJhcnJpbwogIGxhYmVsczoKICAgIGFwcDogdmlzaXRhbnRlCnNwZWM6CiAgbm9kZVNlbGVjdG9yOgogICAga3ViZXJuZXRlcy5pby9ob3N0bmFtZTogY2thLWNvbWljby1wMDUtd29ya2VyCiAgY29udGFpbmVyczoKICAtIG5hbWU6IGN1cmwKICAgIGltYWdlOiBjdXJsaW1hZ2VzL2N1cmxAc2hhMjU2OmQ5NGQwN2JhOWU3ZDZkZTg5OGI2ZDk2YzFhMDcyZjZmODI2NmM2ODdhZjc4YTc0ZjM4MDA4N2EwYWRkZjVkMTcKICAgIGNvbW1hbmQ6IFsic2xlZXAiLCAiMzYwMDAiXQo=' \
  | base64 -d > "$W/averias/paso4.yaml"
printf '%s' 'ZG9ja2VyIGV4ZWMgY2thLWNvbWljby1wMDUtd29ya2VyMiBzeXN0ZW1jdGwgc3RvcCBrdWJlbGV0Cg==' \
  | base64 -d > "$W/averias/paso2.sh"

$K apply -f "$W/averias/paso1.yaml" >/dev/null
$K apply -f "$W/averias/paso3.yaml" >/dev/null
$K apply -f "$W/averias/paso4.yaml" >/dev/null

# Se espera a que las averias de los Pasos 1, 3 y 4 sean visibles, para que
# usted reciba un sistema roto y no un sistema a medio arrancar.
$K -n el-barrio rollout status deployment/portero --timeout=300s >/dev/null
$K -n el-barrio wait --for=condition=Ready pod/visitante --timeout=300s >/dev/null
for i in $(seq 1 40); do
  R1=$($K -n cuchara-de-oro get pods -l app=sancocho \
        -o jsonpath='{.items[*].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
  R2=$($K -n cuchara-de-oro get pods -l app=bandeja \
        -o jsonpath='{.items[*].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
  R3=$($K -n la-bodega get pods -l app=arroz -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  case "$R1 $R2 $R3" in
    *ImagePullBackOff*CreateContainerConfigError*Pending*) break ;;
  esac
  sleep 10
done

# La averia del Paso 2 va de ultima, y el montaje espera a que el sintoma
# aflore: el nodo tarda cerca de un minuto en pasar a NotReady despues de que
# su kubelet deja de reportar.
sh "$W/averias/paso2.sh"
for i in $(seq 1 30); do
  E=$($K get nodes -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep -c Unknown || true)
  [ "$E" -ge 1 ] && break
  sleep 10
done

echo "kubeconfig privado del laboratorio: $KC"
echo "USE --kubeconfig $KC EN TODOS SUS COMANDOS kubectl."
$K get nodes
$K get pods -A -o wide | grep -E 'cuchara-de-oro|la-bodega|el-barrio' || true
echo "montaje listo: el cluster cka-comico-p05 quedo con cuatro averias puestas."
