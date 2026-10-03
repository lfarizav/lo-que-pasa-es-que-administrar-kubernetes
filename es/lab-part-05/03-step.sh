#!/usr/bin/env bash
# lab-part-05 step 3 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

W="$HOME/cka-comico-lab/p05"; K="kubectl --kubeconfig $W/kubeconfig"

# 1. El sintoma: el Pod nunca arranca porque nunca lo programan.
$K -n la-bodega get pods
$K -n la-bodega get pod -l app=arroz \
  -o jsonpath='{.items[0].status.conditions[0].reason}{"\n"}{.items[0].status.conditions[0].message}{"\n"}'

# 2. El evento del planificador, que es quien lo esta rechazando.
$K -n la-bodega get events --sort-by=.lastTimestamp | tail -5

# 3. Que pidio el bulto.
$K -n la-bodega get deployment arroz \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests}{"\n"}'

# 4. Cuanto cabe de verdad en el tanque. Asignable NO es Capacidad: el nodo
#    ya se reservo una parte para el sistema y para el kubelet.
$K describe node cka-comico-p05-worker | sed -n '/^Capacity:/,/^Allocated resources:/p'
$K get node cka-comico-p05-worker \
  -o jsonpath='{.status.allocatable.cpu}{"\t"}{.status.allocatable.memory}{"\n"}'
$K get nodes -o custom-columns='NODO:.metadata.name,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory'

# 5. Ajustar la peticion a algo que quepa, SIN borrar la peticion.
$K -n la-bodega patch deployment arroz --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests","value":{"cpu":"500m","memory":"256Mi"}}]'

# 6. Comprobar que ahora si lo programan y arranca.
$K -n la-bodega rollout status deployment/arroz --timeout=240s
$K -n la-bodega get pods -o wide

# The answer file the book asks you to type, written from the live cluster:
cat > "$W/03-respuesta.txt" <<EOF
EVENTO=FailedScheduling
CPU_ASIGNABLE=$($K get node cka-comico-p05-worker -o jsonpath='{.status.allocatable.cpu}')
MEMORIA_ASIGNABLE=$($K get node cka-comico-p05-worker -o jsonpath='{.status.allocatable.memory}')
EOF
cat "$W/03-respuesta.txt"
