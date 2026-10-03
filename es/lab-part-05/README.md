# Parte V - Laboratorio: el restaurante La Cuchara de Oro que no abre, el nodo que dejó de reportarse, el bulto que no cabe en la bodega, y la portería que no pasa la llamada

- Tiempo: 60 min
- Puntos: 40

## Objetivo

Este es un laboratorio Exam-Style y es de DIAGNÓSTICO puro: cada paso le indica solo el objetivo, y la secuencia exacta de comandos vive en el script NN-step.sh de ese paso para que usted la revele DESPUÉS de haber intentado resolverlo con sus propias manos. Los cuatro pasos arrancan con el sistema ya roto, porque el script de montaje aplica cuatro averías desde cargas codificadas en base64. Eso no es criptografía y no pretende serlo: es una venda de cortesía, para que usted no lea la respuesta en el mismo script que rompe el clúster. Las averías son idénticas para todo el mundo en todas las corridas, y la respuesta completa está en el script NN-step.sh de cada paso. El Paso 1 le entrega dos Deployments caídos en el mismo namespace por dos razones distintas, y usted tiene que separarlas con describe y eventos antes de arreglar nada (Capítulo 11). El Paso 2 le entrega un nodo que el API server ya no sabe si está vivo, y usted tiene que llegar hasta el servicio del sistema que dejó de reportar y volver a prenderlo (Capítulo 12). El Paso 3 le entrega una carga que nunca se programa porque pide más de lo que cabe, y usted tiene que leer lo Asignable del nodo con sus propias manos y ajustar la petición sin borrarla (Capítulo 13). El Paso 4 cierra con una aplicación inalcanzable por dos motivos apilados, y usted tiene que recorrer la ruta completa, Pod listo, endpoints, puerto y portería, hasta que un curl en vivo desde otro Pod devuelva 200 (Capítulo 14). Ninguna comprobación le cree lo que usted escribió: todas vuelven a consultar el clúster en el momento de calificar, una entra al contenedor del nodo a preguntarle al sistema operativo, y otra levanta un Pod nuevo para confirmar que el control que estorbaba sigue estorbando a quien debe.

## Prerrequisitos

- Una máquina Linux x86_64 desechable con kind, kubectl, docker (accesible sin sudo), base64 y python3 3.10 o superior en el PATH, y con al menos 6 GB de RAM libres. Confirme cada herramienta con su propio --version antes de empezar, no le crea a esta prosa. Verificado el 2026-08-21 con kind v0.32.0, kubectl v1.36.1 y Docker 29.7.2.
- AISLAMIENTO, y esto no es opcional. El laboratorio crea su propio clúster kind de tres nodos llamado cka-comico-p05 y escribe su kubeconfig en un archivo PRIVADO, ~/cka-comico-lab/p05/kubeconfig, desde el primer comando. Todos los comandos kubectl de este laboratorio llevan --kubeconfig apuntando a ese archivo, y usted debe hacer lo mismo. Nunca dependa del contexto actual de su ~/.kube/config: si usted tiene otro clúster abierto, un kubectl delete sin --kubeconfig se lo lleva a él y no a este. El laboratorio no toca ningún otro clúster, contexto ni contenedor de su máquina.
- IMÁGENES FIJADAS POR DIGEST, verificadas el 2026-08-21. Los nodos del clúster: kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, que es la imagen que kind v0.32.0 declara como suya. Los Pods de trabajo: nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de. El Pod cliente del Paso 4 y el Pod intruso que levanta la comprobación: curlimages/curl@sha256:d94d07ba9e7d6de898b6d96c1a072f6f8266c687af78a74f380087a0addf5d17. Una etiqueta es mutable y un digest no: los capítulos le enseñan a buscar la versión vigente, el laboratorio la fija para que el ejercicio sea reproducible.
- Salida a internet durante el montaje, para bajar las tres imágenes fijadas. El Paso 1 necesita internet además por una razón menos obvia: una de las dos averías es una etiqueta de imagen que no existe, y el nodo tiene que poder preguntarle al registro para que le contesten que no está. Sin internet ese Pod falla por otro motivo y el diagnóstico cambia. La calificación en sí no necesita internet, solo el clúster vivo y el docker de su máquina.
- El montaje tarda unos dos minutos y medio y deja el clúster YA ROTO, a propósito. Si usted quiere volver a empezar un paso desde cero, corra el teardown completo y vuelva a correr el montaje: las averías se aplican en el montaje, no paso por paso. El teardown borra exactamente el clúster cka-comico-p05 y el directorio ~/cka-comico-lab/p05, nada más.
- Haber leído los Capítulos 11 a 14. Este laboratorio no vuelve a explicar el triángulo de diagnóstico, qué significa cada condición de un nodo, qué es lo Asignable, ni por qué un Service puede tener endpoints y aun así no contestar; le hace operar las cuatro cosas contra un clúster real que ya está enfermo.

## Pasos

El `0N-step.sh` está para que no se quede atascado: lea el paso, intente primero por su cuenta y corra el script cuando quiera comparar. Escribe también el archivo de respuesta que el paso pide, leyendo los valores del clúster vivo.

### 1. Cap. 11: Dos enfermos en La Cuchara de Oro, y no tienen la misma enfermedad (10 pts)

Lo que pasa es que en La Cuchara de Oro hoy no abrió ninguna de las dos cocinas, y el dueño ya está diciendo que "el sistema no sirve". No no no no, tranquilo. El Capítulo 11 fue muy claro con esto: un buen médico no receta antes de examinar, y dos pacientes acostados en la misma sala no tienen por qué tener la misma enfermedad. Aquí hay exactamente dos enfermos, `sancocho` y `bandeja`, los dos en el namespace `cuchara-de-oro`, los dos en 0/1, y las dos enfermedades son distintas.

Empiece por el termómetro, que es `kubectl get pods`. Ahí ya se le nota la primera pista: la columna STATUS no dice lo mismo en los cuatro Pods. Siga con la historia clínica, que es `kubectl describe`, y baje hasta los eventos: el kubelet deja escrito ahí, en español técnico pero en español, qué fue exactamente lo que intentó hacer y por qué no pudo. Uno de los dos le va a hablar de una imagen que salió a buscar al registro y le contestaron que no existe. El otro le va a hablar de algo que el Pod necesitaba tener a la mano antes de arrancar el contenedor, y que no estaba en la casa.

Y aquí viene la parte que separa al que diagnostica del que adivina. Los dos arreglos son fáciles UNA VEZ que usted sabe cuál es cuál. El difícil es no confundirlos, porque el que adivina hace lo mismo en los dos y daña el que estaba a medio andar. Al `sancocho` le falta la imagen correcta: la buena es la misma que ya está usando su compañero de sala, fijada por digest, y usted la puede leer del propio clúster en vez de inventársela. A la `bandeja` le falta apuntar al ConfigMap que sí existe, y ojo con la trampa: el precio del almuerzo se lee de la carta, no se aprende de memoria. Si usted borra el `valueFrom` y escribe 15000 a mano en el manifiesto, el Pod arranca, el número sale bien, el dueño queda contento, y usted no arregló nada. La comprobación se va a dar cuenta.

ENTREGABLE: los dos Deployments en 2/2, y el archivo `~/cka-comico-lab/p05/01-respuesta.txt`, exactamente 4 líneas:

```text
RAZON_SANCOCHO=<la razón estable que muestra el contenedor de sancocho, tal cual la escribe Kubernetes>
RAZON_BANDEJA=<la razón que muestra el contenedor de bandeja, tal cual la escribe Kubernetes>
RECURSO_FALTANTE=<el nombre exacto del objeto que el manifiesto de bandeja pedía y que no existe>
TAG_INEXISTENTE=<solo la etiqueta de imagen que sancocho pedía y que el registro no tiene, sin el nombre del repositorio>
```

<details>
<summary>Qué debería ver</summary>

Antes de arreglar nada, kubectl get pods muestra cuatro Pods en 0/1 con DOS estados distintos: los dos de sancocho en ImagePullBackOff y los dos de bandeja en CreateContainerConfigError. El mensaje del primero dice que no pudo resolver la referencia docker.io/library/nginx:1.29-alpinita, que no existe; el del segundo dice, textualmente, configmap 'la-carta-vieja' not found. Ojo con un detalle honesto: en los primeros segundos sancocho puede mostrar ErrImagePull en vez de ImagePullBackOff. Es la misma falla antes de que el kubelet entre en compás de espera; el estado estable, y el que usted debe anotar, es ImagePullBackOff. Después del arreglo los dos Deployments quedan en 2/2 y printenv imprime 15000.

</details>

```bash
./01-step.sh
./01-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 2. Cap. 12: El nodo que dejó de contestar la llamada de la central (10 pts)

Lo que pasa es que en el taller uno aprende una cosa muy rápido: que el carro no encienda no significa que el motor esté fundido. A veces es la batería, a veces es que se quedó sin gasolina, y a veces es simplemente que el alternador dejó de reportarle al tablero, y el tablero, que no sabe nada por su cuenta, se puso a prender testigos rojos.

Eso es un nodo en NotReady. El Capítulo 12 lo dijo: el API server no vigila los nodos, los nodos se reportan solos. El kubelet de cada nodo le manda su estado a la central cada tantos segundos, y si la central deja de recibir ese reporte durante un rato, no concluye que el nodo esté muerto, concluye algo mucho más honesto: que ya no sabe. Por eso las condiciones no quedan en False, quedan en `Unknown`, y por eso la razón que verá escrita habla de que el kubelet dejó de reportar, no de que el nodo se haya incendiado.

Su trabajo aquí tiene dos mitades y la segunda es la que casi nadie hace. La primera mitad es de kubectl: encontrar cuál de los tres nodos es, y leerle las condiciones con `describe node` hasta tener la razón y el mensaje exactos. La segunda mitad ya no es de kubectl, porque kubectl no puede arreglar un servicio del sistema operativo. Toca bajar al piso del nodo. En un clúster kind cada nodo es un contenedor de Docker que corre systemd adentro, así que la puerta de entrada es `docker exec` y una vez adentro usted está en un Linux normal, con `systemctl` y con `journalctl`, exactamente como en el Capítulo 12.

Y una advertencia sobre el atajo, porque va a estar ahí tentándolo: si usted borra el nodo del clúster, `kubectl get nodes` deja de mostrarle el problema. El testigo rojo se apaga. El carro sigue varado. La comprobación cuenta los nodos y le va a pedir tres.

ENTREGABLE: los tres nodos en Ready con su kubelet corriendo, y el archivo `~/cka-comico-lab/p05/02-respuesta.txt`, exactamente 3 líneas:

```text
NODO_CAIDO=<el nombre exacto del nodo que estaba NotReady>
RAZON_CONDICION=<la razón que Kubernetes escribió en la condición Ready de ese nodo>
SERVICIO_CULPABLE=<el nombre del servicio de systemd que estaba apagado adentro del nodo>
```

<details>
<summary>Qué debería ver</summary>

kubectl get nodes muestra dos nodos Ready y uno NotReady. En describe node, las cuatro condiciones de ese nodo (MemoryPressure, DiskPressure, PIDPressure y Ready) quedan todas en Unknown, con la razón NodeStatusUnknown y el mensaje 'Kubelet stopped posting node status.'. Adentro del contenedor del nodo, systemctl is-active kubelet responde inactive y sale con código distinto de cero. Después de systemctl start kubelet responde active, y el nodo vuelve a Ready en unos diez segundos. Fíjese en el orden de los tiempos: el nodo tardo cerca de un minuto en pasar a NotReady cuando el kubelet murió, pero vuelve a Ready casi de inmediato cuando revive, porque lo primero es un vencimiento de plazo y lo segundo es un reporte nuevo.

</details>

```bash
./02-step.sh
./02-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 3. Cap. 13: El bulto que pidió más bodega de la que la bodega tiene (10 pts)

Lo que pasa es que en la bodega del barrio hay una regla que nadie escribió pero todo el mundo respeta: uno no manda el camión antes de preguntar si el bulto cabe. Y el bulto que llegó hoy, que se llama `arroz`, pidió una bodega que no existe en esta cuadra ni en la siguiente.

Mire el síntoma con calma, porque este no se parece a los otros dos. El Pod no está reiniciándose, no está fallando, no está descargando nada. Está en `Pending`, que quiere decir que ni siquiera lo han programado en ningún nodo. Nadie lo rechazó por malo: lo rechazó el planificador por grande. Y el planificador, que es de buena crianza, deja dicho exactamente por qué en un evento, nodo por nodo. Vaya y léalo, porque ahí está media respuesta.

La otra media respuesta está en el nodo, y aquí es donde el Capítulo 13 le pidió que hiciera una distinción que se le olvida a mucha gente: Capacidad no es lo mismo que Asignable. La Capacidad es lo que trae la máquina; lo Asignable es lo que queda después de que el nodo se reservó su parte para el sistema operativo y para el propio kubelet. El planificador solo mira lo Asignable. Léalo usted mismo con `describe node` o con jsonpath, porque el número depende de SU máquina y por eso este texto no se lo puede decir.

Y ahora la trampa, que en este paso es especialmente cómoda: usted puede borrar el bloque `resources` completo, el Pod arranca de una y todo se ve verde. No no no no. Un Pod sin peticiones es un Pod que el planificador cree que no pesa nada, y ese es el que después se lleva por delante al nodo entero. Arreglar aquí significa poner un número que quepa, no quitar el número. La comprobación exige que las dos peticiones sigan declaradas, con un piso razonable y con el techo real del nodo donde el Pod aterrizó.

ENTREGABLE: el Deployment `arroz` en 1/1 con sus peticiones puestas, y el archivo `~/cka-comico-lab/p05/03-respuesta.txt`, exactamente 3 líneas:

```text
EVENTO=<la razón del evento con que el planificador rechazó el Pod, tal cual la escribe Kubernetes>
CPU_ASIGNABLE=<el valor de cpu Asignable del nodo cka-comico-p05-worker, tal cual lo reporta la API>
MEMORIA_ASIGNABLE=<el valor de memoria Asignable de ese mismo nodo, tal cual lo reporta la API, con su sufijo>
```

<details>
<summary>Qué debería ver</summary>

El Pod de arroz queda en Pending, sin nodo asignado, con la condición PodScheduled en False y razón Unschedulable. El evento del planificador es de tipo Warning y su razón es FailedScheduling, con un mensaje que empieza en '0/3 nodes are available:' y enumera por que se cae cada nodo: uno por un taint que el Pod no tolera (el nodo del control plane) y los otros dos por Insufficient cpu e Insufficient memory. Lo que pida su nodo Asignable depende de su maquina, y ese es justamente el punto: la respuesta correcta no esta en este texto, esta en su clúster. Después del ajuste el Pod pasa a Running en pocos segundos, ya con nodo asignado.

</details>

```bash
./03-step.sh
./03-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 4. Cap. 14: El teléfono timbra, la portería está, y la llamada no entra (10 pts)

Lo que pasa es que en el conjunto residencial nadie contesta el citófono, y ya hay tres versiones circulando: que se cayó la red, que Justo Segura, el celador, se fue a almorzar, y que "eso nunca ha servido". El Capítulo 14 le dejó el procedimiento para no entrar en esa conversación: uno no adivina, uno recorre la ruta en orden, y en cada punto pregunta una sola cosa.

El primer punto es si hay alguien atendiendo. Mire los Pods del Deployment `portero`: si están 1/1 y Running, deje de culpar a la aplicación, porque la aplicación está de pie. El segundo punto es el directorio, que en Kubernetes es el EndpointSlice del Service. Aquí hay una sorpresa que vale más que todo el paso: el directorio NO está vacío. Tiene las dos direcciones anotadas. Un directorio vacío significa que el selector no encuentra a nadie; un directorio lleno significa que el selector está bien y el problema está más adelante. Mire con calma la columna del puerto de ese EndpointSlice, y después mire qué puerto declara de verdad el contenedor. Ahí está el número mal anotado: alguien escribió en el directorio una extensión que en ese apartamento nadie contesta.

Arréglelo y vuelva a llamar. Y aquí es donde este paso deja de ser un ejercicio de puerto y se vuelve un ejercicio de carácter, porque la llamada SIGUE sin entrar. No no no no, usted no se equivocó: es que hay dos capas, y esa es la vida real. La segunda es la portería silenciosa, la `NetworkPolicy`, que no rechaza a nadie con un mensaje sino que simplemente no deja pasar y lo deja a uno esperando hasta que se cansa. Léala. Va a ver que autoriza a un tipo de residente y que el que está llamando no es de esos.

Y ahora la tentación, que en este paso es enorme y toma medio segundo: borre la NetworkPolicy y el citófono suena. Suena de verdad, da 200, se ve perfecto. Y usted acaba de quitarle la puerta a un edificio para que entrara una visita. La comprobación levanta un Pod nuevo, con una etiqueta que nadie autorizó, y le pregunta a la portería si lo deja entrar. Si lo deja, usted no arregló la llamada: abrió el conjunto.

ENTREGABLE: un curl desde el Pod `visitante` que devuelva 200 contra el nombre DNS del Service, con la NetworkPolicy todavía en pie y todavía filtrando, y el archivo `~/cka-comico-lab/p05/04-respuesta.txt`, exactamente 3 líneas:

```text
TARGETPORT_MALO=<el targetPort que el Service traía y que no correspondía a ningún puerto del contenedor>
TARGETPORT_BUENO=<el puerto que el contenedor de portero declara de verdad>
POLITICA_CULPABLE=<el nombre exacto del objeto NetworkPolicy que estaba bloqueando la llamada>
```

<details>
<summary>Qué debería ver</summary>

Al principio el curl desde el Pod visitante se queda colgado y termina en 'Connection timed out', con código 000 y salida 28 de curl. Los dos Pods de portero están 1/1 y Running, y el EndpointSlice del Service SI tiene las dos direcciones IP anotadas: el directorio no esta vacío, esta mal escrito. La columna PORTS del EndpointSlice dice 8080 mientras el contenedor declara el puerto 80. Después de corregir targetPort a 80, el EndpointSlice pasa a decir 80 y el curl SIGUE dando timeout, porque falta la segunda capa. La NetworkPolicy solo-los-de-la-casa autoriza unicamente a Pods con la etiqueta app=residente, y el visitante tiene app=visitante. Cuando usted agrega esa autorización sin borrar la política, el curl responde 200 de una vez.

</details>

```bash
./04-step.sh
./04-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

## Cómo correrlo

```bash
./00-setup.sh
./01-step.sh && ./01-check.sh
./02-step.sh && ./02-check.sh
./03-step.sh && ./03-check.sh
./04-step.sh && ./04-check.sh
./99-teardown.sh
```

## Si algo falla

- **Síntoma (step 1):** Los Pods de sancocho muestran ErrImagePull y no ImagePullBackOff, y la comprobación falla
  **Qué hacer:** Las dos son la misma falla en dos momentos distintos. ErrImagePull es el intento que acaba de fracasar; ImagePullBackOff es el kubelet diciendo que ya se cansó de reintentar y va a esperar antes del próximo intento. El estado estable, el que usted ve un minuto después del montaje y el que la comprobación pide, es ImagePullBackOff. Si le sale el otro, espere treinta segundos y vuelva a mirar.

- **Síntoma (step 1):** Arreglé la imagen pero el Deployment sancocho se queda a medio camino, con un Pod nuevo y uno viejo
  **Qué hacer:** Eso es la actualización progresiva haciendo su trabajo: el Deployment no mata al viejo hasta que el nuevo esté listo. Con la imagen buena, el nuevo queda listo en segundos y el viejo se va solo. Use kubectl rollout status deployment/sancocho para esperar en vez de mirar get pods a cada rato, y si se queda ahí más de dos minutos revise con describe que el Pod nuevo no esté fallando por una razón distinta a la que usted arregló.

- **Síntoma (step 2):** Prendí el kubelet y systemctl dice active, pero el nodo sigue apareciendo NotReady
  **Qué hacer:** Deje pasar entre cinco y quince segundos. El nodo no vuelve a Ready por el hecho de que el proceso arranque, vuelve cuando el primer reporte nuevo llega al API server y este actualiza la condición. Use kubectl wait --for=condition=Ready node/<nombre> --timeout=180s en vez de mirar get nodes a cada rato. Si pasados dos minutos sigue igual, mire journalctl -u kubelet adentro del nodo: ahí queda escrito si el proceso arrancó y se murió otra vez.

- **Síntoma (step 2):** docker exec me responde que no encuentra el contenedor del nodo
  **Qué hacer:** El contenedor se llama igual que el nodo, y ese nombre sale de kubectl get nodes: cka-comico-p05-worker2. Confirme con docker ps que ese contenedor está corriendo. Si no aparece, lo que se cayó no fue el kubelet sino el contenedor entero del nodo, y en ese caso el arreglo es docker start con ese mismo nombre, no systemctl. Es una avería distinta de la que este paso le puso, así que revise que no haya corrido un docker rm por error.

- **Síntoma (step 3):** Anoté la memoria Asignable como 62Gi y la comprobación falla
  **Qué hacer:** La comprobación compara texto exacto contra lo que devuelve la API, y la API no redondea ni convierte: reporta la memoria en la unidad en que la tiene, por ejemplo 65246152Ki. Copie el valor tal cual, con su sufijo, de kubectl get node <nombre> -o jsonpath='{.status.allocatable.memory}'. Lo mismo con la cpu: si la API dice 24, escriba 24, no 24000m.

- **Síntoma (step 3):** Bajé la petición pero el Pod sigue en Pending
  **Qué hacer:** Mire el evento otra vez, porque el mensaje del planificador cambia cuando cambia la razón. Este Deployment trae un nodeSelector que lo fija al nodo cka-comico-p05-worker a propósito, para que la avería del Paso 2 no le contamine este paso, así que el único nodo que le sirve es ese: si el número todavía no cabe ahí, sigue Pending aunque quepa en otro. Y confirme que el patch de verdad se aplicó, con kubectl get deployment arroz -o jsonpath del bloque de requests: un patch mal escrito devuelve error y no cambia nada.

- **Síntoma (step 4):** Corregí el targetPort y el curl sigue en timeout, y ya no sé si el arreglo sirvió
  **Qué hacer:** Confirme la capa que acaba de arreglar sin depender del curl: mire la columna PORTS de kubectl get endpointslices, que debe haber cambiado de 8080 a 80 en pocos segundos. Si ya dice 80, esa capa está buena y lo que falta es la otra. Ese es justamente el punto del paso: hay dos fallas apiladas y arreglar la primera no cambia el síntoma. Siga con kubectl get networkpolicy en ese namespace.

- **Síntoma (step 4):** El curl responde 'Could not resolve host' en vez de quedarse colgado
  **Qué hacer:** Eso ya no es la portería ni el puerto, eso es la central telefónica: el DNS del clúster. Un timeout significa que el nombre se resolvió y la conexión no pasó; un error de resolución significa que ni siquiera hubo a quién llamar. Revise que los Pods de CoreDNS estén Running con kubectl -n kube-system get pods -l k8s-app=kube-dns, y confirme que está usando el nombre completo portería.el-barrio.svc.clúster.local o que está corriendo el curl desde un Pod del mismo namespace.

## Para ir más lejos

- Vuelva al Paso 1 y rompa la bandeja de otra forma: deje el nombre del ConfigMap correcto pero cambie la LLAVE por una que no existe. Prediga por escrito, antes de aplicar nada, si la razón que va a ver será la misma CreateContainerConfigError o una distinta, y después compruébelo. Anote qué esperaba y qué pasó.
- En el Paso 2, en vez de prender el kubelet de una, deje el nodo NotReady y ponga en ese nodo un Deployment con una réplica. Observe cuánto tarda el planificador en decidir y qué evento deja. Después mida el otro lado: con el nodo sano, corra kubectl drain sobre él con las banderas que el Capítulo 12 explica y vea a dónde se van los Pods. Es la diferencia entre un nodo que se cayó y un nodo que usted saca de servicio a propósito.
- En el Paso 3, en vez de bajar la petición, súbale las réplicas al Deployment arroz hasta que la SUMA de las peticiones pase de lo Asignable del nodo. Va a ver que unas réplicas arrancan y otras se quedan en Pending, con el mismo evento. Eso le enseña que el planificador no mira una petición contra el nodo vacío, la mira contra lo que ya está reservado. Compárelo con la sección de recursos Asignados que imprime describe node.
- En el Paso 4, haga la comprobación al revés: en vez de autorizar la etiqueta del visitante en la política, póngale al Pod visitante la etiqueta que la política ya autorizaba. Confirme que el curl también da 200 por ese camino y que el Pod intruso sigue bloqueado. Los dos arreglos son válidos porque los dos respetan el control; escriba en tres líneas cuál preferiría en producción y por qué.

## Referencias

- Kubernetes documentation, Debug Pods. The describe-plus-events procedure Step 1 follows, and the reference for Pending, ImagePullBackOff and container configuration failures. https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
- Kubernetes documentation, Troubleshooting Clusters. The cluster-level triage Step 2 follows, including reading node state before touching any node. https://kubernetes.io/docs/tasks/debug/debug-cluster/
- Kubernetes documentation, Node Status. Documents the node conditions, their Unknown state and the node-status reporting Step 2 diagnoses. https://kubernetes.io/docs/reference/node/node-status/
- Kubernetes documentation, Nodes. Documents node registration, heartbeats and the grace period that makes a node flip to NotReady about a minute after its kubelet stops. https://kubernetes.io/docs/concepts/architecture/nodes/
- Kubernetes documentation, Reserve Compute Resources for System Daemons. Documents why Allocatable is smaller than Capacity, the distinction Step 3 is built on. https://kubernetes.io/docs/tasks/administer-cluster/reserve-compute-resources/
- Kubernetes documentation, Resource Management for Pods and Containers. Documents requests and limits and how the scheduler uses requests, the basis of Step 3. https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- Kubernetes documentation, Debug Services. The ordered service-path procedure Step 4 follows: Pods ready, endpoints present, ports matching, then network policy. https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
- Kubernetes documentation, Service. Documents port versus targetPort, the exact mismatch Step 4 injects. https://kubernetes.io/docs/concepts/services-networking/service/
- Kubernetes documentation, EndpointSlices. Documents the object Step 4 reads to prove the Service selector is fine and the port is not. https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
- Kubernetes documentation, Network Policies. Documents ingress rules and the deny-by-default behavior Step 4 diagnoses, and states that the CNI must implement them for them to have any effect. https://kubernetes.io/docs/concepts/services-networking/network-policies/
- kind documentation, Quick Start. Documents multi-node cluster configuration and the --kubeconfig flag this lab uses for isolation. https://kind.sigs.k8s.io/docs/user/quick-start/
- kind release v0.32.0. Source of the pinned kindest/node:v1.36.1 image digest this lab runs on, verified 2026-08-21. https://github.com/kubernetes-sigs/kind/releases/tag/v0.32.0

---

_Hecho con ❤️ por Luis Felipe Ariza Vesga._
