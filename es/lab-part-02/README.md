# Parte II - Laboratorio: cambiar la receta sin cerrar La Cuchara de Oro, devolverse cuando reclaman, la mesa reservada que solo entra con brazalete, el pedido que no cabe en ninguna cocina, y la carta que el cocinero lee por dentro

- Tiempo: 55 min
- Puntos: 40

## Objetivo

Este es un laboratorio Exam-Style: cada paso le dice solo el objetivo y el estado final que se califica, y la secuencia exacta de comandos vive en el script NN-step.sh de ese paso para que usted la revele después de haber intentado primero por su cuenta. El Paso 1 le hace operar el ciclo completo de un rollout (crear un Deployment con una imagen fijada, cambiarle la imagen a una segunda imagen fijada, mirar el estado y el historial, y devolverse con rollout undo), y la calificación exige que la imagen viva sea otra vez la original, que el número de revisión del Deployment sea al menos 3, y que todas las réplicas estén listas (Capítulo 4). El Paso 2 le hace reservar un nodo con un taint dedicated=cuchara-de-oro:NoSchedule y meter ahí un Deployment que traiga la tolerancia correcta y además apunte a ese nodo; la trampa está nombrada de frente: quitar el taint hace desaparecer el síntoma y hace fallar el paso, porque la comprobación verifica que el taint siga puesto y monta su propia sonda sin tolerancia que tiene que quedar en Pending (Capítulo 5). El Paso 3 le hace pedir más memoria de la que tiene cualquier nodo, ver el Pod parado en Pending con su evento FailedScheduling, y después arreglarlo bajando el pedido a un valor sensato; la comprobación no le cree al arreglo por sí solo: vuelve a lanzar ella misma un pedido descomunal calculado sobre la memoria real de sus nodos y exige que ese sí quede en Pending (Capítulo 5). El Paso 4 le hace consumir un ConfigMap como variables de entorno y un Secret montado como archivo dentro de un Pod, y la comprobación entra al contenedor con kubectl exec en el momento de calificar y compara lo que hay adentro contra los objetos vivos y contra lo que usted anotó (Capítulo 5). Ninguna comprobación lee su historial de comandos: todas vuelven a consultar el clúster, y dos de ellas crean recursos nuevos de prueba y los borran para confirmar que el sustrato de verdad hace lo que el laboratorio asume.

## Prerrequisitos

- Una máquina Linux con kind, kubectl y Docker en el PATH, y con al menos 4 GB de RAM libres. Este laboratorio levanta su PROPIO clúster kind de tres nodos llamado cka-comico-p02 y escribe su kubeconfig en un archivo privado, ~/cka-comico-lab/p02/kubeconfig, que no es el suyo de siempre. Nunca toca ~/.kube/config, ni su contexto actual, ni ningún otro clúster que usted ya tenga corriendo. Por eso TODOS los comandos del laboratorio llevan --kubeconfig; si se le olvida el flag una sola vez, kubectl le apunta a otro clúster y usted no se entera.
- Tres nodos, no uno. El clúster se crea con un archivo de configuración de kind que declara un control-plane y dos workers, porque los Pasos 2 y 3 necesitan más de un nodo para que un taint y una falta de memoria signifiquen algo. En un clúster de un solo nodo estos dos pasos no se pueden demostrar.
- Acceso a internet en el momento de montar el laboratorio: kind descarga la imagen de nodo y los Pods descargan las dos imágenes de nginx fijadas por digest. La calificación en sí no necesita internet, solo el clúster vivo.
- VERSIONES FIJADAS, verificadas el 2026-08-21 en esta misma máquina. kind v0.32.0 y kubectl v1.36.1. Imagen de nodo kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, que es la imagen por defecto que trae kind v0.32.0 y que este laboratorio declara explícitamente en el archivo de configuración para que no dependa de la versión de kind que usted tenga. Confirme lo que de verdad quedó instalado con kind version y kubectl version --client, nunca de memoria, y confirme la versión real de sus nodos con kubectl get nodes.
- DOS imágenes de contenedor fijadas por digest, verificadas el 2026-08-21 contra Docker Hub. La vieja, nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236, y la nueva, nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de. Son dos porque el Paso 1 necesita algo real a lo que cambiarse y desde lo cual devolverse. Un tag es mutable, un digest no, y por eso la comprobación del Paso 1 compara la cadena completa con digest y no el tag suelto.
- Haber leído los Capítulos 4 y 5. Este laboratorio no vuelve a explicar qué es un ReplicaSet, qué diferencia hay entre un request y un limit, ni para qué sirve una tolerancia; le hace operar las cinco cosas contra un clúster real y le califica el estado final.

## Pasos

El `0N-step.sh` está para que no se quede atascado: lea el paso, intente primero por su cuenta y corra el script cuando quiera comparar. Escribe también el archivo de respuesta que el paso pide, leyendo los valores del clúster vivo.

### 1. Cap. 4: Cambiar la receta con La Cuchara de Oro llena, y devolverse cuando el cliente reclama (10 pts)

El Capítulo 4 dejó La Cuchara de Oro abierta y la lección puesta: usted no cierra el negocio para cambiar la receta del día. Va sacando un cocinero, mete al de la receta nueva, comprueba que sí está sirviendo, y solo entonces saca al siguiente. Lo que pasa es que en Kubernetes ese baile no lo hace usted a mano: lo hace el Deployment creando un ReplicaSet nuevo y bajándole las réplicas al viejo, uno a uno, mientras La Cuchara de Oro sigue llena.

Este paso le hace operar el ciclo entero, con las dos mitades que la gente casi nunca practica junta. La primera mitad es el cambio: crear el Deployment con la imagen vieja fijada por digest, y después cambiarle la imagen a la nueva. La segunda mitad es la que le salva el turno el día que la receta nueva sale mala: rollout undo, y La Cuchara de Oro vuelve a la receta anterior sin cerrar tampoco.

No no no no, y aquí viene el detalle que confunde a todo el mundo: después del undo, rollout history NO le muestra tres filas. Le muestra dos, la 2 y la 3. La revisión 1 no desapareció ni se borró: Kubernetes reutilizó ese mismo ReplicaSet viejo y le puso la anotación de revisión 3, porque es el mismo conjunto de Pods al que usted se devolvió. Si usted esperaba tres filas y ve dos, no se asuste y no vuelva a hacer nada: mire la anotación de revisión del Deployment, que sí dice 3, y mire los dos ReplicaSets con sus números de revisión. Ahí está toda la historia.

Y sí, se lo digo antes de que se le ocurra: borrar el Deployment y crearlo de nuevo con la imagen vieja deja todo viéndose igual y no pasa este paso. Está calificado a propósito para que no pase.

ENTREGABLE: el Deployment receta-del-dia corriendo en el namespace cuchara-de-oro con la imagen vieja y sus tres réplicas listas, y el archivo `~/cka-comico-lab/p02/01-respuesta.txt`, exactamente 3 líneas:

```text
REVISION_ACTUAL=<lo que dice la anotación deployment.kubernetes.io/revisión del Deployment ahora>
IMAGEN_ACTUAL=<la cadena completa de la imagen que corre ahora, con tag y digest>
REPLICAS_LISTAS=<lo que dice .status.readyReplicas ahora>
```

<details>
<summary>Qué debería ver</summary>

Después de crear, la anotación de revisión dice 1. Después de set image dice 2, y rollout status va narrando el reemplazo réplica por réplica hasta que imprime que el Deployment se desplegó con éxito. En ese momento rollout history lista DOS filas, la revisión 1 y la 2. Después de rollout undo la anotación dice 3, la imagen viva vuelve a terminar en el digest a8b39bd9, y readyReplicas dice 3. Y aquí está la sorpresa que hay que ver con los propios ojos: rollout history DESPUÉS del undo sigue listando dos filas, pero ahora son la 2 y la 3, no la 1 y la 2. La revisión 1 no se perdió, se reutilizó: Kubernetes le volvió a poner al ReplicaSet viejo la anotación de revisión 3. Por eso el listado de ReplicaSets muestra dos objetos, el de la imagen nueva con DESEADAS en 0 y el de la imagen vieja con DESEADAS en 3.

</details>

```bash
./01-step.sh
./01-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 2. Cap. 5: La mesa reservada, y el brazalete que hay que traer puesto para sentarse (10 pts)

El Capítulo 5 habló de las mesas reservadas y del brazalete, y la confusión más cara del examen vive justo ahí. Lo que pasa es que el taint y el nodeSelector NO son la misma cosa ni hacen el mismo trabajo, y la gente los mezcla porque los dos suenan a "dónde va este Pod".

El taint es del nodo y empuja hacia afuera: es el letrero de MESA RESERVADA. Sin brazalete, usted no se sienta ahí, punto. La tolerancia es del Pod y es el brazalete: no lo lleva a ninguna mesa, solamente le da permiso de sentarse en la reservada SI el mesero lo manda para allá. Y el que lo manda para allá es el nodeSelector o la afinidad. Por eso un Pod con tolerancia y sin nodeSelector puede terminar sentado en cualquier mesa del salón: tiene brazalete, pero nadie le dijo que fuera a la reservada.

Este paso le hace poner las tres piezas: el letrero en el nodo, el brazalete en el Pod, y la instrucción de ir para allá. Reserve un worker (nunca el control-plane, que ya viene con su propio taint de fábrica), etiquételo, y despliegue dos réplicas que traigan tolerancia Y destino.

Y ahora la advertencia, de frente y sin letra menuda, porque es la trampa a la que se cae medio mundo cuando algo no arranca: quitar el taint. El día del examen eso le "arregla" el síntoma en cuatro segundos y le anula la pregunta completa, porque lo que le pidieron fue tolerar la reserva, no cancelarla. Aquí este paso está calificado exactamente así: la comprobación revisa que el letrero siga puesto y monta su propio cliente sin brazalete para confirmar que la mesa de verdad lo rechaza.

ENTREGABLE: el worker reservado con su taint puesto, el Deployment turno-de-la-noche con sus dos réplicas listas y las dos corriendo en ese nodo, y el archivo `~/cka-comico-lab/p02/02-respuesta.txt`, exactamente 3 líneas:

```text
NODO_RESERVADO=<el nombre exacto del nodo que usted reservó>
LLAVE_DEL_TAINT=<la llave del taint que le puso>
EFECTO_DEL_TAINT=<el efecto del taint que le puso>
```

<details>
<summary>Qué debería ver</summary>

Antes del taint, la consulta muestra que el control-plane ya trae de fábrica un taint node-role.kubernetes.io/control-plane:NoSchedule y que los dos workers no traen ninguno. Después del taint, el worker escogido reporta exactamente dedicated=cuchara-de-oro:NoSchedule. El rollout del Deployment termina bien, y kubectl get pods -o wide muestra las DOS réplicas con la columna NODE apuntando al mismo worker que usted reservó, ninguna en el otro.

</details>

```bash
./02-step.sh
./02-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 3. Cap. 5: El pedido que no cabe en ninguna cocina, y el cliente parado en la puerta (10 pts)

El Capítulo 5 lo dejó dicho: el request no es un deseo, es una reserva. Lo que pasa es que el planificador no mira cuánta memoria está usando el nodo en este momento, mira cuánta ya prometió. Y si lo que usted pide no cabe en lo que queda prometible de ningún nodo, el Pod no arranca mal ni se cae: simplemente no arranca. Se queda parado en la puerta, en Pending, sin IP y sin nodo, esperando a que aparezca una cocina donde quepa.

Este paso le hace provocar esa situación a propósito y después leerla bien, que es la parte que califica el examen. Primero lea cuánta memoria ofrece de verdad cada nodo, con status.allocatable.memory, no con lo que usted cree que tiene la máquina. Después pida cuatro veces eso. Y ahora venga la parte importante: no se quede mirando el STATUS Pending, que no explica nada. Vaya al mensaje. La condición PodScheduled y el evento FailedScheduling le dicen, con números, cuántos nodos se descartaron por cada razón. Ahí va a ver dos razones distintas conviviendo, y las dos son suyas: unos nodos quedaron por fuera por memoria insuficiente y otros por taints que este Pod no tolera, porque el control-plane trae el suyo de fábrica y el worker del Paso 2 trae el que usted mismo le puso.

No no no no, y aquí está el error que hay que no cometer: la salida de arriba, la de kubectl get pods, dice Pending y ya. Si usted se queda ahí, no sabe si el problema es memoria, CPU, un taint, un volumen o una etiqueta. Los cinco se ven exactamente igual desde afuera. El mensaje es el único que distingue.

Después arréglelo por donde se debe arreglar: bajando el pedido a un valor que sí quepa. Este paso comparte clúster con el Paso 2, así que si ya reservó el worker, el mensaje va a contar ese nodo entre los descartados por taint; eso es correcto y esperado, no lo deshaga.

ENTREGABLE: el Deployment pedido-gigante corriendo con su request bajado, y el archivo `~/cka-comico-lab/p02/03-respuesta.txt`, exactamente 3 líneas:

```text
MEMORIA_PEDIDA_INICIAL=<el valor de memoria descomunal que pidió al principio, tal cual lo escribió, por ejemplo 260984608Ki>
RAZON_DEL_EVENTO=<el valor del campo reason del evento que produjo el Pod parado>
MOTIVO_EXACTO=<la frase de DOS palabras dentro del mensaje que nombra el recurso que se quedó corto, escrita exactamente como la escribe el mensaje>
```

<details>
<summary>Qué debería ver</summary>

La consulta de allocatable le dice cuánta memoria ofrece de verdad cada nodo, y el pedido que usted arma es cuatro veces esa cifra, así que no cabe en ninguno. El Pod aparece con STATUS Pending y con las columnas IP y NODE en <none>, porque nunca fue asignado a ningún nodo. El mensaje de la condición PodScheduled y el evento con reason FailedScheduling dicen los dos lo mismo, en la forma 0/3 nodes are available, y adentro traen la frase Insufficient memory contando cuántos nodos se quedaron cortos, más el conteo de los que quedaron descartados por taints sin tolerar (el control-plane y el worker reservado del Paso 2). Después de bajar el pedido a 64Mi el rollout termina, el Pod aparece Running con IP y NODE llenos, y el Deployment reporta 64Mi.

</details>

```bash
./03-step.sh
./03-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 4. Cap. 5: La carta pegada en la cocina, y el ingrediente que no se dice en voz alta (10 pts)

El Capítulo 5 lo puso así: la receta va pegada en la pared de la cocina y el ingrediente que da el sabor no se dice en voz alta. Lo que pasa es que en Kubernetes eso no es una metáfora bonita, son dos objetos distintos con dos formas distintas de llegar al contenedor, y el examen le va a pedir las dos.

El ConfigMap entra como variables de entorno: el contenedor arranca y ya las tiene ahí, sin haber leído ningún archivo. El Secret entra montado como archivo dentro de una carpeta: el contenedor lo lee cuando quiere. Y hay una diferencia que se le tiene que quedar grabada: las variables de entorno se congelan al arrancar el contenedor, y si usted edita el ConfigMap después, el proceso que ya está corriendo no se entera nunca. El archivo montado sí se actualiza solo, sin reiniciar nada, aunque tarda un rato.

No no no no, y ahora lo que hay que decir en voz alta porque medio mundo lo entiende al revés: un Secret NO está cifrado. Está codificado en base64, que es una forma de escribir bytes, no una forma de esconderlos. Usted mismo lo va a comprobar en este paso: le va a pasar la salida por base64 -d y le va a salir la frase completa, en texto claro, sin que nadie le pida una clave. Lo que de verdad protege un Secret es el RBAC que decide quién puede leerlo y el cifrado en reposo del etcd, no el base64.

Y un detalle que sorprende siempre: cuando haga ls -l en la carpeta montada, sazón.txt no va a ser un archivo, va a ser un enlace simbólico hacia ..data/sazón.txt. Eso es normal y es a propósito: así el kubelet puede cambiar el contenido de un solo golpe sin que nadie lea nunca medio archivo. cat lo lee igual.

ENTREGABLE: el ConfigMap y el Secret creados, el Pod el-cocinero corriendo con el ConfigMap como variables de entorno Y el Secret montado como archivo, y el archivo `~/cka-comico-lab/p02/04-respuesta.txt`, exactamente 3 líneas:

```text
PLATO_EN_EL_CONTENEDOR=<lo que imprime printenv PLATO_DEL_DIA ADENTRO del contenedor>
SAZON_EN_EL_CONTENEDOR=<el contenido completo del archivo montado, leído ADENTRO del contenedor>
RUTA_DEL_SECRETO=<la ruta absoluta del archivo del secreto adentro del contenedor>
```

<details>
<summary>Qué debería ver</summary>

El ConfigMap sale en YAML con sus dos claves en texto plano. El Secret sale con la clave sazón.txt en base64, y el propio kubectl le recuerda con el type Opaque que eso es codificación, no cifrado: el comando con base64 -d le devuelve la frase completa en texto claro sin pedirle ninguna credencial. Adentro del contenedor, printenv PLATO_DEL_DIA imprime sancocho y printenv PORCIONES imprime 40, sin que usted haya escrito esos valores en el manifiesto del Pod. Y ls -l /etc/cuchara-de-oro muestra algo que sorprende la primera vez: sazón.txt no es un archivo, es un enlace simbólico que apunta a ..data/sazón.txt, que es como kubelet monta los secretos para poder actualizarlos de forma atómica. cat lo sigue leyendo sin problema y devuelve exactamente la misma frase que devolvió base64 -d.

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

- **Síntoma (step 1):** rollout status se queda esperando y nunca termina
  **Qué hacer:** Mire los Pods con kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig -n cuchara-de-oro get pods. Si están en ImagePullBackOff, la máquina no está descargando la imagen fijada; revise la conectividad y que el digest esté copiado completo, sin cortes de línea. Si están en Pending, no hay nodo donde quepan: eso es exactamente lo que el Paso 3 le va a enseñar a leer.

- **Síntoma (step 1):** set image responde que no encontró el contenedor que usted nombró
  **Qué hacer:** kubectl create deployment le pone al contenedor el nombre del repositorio de la imagen, no el nombre del Deployment. Con nginx:1.28-alpine el contenedor se llama nginx, y por eso el comando dice nginx=. Confírmelo con kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig -n cuchara-de-oro get deployment receta-del-dia -o jsonpath='{.spec.template.spec.containers[0].name}' en vez de adivinarlo.

- **Síntoma (step 2):** Los Pods quedan en Pending después de aplicar el Deployment
  **Qué hacer:** Lea el mensaje completo con kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig -n cuchara-de-oro describe pod <pod> y mire la sección Events. Si dice untolerated taint, le falta la tolerancia o la escribió con otra llave, otro valor u otro efecto que los del taint. Si dice didn't match Pod's node affinity/selector, el nodeSelector apunta a una etiqueta que el nodo no tiene: confirme la etiqueta real con kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig get node <nodo> --show-labels.

- **Síntoma (step 2):** Las réplicas quedaron repartidas, una en cada worker
  **Qué hacer:** Eso significa que usted puso la tolerancia pero NO puso el destino: el Pod traía brazalete y el planificador lo sentó donde hubiera espacio. La tolerancia autoriza, no dirige. Agregue el nodeSelector (o una nodeAffinity requerida) apuntando al nodo reservado y vuelva a aplicar.

- **Síntoma (step 3):** El Pod gigante NO queda en Pending, arranca sin problema
  **Qué hacer:** Casi siempre es que el valor pedido quedó mal escrito y terminó siendo pequeño. Mi vs M no es lo mismo (1Mi son 1048576 bytes y 1M son 1000000), y un número sin sufijo se interpreta en BYTES, así que memory: 200 son doscientos bytes, no doscientos de nada más. Revise lo que quedó de verdad en el objeto con kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig -n cuchara-de-oro get deployment pedido-gigante -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' y compárelo contra el allocatable de los nodos.

- **Síntoma (step 3):** El evento FailedScheduling ya no aparece cuando va a anotarlo
  **Qué hacer:** Los eventos de Kubernetes tienen vida corta y se van solos. Si ya arregló el Deployment y perdió el mensaje, no reviva el pedido gigante encima del bueno: cree un Deployment aparte, con otro nombre, con el mismo pedido descomunal, léale el mensaje, y bórrelo. Eso es exactamente lo que hace la comprobación cuando lo califica.

- **Síntoma (step 4):** printenv adentro del contenedor no encuentra la variable
  **Qué hacer:** Revise dos cosas, en este orden. Que el ConfigMap esté en el MISMO namespace que el Pod (un ConfigMap de otro namespace no se puede referenciar, y el Pod se queda esperando en CreateContainerConfigError). Y que envFrom esté colgando del contenedor, no del spec del Pod: es spec.containers[].envFrom, un nivel más adentro de donde la gente lo pone la primera vez.

- **Síntoma (step 4):** El archivo del secreto no aparece en la carpeta montada
  **Qué hacer:** El nombre del archivo lo pone la CLAVE del Secret, no el nombre del Secret ni el del volumen. Si usted creó el Secret con --from-literal=sazón=... la clave es sazón y el archivo se llama sazón, sin extensión. Confirme las claves reales con kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig -n cuchara-de-oro get secret receta-secreta -o jsonpath='{.data}' antes de adivinar la ruta.

## Para ir más lejos

- Vuelva al Deployment del Paso 1 y hágale un segundo cambio de imagen, esta vez con --record ya retirado del kubectl moderno: en su lugar anote el motivo con kubectl annotate deployment receta-del-dia kubernetes.io/change-cause='...' antes de cambiar la imagen, y después mire cómo rollout history sí llena la columna CHANGE-CAUSE. Después use rollout undo --to-revision=<n> para devolverse a una revisión concreta en vez de a la anterior, y observe qué número de revisión queda al final.
- Cambie el efecto del taint del Paso 2 de NoSchedule a NoExecute en un nodo donde ya haya Pods corriendo sin la tolerancia correspondiente, y quédese mirando qué les pasa. NoSchedule solo impide que lleguen nuevos; NoExecute expulsa a los que ya estaban. Después agregue tolerationSeconds a la tolerancia y observe que el Pod aguanta ese tiempo antes de ser sacado.
- Cree un ResourceQuota y un LimitRange en el namespace cuchara-de-oro y vuelva a intentar el pedido descomunal del Paso 3. Va a ver una diferencia clave: con una quota el objeto es rechazado en la puerta por el API server, con un mensaje distinto y sin llegar nunca a existir, mientras que sin quota el objeto se crea perfectamente y solo después se queda en Pending. Es la diferencia entre que le nieguen la reserva y que le acepten la reserva pero no haya mesa.
- Edite el ConfigMap del Paso 4 con kubectl edit y cambie el valor de PLATO_DEL_DIA. Después vuelva a hacer printenv adentro del contenedor y confirme que la variable NO cambió. Ahora cambie el valor del Secret y quédese mirando el archivo montado con watch cat: al cabo de un rato sí cambia solo. Ahí tiene, con las manos, la diferencia entre una variable de entorno congelada al arrancar y un volumen que el kubelet sincroniza.

## Referencias

- Kubernetes Project, Deployments. The authority on rolling updates, on rollout undo, and on the deployment.kubernetes.io/revision annotation and revisionHistoryLimit that Step 1 is graded against, including the statement that rolling back reuses the old ReplicaSet rather than creating a new one. https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- Kubernetes Project, kubectl rollout reference. Documents the status, history, undo and --to-revision subcommands used in Step 1 and in the first extension. https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/
- Kubernetes Project, Taints and Tolerations. Documents the kubectl taint syntax including the trailing hyphen that removes a taint, the NoSchedule, PreferNoSchedule and NoExecute effects, the Equal and Exists operators, and tolerationSeconds, the basis for Step 2 and the second extension. https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
- Kubernetes Project, Assigning Pods to Nodes. Documents nodeSelector and node affinity, and states explicitly that a toleration authorizes scheduling onto a tainted node without steering the Pod there, which is the distinction Step 2 grades. https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
- Kubernetes Project, Resource Management for Pods and Containers. Documents memory requests and limits, the Ki/Mi/Gi and K/M/G quantity suffixes, the rule that a suffixless number means bytes, and the statement that the scheduler places a Pod only where the sum of requests fits, the basis for Step 3. https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- Kubernetes Project, Debug Pods. Documents reading a Pending Pod through its events and the FailedScheduling reason rather than through its phase alone, the diagnostic method Step 3 teaches. https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
- Kubernetes Project, Configure a Pod to Use a ConfigMap. Documents envFrom with configMapRef and env with valueFrom.configMapKeyRef, and states that environment variables taken from a ConfigMap are not updated in a running container, used in Step 4 and its extension. https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/
- Kubernetes Project, Secrets. States that Secret data is base64 encoded and not encrypted, that anyone with API read access can retrieve it, and documents mounting a Secret as a volume where each key becomes a file, the basis for Step 4. https://kubernetes.io/docs/concepts/configuration/secret/
- kind Project, Configuration. Documents the kind.x-k8s.io/v1alpha4 Cluster config file, the nodes list with control-plane and worker roles, and the per-node image field used to pin the node image in this lab's setup. https://kind.sigs.k8s.io/docs/user/configuration/
- kind Project, Quick Start. Documents kind create cluster with --name, --config and --kubeconfig, and kind delete cluster, which is what keeps this lab's cluster and kubeconfig isolated from every other cluster on the machine. https://kind.sigs.k8s.io/docs/user/quick-start/

---

_Hecho con ❤️ por Luis Felipe Ariza Vesga._
