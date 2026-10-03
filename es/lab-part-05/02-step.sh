#!/usr/bin/env bash
# lab-part-05 step 2 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

W="$HOME/cka-comico-lab/p05"; K="kubectl --kubeconfig $W/kubeconfig"

# 1. El tablero: cual de los tres nodos esta reportando mal.
$K get nodes

# 2. Que dicen las condiciones de ese nodo, con su razon y su mensaje.
$K describe node cka-comico-p05-worker2 | sed -n '/Conditions:/,/Addresses:/p'
$K get node cka-comico-p05-worker2 \
  -o jsonpath='{range .status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.reason}{"\t"}{.message}{"\n"}{end}'

# 3. Bajar al piso del nodo. En kind cada nodo es un contenedor de Docker,
#    asi que el "servidor" se abre con docker exec y adentro hay systemd.
docker exec cka-comico-p05-worker2 systemctl is-active kubelet
docker exec cka-comico-p05-worker2 systemctl status kubelet --no-pager | head -12

# 4. Prenderlo otra vez y mirar su bitacora.
docker exec cka-comico-p05-worker2 systemctl start kubelet
docker exec cka-comico-p05-worker2 systemctl is-active kubelet
docker exec cka-comico-p05-worker2 journalctl -u kubelet --no-pager -n 15

# 5. Esperar a que el nodo vuelva a reportarse y confirmar.
$K wait --for=condition=Ready node/cka-comico-p05-worker2 --timeout=180s
$K get nodes

# The answer file the book asks you to type, written from the live cluster:
cat > "$W/02-respuesta.txt" <<'EOF'
NODO_CAIDO=cka-comico-p05-worker2
RAZON_CONDICION=NodeStatusUnknown
SERVICIO_CULPABLE=kubelet
EOF
cat "$W/02-respuesta.txt"
