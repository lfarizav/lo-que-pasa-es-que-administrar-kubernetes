#!/usr/bin/env bash
# lab-part-02 step 4 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

cd ~/cka-comico-lab/p02
KC="$HOME/cka-comico-lab/p02/kubeconfig"

VIEJA=nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236

kubectl --kubeconfig "$KC" -n cuchara-de-oro create configmap carta-del-dia \
  --from-literal=PLATO_DEL_DIA=sancocho \
  --from-literal=PORCIONES=40

kubectl --kubeconfig "$KC" -n cuchara-de-oro create secret generic receta-secreta \
  --from-literal=sazon.txt='cilantro cimarron y una hoja de laurel'

kubectl --kubeconfig "$KC" -n cuchara-de-oro get configmap carta-del-dia -o yaml
kubectl --kubeconfig "$KC" -n cuchara-de-oro get secret receta-secreta -o yaml

cat > el-cocinero.yaml <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: el-cocinero
  namespace: cuchara-de-oro
spec:
  containers:
  - name: nginx
    image: $VIEJA
    envFrom:
    - configMapRef:
        name: carta-del-dia
    volumeMounts:
    - name: sazon
      mountPath: /etc/cuchara-de-oro
      readOnly: true
    resources:
      requests:
        cpu: 20m
        memory: 32Mi
  volumes:
  - name: sazon
    secret:
      secretName: receta-secreta
YAML

kubectl --kubeconfig "$KC" apply -f el-cocinero.yaml
kubectl --kubeconfig "$KC" -n cuchara-de-oro wait --for=condition=Ready pod/el-cocinero --timeout=300s

kubectl --kubeconfig "$KC" -n cuchara-de-oro exec el-cocinero -- printenv PLATO_DEL_DIA
kubectl --kubeconfig "$KC" -n cuchara-de-oro exec el-cocinero -- printenv PORCIONES

kubectl --kubeconfig "$KC" -n cuchara-de-oro exec el-cocinero -- ls -l /etc/cuchara-de-oro
kubectl --kubeconfig "$KC" -n cuchara-de-oro exec el-cocinero -- cat /etc/cuchara-de-oro/sazon.txt; echo

kubectl --kubeconfig "$KC" -n cuchara-de-oro get secret receta-secreta \
  -o jsonpath='{.data.sazon\.txt}' | base64 -d; echo

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p02"
cat > "$D/04-respuesta.txt" <<EOF
PLATO_EN_EL_CONTENEDOR=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro exec el-cocinero -- printenv PLATO_DEL_DIA)
SAZON_EN_EL_CONTENEDOR=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro exec el-cocinero -- cat /etc/cuchara-de-oro/sazon.txt)
RUTA_DEL_SECRETO=/etc/cuchara-de-oro/sazon.txt
EOF
cat "$D/04-respuesta.txt"
