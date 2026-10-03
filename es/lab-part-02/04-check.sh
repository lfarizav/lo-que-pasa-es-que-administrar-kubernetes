#!/usr/bin/env bash
# lab-part-02 step 4 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/cka-comico-lab/p02"
K="kubectl --kubeconfig $D/kubeconfig"
NS=cuchara-de-oro
test -f "$D/04-respuesta.txt" || exit 1
FASE=$($K -n $NS get pod el-cocinero -o jsonpath='{.status.phase}' 2>/dev/null)
test "$FASE" = "Running" || exit 1
FUENTES=$($K -n $NS get pod el-cocinero -o jsonpath='{range .spec.containers[*].envFrom[*]}{.configMapRef.name}{"\n"}{end}{range .spec.containers[*].env[*]}{.valueFrom.configMapKeyRef.name}{"\n"}{end}' 2>/dev/null)
echo "$FUENTES" | grep -qxF "carta-del-dia" || exit 1
VOL=$($K -n $NS get pod el-cocinero -o jsonpath='{range .spec.volumes[?(@.secret.secretName=="receta-secreta")]}{.name}{"\n"}{end}' 2>/dev/null | head -1)
test -n "$VOL" || exit 1
MONTAJE=$($K -n $NS get pod el-cocinero -o jsonpath="{range .spec.containers[*].volumeMounts[?(@.name==\"$VOL\")]}{.mountPath}{\"\n\"}{end}" 2>/dev/null | head -1)
test -n "$MONTAJE" || exit 1
RUTA=$(grep -oP "(?<=RUTA_DEL_SECRETO=).*" "$D/04-respuesta.txt")
test "$RUTA" = "${MONTAJE%/}/sazon.txt" || exit 1
CM=$($K -n $NS get configmap carta-del-dia -o jsonpath='{.data.PLATO_DEL_DIA}' 2>/dev/null)
test -n "$CM" || exit 1
ENV=$($K -n $NS exec el-cocinero -- printenv PLATO_DEL_DIA 2>/dev/null)
test -n "$ENV" || exit 1
test "$ENV" = "$CM" || exit 1
grep -qxF "PLATO_EN_EL_CONTENEDOR=$ENV" "$D/04-respuesta.txt" || exit 1
SEC=$($K -n $NS get secret receta-secreta -o jsonpath='{.data.sazon\.txt}' 2>/dev/null | base64 -d)
test -n "$SEC" || exit 1
ARCHIVO=$($K -n $NS exec el-cocinero -- cat "$RUTA" 2>/dev/null)
test -n "$ARCHIVO" || exit 1
test "$ARCHIVO" = "$SEC" || exit 1
grep -qxF "SAZON_EN_EL_CONTENEDOR=$ARCHIVO" "$D/04-respuesta.txt" || exit 1
echo ok
