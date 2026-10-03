#!/usr/bin/env bash
# lab-part-02 step 1 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

cd ~/cka-comico-lab/p02
KC="$HOME/cka-comico-lab/p02/kubeconfig"

VIEJA=nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236
NUEVA=nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de

kubectl --kubeconfig "$KC" -n cuchara-de-oro create deployment receta-del-dia \
  --image="$VIEJA" --replicas=3
kubectl --kubeconfig "$KC" -n cuchara-de-oro rollout status deployment/receta-del-dia --timeout=300s

kubectl --kubeconfig "$KC" -n cuchara-de-oro get deployment receta-del-dia \
  -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}{"\n"}'

kubectl --kubeconfig "$KC" -n cuchara-de-oro set image deployment/receta-del-dia nginx="$NUEVA"
kubectl --kubeconfig "$KC" -n cuchara-de-oro rollout status deployment/receta-del-dia --timeout=300s

kubectl --kubeconfig "$KC" -n cuchara-de-oro rollout history deployment/receta-del-dia

kubectl --kubeconfig "$KC" -n cuchara-de-oro rollout undo deployment/receta-del-dia
kubectl --kubeconfig "$KC" -n cuchara-de-oro rollout status deployment/receta-del-dia --timeout=300s

kubectl --kubeconfig "$KC" -n cuchara-de-oro rollout history deployment/receta-del-dia

kubectl --kubeconfig "$KC" -n cuchara-de-oro get deployment receta-del-dia \
  -o jsonpath='rev={.metadata.annotations.deployment\.kubernetes\.io/revision}{"\n"}imagen={.spec.template.spec.containers[0].image}{"\n"}listas={.status.readyReplicas}{"\n"}'

kubectl --kubeconfig "$KC" -n cuchara-de-oro get rs -l app=receta-del-dia \
  -o custom-columns='NOMBRE:.metadata.name,REV:.metadata.annotations.deployment\.kubernetes\.io/revision,IMAGEN:.spec.template.spec.containers[0].image,DESEADAS:.spec.replicas'

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p02"
cat > "$D/01-respuesta.txt" <<EOF
REVISION_ACTUAL=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get deployment receta-del-dia -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
IMAGEN_ACTUAL=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get deployment receta-del-dia -o jsonpath='{.spec.template.spec.containers[0].image}')
REPLICAS_LISTAS=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get deployment receta-del-dia -o jsonpath='{.status.readyReplicas}')
EOF
cat "$D/01-respuesta.txt"
