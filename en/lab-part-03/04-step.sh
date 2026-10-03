#!/usr/bin/env bash
# lab-part-03 step 4 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

cd ~/cka-comico-lab/p03
K="kubectl --kubeconfig $HOME/cka-comico-lab/p03/kubeconfig"
IMG=nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de

cat > apartamentos.yaml <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: contenido-101
  namespace: el-edificio
data:
  index.html: |
    APARTAMENTO 101
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: contenido-302
  namespace: el-edificio
data:
  index.html: |
    APARTAMENTO 302
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apartamento-101
  namespace: el-edificio
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apartamento-101
  template:
    metadata:
      labels:
        app: apartamento-101
    spec:
      containers:
      - name: web
        image: $IMG
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html/101
      volumes:
      - name: html
        configMap:
          name: contenido-101
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apartamento-302
  namespace: el-edificio
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apartamento-302
  template:
    metadata:
      labels:
        app: apartamento-302
    spec:
      containers:
      - name: web
        image: $IMG
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html/302
      volumes:
      - name: html
        configMap:
          name: contenido-302
---
apiVersion: v1
kind: Service
metadata:
  name: apartamento-101
  namespace: el-edificio
spec:
  selector:
    app: apartamento-101
  ports:
  - name: http
    port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: apartamento-302
  namespace: el-edificio
spec:
  selector:
    app: apartamento-302
  ports:
  - name: http
    port: 80
    targetPort: 80
YAML

$K apply -f apartamentos.yaml
$K -n el-edificio rollout status deploy/apartamento-101 --timeout=300s
$K -n el-edificio rollout status deploy/apartamento-302 --timeout=300s

$K get ingressclass
$K get ingressclass nginx -o jsonpath='{.spec.controller}{"\n"}'

cat > citofono.yaml <<'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: citofono
  namespace: el-edificio
spec:
  ingressClassName: nginx
  rules:
  - host: edificio.local
    http:
      paths:
      - path: /101
        pathType: Prefix
        backend:
          service:
            name: apartamento-101
            port:
              number: 80
      - path: /302
        pathType: Prefix
        backend:
          service:
            name: apartamento-302
            port:
              number: 80
YAML

$K apply -f citofono.yaml
$K -n el-edificio get ingress citofono
$K -n el-edificio describe ingress citofono

# el controlador no recarga sus reglas en el mismo instante del apply: si usted
# hace curl de una, le contesta 404 y parece que el Ingress no sirviera.
echo "esperando a que el controlador cargue las reglas nuevas..."
for _ in $(seq 1 30); do
  CODIGO=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 \
    -H 'Host: edificio.local' http://localhost:8080/101/ 2>/dev/null)
  [ "$CODIGO" = "200" ] && break
  sleep 2
done

curl -sS -H 'Host: edificio.local' http://localhost:8080/101/
curl -sS -H 'Host: edificio.local' http://localhost:8080/302/
curl -sS -o /dev/null -w 'con otro host: HTTP %{http_code}\n' -H 'Host: otro.local' http://localhost:8080/101/

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p03"
cat > "$D/04-respuesta.txt" <<EOF
CLASE_DEL_CITOFONO=$($K -n el-edificio get ingress citofono -o jsonpath='{.spec.ingressClassName}')
HOST_DEL_CITOFONO=$($K -n el-edificio get ingress citofono -o jsonpath='{.spec.rules[0].host}')
EOF
cat "$D/04-respuesta.txt"
