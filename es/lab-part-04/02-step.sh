#!/usr/bin/env bash
# lab-part-04 step 2 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab fail on purpose (a Forbidden, a "no" from auth can-i, a
# missing file): the failure is the lesson. Fail-fast is therefore switched off from here
# and the script reports through its explicit exit codes and the grader.
set +e

KC="$HOME/cka-comico-lab/p04/kubeconfig"
cd ~/cka-comico-lab/p04

cat > despensero.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: despensero
  namespace: cuchara-de-oro
spec:
  containers:
  - name: despensero
    image: busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0
    command: ["sh", "-c", "sleep 86400"]
    volumeMounts:
    - name: deposito
      mountPath: /deposito
  volumes:
  - name: deposito
    persistentVolumeClaim:
      claimName: contrato-de-la-cocina
YAML

kubectl --kubeconfig "$KC" apply -f despensero.yaml
kubectl --kubeconfig "$KC" -n cuchara-de-oro wait --for=condition=Ready pod/despensero --timeout=180s
kubectl --kubeconfig "$KC" -n cuchara-de-oro get pod despensero -o wide

kubectl --kubeconfig "$KC" -n cuchara-de-oro exec despensero -- \
  sh -c 'echo "la-cosecha-de-agosto" > /deposito/marca.txt'
kubectl --kubeconfig "$KC" -n cuchara-de-oro exec despensero -- cat /deposito/marca.txt
kubectl --kubeconfig "$KC" -n cuchara-de-oro exec despensero -- stat -c '%Y %n' /deposito/marca.txt

kubectl --kubeconfig "$KC" -n cuchara-de-oro delete pod despensero --wait=true
sleep 3
kubectl --kubeconfig "$KC" apply -f despensero.yaml
kubectl --kubeconfig "$KC" -n cuchara-de-oro wait --for=condition=Ready pod/despensero --timeout=180s

echo "--- despues de la mudanza ---"
kubectl --kubeconfig "$KC" -n cuchara-de-oro get pod despensero -o wide
kubectl --kubeconfig "$KC" -n cuchara-de-oro exec despensero -- cat /deposito/marca.txt
echo "mtime del archivo: $(kubectl --kubeconfig "$KC" -n cuchara-de-oro exec despensero -- stat -c '%Y' /deposito/marca.txt)"
echo "startTime del Pod: $(date -u -d "$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pod despensero -o jsonpath='{.status.startTime}')" +%s)"

# The answer file the book asks you to type, written from the live cluster:
D="$HOME/cka-comico-lab/p04"
cat > "$D/02-respuesta.txt" <<EOF
MARCA=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro exec despensero -- cat /deposito/marca.txt)
VOLUMEN_DEL_POD=$(kubectl --kubeconfig "$KC" -n cuchara-de-oro get pod despensero -o jsonpath='{.spec.volumes[0].persistentVolumeClaim.claimName}')
EOF
cat "$D/02-respuesta.txt"
