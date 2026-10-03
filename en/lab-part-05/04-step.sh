#!/usr/bin/env bash
# lab-part-05 step 4 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

W="$HOME/cka-comico-lab/p05"; K="kubectl --kubeconfig $W/kubeconfig"
URL="http://porteria.el-barrio.svc.cluster.local"

# 1. El sintoma, desde adentro del clúster y no desde su portatil.
$K -n el-barrio get pods -o wide
$K -n el-barrio exec visitante -- curl -sS -o /dev/null -w 'CODIGO=%{http_code}\n' --max-time 6 "$URL" || true

# 2. Primera pregunta del procedimiento oficial: hay Pods listos detras?
$K -n el-barrio get deployment portero
$K -n el-barrio get pods -l app=portero

# 3. Segunda: el directorio tiene anotado a alguien, y en que puerto?
$K -n el-barrio get endpointslices -o wide
$K -n el-barrio get service porteria -o yaml | sed -n '/^spec:/,$p'

# 4. Tercera: el numero del directorio coincide con el puerto que el
#    contenedor de verdad escucha?
$K -n el-barrio get deployment portero \
  -o jsonpath='{.spec.template.spec.containers[0].ports[*].containerPort}{"\n"}'

# 5. Arreglar el numero mal anotado.
$K -n el-barrio patch service porteria --type=json \
  -p '[{"op":"replace","path":"/spec/ports/0/targetPort","value":80}]'
sleep 5
$K -n el-barrio get endpointslices -o wide
$K -n el-barrio exec visitante -- curl -sS -o /dev/null -w 'CODIGO=%{http_code}\n' --max-time 6 "$URL" || true

# 6. Sigue sin entrar: falta la portería. Quien esta autorizado hoy?
$K -n el-barrio get networkpolicy
$K -n el-barrio get networkpolicy solo-los-de-la-casa -o yaml | sed -n '/^spec:/,$p'
$K -n el-barrio get pod visitante --show-labels

# 7. Autorizar al visitante SIN quitar la portería del edificio.
$K -n el-barrio patch networkpolicy solo-los-de-la-casa --type=json \
  -p '[{"op":"add","path":"/spec/ingress/0/from/-","value":{"podSelector":{"matchLabels":{"app":"visitante"}}}}]'
sleep 6

# 8. Comprobar en vivo.
$K -n el-barrio exec visitante -- curl -sS -o /dev/null -w 'CODIGO=%{http_code}\n' --max-time 6 "$URL"

# The answer file the book asks you to type, written from the live cluster:
cat > "$W/04-respuesta.txt" <<'EOF'
TARGETPORT_MALO=8080
TARGETPORT_BUENO=80
POLITICA_CULPABLE=solo-los-de-la-casa
EOF
cat "$W/04-respuesta.txt"
