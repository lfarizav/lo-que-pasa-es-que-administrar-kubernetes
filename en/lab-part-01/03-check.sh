#!/usr/bin/env bash
# lab-part-01 step 3 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/cka-comico-lab/p01"
KC="$D/kubeconfig"
K="kubectl --kubeconfig $KC --context kind-cka-comico-p01"
M="kubectl --kubeconfig $KC --context marcela"
CASA=la-casa
VECINA=la-finca-vecina
HERRAMIENTA="system:serviceaccount:${CASA}:el-medidor"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
test -f "$D/03-respuesta.txt" || exit 1
CSR=$($K get csr marcela -o json 2>/dev/null) || exit 1
FIRMANTE=$(echo "$CSR" | jq -r '.spec.signerName')
test "$FIRMANTE" = "kubernetes.io/kube-apiserver-client" || exit 1
echo "$CSR" | jq -e '[.status.conditions[]? | select(.type == "Approved" and .status == "True")] | length == 1' >/dev/null || exit 1
echo "$CSR" | jq -e '(.status.certificate // "") | length > 0' >/dev/null || exit 1
echo "$CSR" | jq -r '.status.certificate' | base64 -d > "$TMP/emitido.pem"
openssl x509 -in "$TMP/emitido.pem" -noout -checkend 0 >/dev/null 2>&1 || exit 1
openssl x509 -in "$TMP/emitido.pem" -noout -subject -nameopt RFC2253 | grep -q 'CN=marcela' || exit 1
CFG=$(kubectl --kubeconfig "$KC" config view --raw -o json 2>/dev/null) || exit 1
USUARIO=$(echo "$CFG" | jq -r '.contexts[]? | select(.name == "marcela") | .context.user // empty')
CLUSTER_M=$(echo "$CFG" | jq -r '.contexts[]? | select(.name == "marcela") | .context.cluster // empty')
CLUSTER_A=$(echo "$CFG" | jq -r '.contexts[]? | select(.name == "kind-cka-comico-p01") | .context.cluster // empty')
test -n "$USUARIO" || exit 1
test -n "$CLUSTER_M" || exit 1
test "$CLUSTER_M" = "$CLUSTER_A" || exit 1
echo "$CFG" | jq -r --arg u "$USUARIO" '.users[]? | select(.name == $u) | .user["client-certificate-data"] // empty' | base64 -d > "$TMP/en-kubeconfig.pem" 2>/dev/null
FP1=$(openssl x509 -in "$TMP/en-kubeconfig.pem" -noout -fingerprint -sha256 2>/dev/null) || exit 1
FP2=$(openssl x509 -in "$TMP/emitido.pem" -noout -fingerprint -sha256 2>/dev/null) || exit 1
test -n "$FP1" || exit 1
test "$FP1" = "$FP2" || exit 1
QUIEN=$($M auth whoami -o jsonpath='{.status.userInfo.username}' 2>/dev/null)
test "$QUIEN" = "marcela" || exit 1
$M auth whoami -o json 2>/dev/null | jq -e '(.status.userInfo.groups // []) | index("system:masters") | not' >/dev/null || exit 1
$K -n "$CASA" get serviceaccount el-medidor >/dev/null 2>&1 || exit 1
RB=$($K -n "$CASA" get rolebindings -o json 2>/dev/null) || exit 1
echo "$RB" | jq -e '[.items[] | select(any(.subjects[]?; .kind == "User" and .name == "marcela"))] | length >= 1' >/dev/null || exit 1
echo "$RB" | jq -e --arg ns "$CASA" '[.items[] | select(any(.subjects[]?; .kind == "ServiceAccount" and .name == "el-medidor" and ((.namespace == $ns) or (.namespace == null))))] | length >= 1' >/dev/null || exit 1
$K get clusterrolebindings -o json 2>/dev/null | jq -e --arg ns "$CASA" '[.items[] | select(any(.subjects[]?; (.kind == "User" and .name == "marcela") or (.kind == "Group" and .name == "cocina") or (.kind == "ServiceAccount" and .name == "el-medidor" and .namespace == $ns)))] | length == 0' >/dev/null || exit 1
for V in get list create delete; do
  test "$($K auth can-i "$V" pods -n "$CASA" --as=marcela 2>/dev/null)" = "yes" || exit 1
done
test "$($K auth can-i watch pods -n "$CASA" --as=marcela 2>/dev/null)" = "no" || exit 1
test "$($K auth can-i get pods -n "$VECINA" --as=marcela 2>/dev/null)" = "no" || exit 1
test "$($K auth can-i '*' '*' -n "$CASA" --as=marcela 2>/dev/null)" = "no" || exit 1
for V in get list watch; do
  test "$($K auth can-i "$V" pods -n "$CASA" --as="$HERRAMIENTA" 2>/dev/null)" = "yes" || exit 1
done
for V in create delete; do
  test "$($K auth can-i "$V" pods -n "$CASA" --as="$HERRAMIENTA" 2>/dev/null)" = "no" || exit 1
done
test "$($K auth can-i get pods -n "$VECINA" --as="$HERRAMIENTA" 2>/dev/null)" = "no" || exit 1
PERSONA_BORRA=$($M auth can-i delete pods -n "$CASA" 2>/dev/null)
test "$PERSONA_BORRA" = "yes" || exit 1
$M -n "$CASA" get pods >/dev/null 2>&1 || exit 1
$M -n "$CASA" delete pod la-alarma --dry-run=server >/dev/null 2>&1 || exit 1
$M -n "$VECINA" get pods >/dev/null 2>&1 && exit 1
SERVIDOR=$(echo "$CFG" | jq -r --arg c "$CLUSTER_A" '.clusters[]? | select(.name == $c) | .cluster.server')
echo "$CFG" | jq -r --arg c "$CLUSTER_A" '.clusters[]? | select(.name == $c) | .cluster["certificate-authority-data"]' | base64 -d > "$TMP/ca.crt"
TOKEN=$($K -n "$CASA" create token el-medidor --duration=10m 2>/dev/null) || exit 1
T="env KUBECONFIG=/dev/null kubectl --server=$SERVIDOR --certificate-authority=$TMP/ca.crt --token=$TOKEN"
test "$($T auth whoami -o jsonpath='{.status.userInfo.username}' 2>/dev/null)" = "$HERRAMIENTA" || exit 1
$T get pods -n "$CASA" >/dev/null 2>&1 || exit 1
HERRAMIENTA_BORRA=$($T auth can-i delete pods -n "$CASA" 2>/dev/null)
test "$HERRAMIENTA_BORRA" = "no" || exit 1
grep -qxF "USUARIO_AUTENTICADO=$QUIEN" "$D/03-respuesta.txt" || exit 1
grep -qxF "FIRMANTE_DE_LA_CSR=$FIRMANTE" "$D/03-respuesta.txt" || exit 1
grep -qxF "LA_PERSONA_PUEDE_BORRAR=$PERSONA_BORRA" "$D/03-respuesta.txt" || exit 1
grep -qxF "LA_HERRAMIENTA_PUEDE_BORRAR=$HERRAMIENTA_BORRA" "$D/03-respuesta.txt" || exit 1
echo ok
