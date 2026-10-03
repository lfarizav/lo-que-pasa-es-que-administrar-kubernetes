#!/usr/bin/env bash
# lab-part-03 step 1 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

cd ~/cka-comico-lab/p03
K="kubectl --kubeconfig $HOME/cka-comico-lab/p03/kubeconfig"
IMG=nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de

cat > dona-rosa.yaml <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dona-rosa
  namespace: el-barrio
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dona-rosa
  template:
    metadata:
      labels:
        app: dona-rosa
        casa: azul
    spec:
      containers:
      - name: web
        image: $IMG
        ports:
        - containerPort: 80
YAML

$K apply -f dona-rosa.yaml
$K -n el-barrio rollout status deploy/dona-rosa --timeout=300s
$K -n el-barrio get pods --show-labels -o wide

$K -n el-barrio expose deployment dona-rosa \
  --name=tienda-de-la-esquina --port=80 --target-port=80

$K -n el-barrio get endpointslices -l kubernetes.io/service-name=tienda-de-la-esquina
$K -n el-barrio get endpointslices -l kubernetes.io/service-name=directorio-viejo

$K -n el-barrio get svc directorio-viejo -o jsonpath='{.spec.selector}{"\n"}'
$K -n el-barrio get deploy dona-rosa -o jsonpath='{.spec.template.metadata.labels}{"\n"}'

$K -n el-barrio patch svc directorio-viejo \
  --type=json -p='[{"op":"replace","path":"/spec/selector/casa","value":"azul"}]'

$K -n el-barrio get endpointslices -l kubernetes.io/service-name=directorio-viejo

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p03"
cat > "$D/01-respuesta.txt" <<EOF
ENDPOINTS_TIENDA=$($K -n el-barrio get endpointslices -l kubernetes.io/service-name=tienda-de-la-esquina -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}' | grep -c .)
SELECTOR_ARREGLADO=casa=$($K -n el-barrio get svc directorio-viejo -o jsonpath='{.spec.selector.casa}')
EOF
cat "$D/01-respuesta.txt"
