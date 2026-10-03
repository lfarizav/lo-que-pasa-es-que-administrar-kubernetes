#!/usr/bin/env bash
# lab-part-01 step 3 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

cd ~/cka-comico-lab/p01
KC="$HOME/cka-comico-lab/p01/kubeconfig"
K="kubectl --kubeconfig $KC --context kind-cka-comico-p01"

$K get users

openssl genrsa -out marcela.key 3072
openssl req -new -key marcela.key -out marcela.csr -subj "/CN=marcela/O=cocina"

cat <<EOF | $K apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: marcela
spec:
  request: $(base64 < marcela.csr | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF

$K get csr marcela
$K certificate approve marcela
$K get csr marcela

$K get csr marcela -o jsonpath='{.status.certificate}' | base64 -d > marcela.crt
openssl x509 -in marcela.crt -noout -subject -issuer -enddate

kubectl --kubeconfig "$KC" config set-credentials marcela \
  --client-key=marcela.key --client-certificate=marcela.crt --embed-certs=true
kubectl --kubeconfig "$KC" config set-context marcela \
  --cluster=kind-cka-comico-p01 --user=marcela --namespace=la-casa

M="kubectl --kubeconfig $KC --context marcela"
$M auth whoami
$M get pods

$K -n la-casa create serviceaccount el-medidor
$K -n la-casa create role encargada \
  --verb=get --verb=list --verb=create --verb=delete --resource=pods
$K -n la-casa create role medidor \
  --verb=get --verb=list --verb=watch --resource=pods
$K -n la-casa create rolebinding llave-de-marcela \
  --role=encargada --user=marcela
$K -n la-casa create rolebinding llave-del-medidor \
  --role=medidor --serviceaccount=la-casa:el-medidor

HERRAMIENTA=system:serviceaccount:la-casa:el-medidor
for VERBO in get create delete watch; do
  printf 'marcela %s pods en la-casa: ' "$VERBO"
  $K auth can-i "$VERBO" pods -n la-casa --as=marcela
  printf 'el-medidor %s pods en la-casa: ' "$VERBO"
  $K auth can-i "$VERBO" pods -n la-casa --as="$HERRAMIENTA"
done
$K auth can-i get pods -n la-finca-vecina --as=marcela
$K auth can-i get pods -n la-finca-vecina --as="$HERRAMIENTA"

$M auth can-i delete pods
$M auth can-i watch pods
$M auth can-i get pods -n la-finca-vecina
$M get pods

SERVIDOR=$(kubectl --kubeconfig "$KC" config view --raw --minify \
  -o jsonpath='{.clusters[0].cluster.server}')
kubectl --kubeconfig "$KC" config view --raw --minify \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > ca.crt
TOKEN=$($K -n la-casa create token el-medidor --duration=1h)
T="env KUBECONFIG=/dev/null kubectl --server=$SERVIDOR --certificate-authority=ca.crt --token=$TOKEN"
$T auth whoami
$T get pods -n la-casa
$T auth can-i delete pods -n la-casa

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p01"
cat > "$D/03-respuesta.txt" <<EOF
USUARIO_AUTENTICADO=$($M auth whoami -o jsonpath='{.status.userInfo.username}')
FIRMANTE_DE_LA_CSR=$($K get csr marcela -o jsonpath='{.spec.signerName}')
LA_PERSONA_PUEDE_BORRAR=$($M auth can-i delete pods -n la-casa || true)
LA_HERRAMIENTA_PUEDE_BORRAR=$($T auth can-i delete pods -n la-casa || true)
EOF
cat "$D/03-respuesta.txt"
