#!/usr/bin/env bash
# lab-part-03 step 2 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

cd ~/cka-comico-lab/p03
K="kubectl --kubeconfig $HOME/cka-comico-lab/p03/kubeconfig"
DNSUTILS=registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3@sha256:8b03e4185ecd305bc9b410faac15d486a3b1ef1946196d429245cdd3c7b152eb

cat > las-casas-mismas.yaml <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: las-casas-mismas
  namespace: el-barrio
spec:
  clusterIP: None
  selector:
    app: dona-rosa
  ports:
  - name: http
    port: 80
    targetPort: 80
YAML

$K apply -f las-casas-mismas.yaml
$K -n el-barrio get svc

$K -n el-barrio run el-visitante --image=$DNSUTILS --command -- sleep 36000
$K -n el-barrio wait --for=condition=Ready pod/el-visitante --timeout=300s

$K -n el-barrio exec el-visitante -- nslookup tienda-de-la-esquina.el-barrio.svc.cluster.local
$K -n el-barrio exec el-visitante -- nslookup las-casas-mismas.el-barrio.svc.cluster.local

$K -n el-barrio get svc tienda-de-la-esquina -o jsonpath='{.spec.clusterIP}{"\n"}'
$K -n el-barrio get svc las-casas-mismas -o jsonpath='{.spec.clusterIP}{"\n"}'
$K -n el-barrio get pods -l app=dona-rosa -o wide

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p03"
cat > "$D/02-respuesta.txt" <<EOF
NOMBRE_COMPLETO=tienda-de-la-esquina.el-barrio.svc.cluster.local
CLUSTERIP_POR_DNS=$($K -n el-barrio get svc tienda-de-la-esquina -o jsonpath='{.spec.clusterIP}')
REGISTROS_HEADLESS=$($K -n el-barrio exec el-visitante -- nslookup las-casas-mismas.el-barrio.svc.cluster.local | tr -d '\r' | awk -F'[ \t]+' '/^Address:/{print $2}' | grep -v '#' | grep -c .)
EOF
cat "$D/02-respuesta.txt"
