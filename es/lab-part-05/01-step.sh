#!/usr/bin/env bash
# lab-part-05 step 1 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

W="$HOME/cka-comico-lab/p05"; K="kubectl --kubeconfig $W/kubeconfig"
IMG="nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de"

# 1. Tomar la temperatura: quien esta caido y con que estado.
$K -n cuchara-de-oro get deployments
$K -n cuchara-de-oro get pods

# 2. La historia clinica de cada uno. Las dos razones salen distintas.
$K -n cuchara-de-oro get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].state.waiting.reason}{"\t"}{.status.containerStatuses[0].state.waiting.message}{"\n"}{end}'
$K -n cuchara-de-oro describe pod -l app=sancocho | tail -12
$K -n cuchara-de-oro describe pod -l app=bandeja  | tail -10

# 3. Los examenes: que pide cada Deployment y que hay de verdad en la casa.
$K -n cuchara-de-oro get deployment sancocho -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
$K -n cuchara-de-oro get deployment bandeja  -o jsonpath='{.spec.template.spec.containers[0].env[*].valueFrom.configMapKeyRef.name}{"\n"}'
$K -n cuchara-de-oro get configmaps

# 4. Recetar. Al sancocho le falta la imagen correcta, fijada por digest.
$K -n cuchara-de-oro set image deployment/sancocho olla="$IMG"

# 5. A la bandeja le falta apuntar al ConfigMap que SI existe, sin dejar de
#    leerlo del ConfigMap: el precio nunca se escribe a mano en el manifiesto.
$K -n cuchara-de-oro patch deployment bandeja --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/configMapKeyRef/name","value":"la-carta"}]'

# 6. Comprobar el alta medica de los dos.
$K -n cuchara-de-oro rollout status deployment/sancocho --timeout=240s
$K -n cuchara-de-oro rollout status deployment/bandeja  --timeout=240s
$K -n cuchara-de-oro get deployments
$K -n cuchara-de-oro exec deploy/bandeja -- printenv PRECIO_ALMUERZO

# The answer file the book asks you to type, written from the live cluster:
cat > "$W/01-respuesta.txt" <<'EOF'
RAZON_SANCOCHO=ImagePullBackOff
RAZON_BANDEJA=CreateContainerConfigError
RECURSO_FALTANTE=la-carta-vieja
TAG_INEXISTENTE=1.29-alpinita
EOF
cat "$W/01-respuesta.txt"
