# Parte I - Laboratorio: quién trabaja en la finca por una hoja pegada en la pared, la llave que solo abre una casa, la persona y la herramienta que reciben cada una la suya, el cuaderno de obra que se guarda afuera, y el llavero nuevo que no puede más que la llave

- Tiempo: 60 min
- Puntos: 50

## Objetivo

Este es un laboratorio Exam-Style: cada paso le dice solamente el objetivo y el entregable, y la secuencia exacta de comandos vive en el script NN-step.sh de ese paso para que usted la revele después de haber intentado primero por su cuenta. El Paso 1 le hace abrir la finca por dentro y separar dos formas completamente distintas de contratar personal: los componentes que el kubelet levanta leyendo una carpeta de archivos en el nodo, sin que el kube-apiserver los haya autorizado nunca, y los que sí reparte un controlador del clúster (Capítulo 1). El Paso 2 le hace fabricar una llave: una ServiceAccount, una Role que solo deja mirar Pods y un RoleBinding que la entrega dentro de un namespace, y después le exige probar que esa llave abre lo que debe y NO abre ni el verbo prohibido ni la casa del vecino (Capítulo 2). El Paso 3 completa el llavero con las dos clases de portador: una persona, que en Kubernetes no es un objeto sino un certificado de cliente que usted pide con un CertificateSigningRequest y mete en el kubeconfig, y una herramienta, que es una ServiceAccount con su token; a cada una le entrega una Role con verbos distintos y usted prueba con kubectl auth can-i, como administrador con --as y con la llave en la mano, qué abre cada llave y qué no (Capítulo 2). El Paso 4 le hace sacar el respaldo de etcd desde adentro del nodo de control, leyendo las rutas de los certificados del manifiesto estático en vez de copiarlas de memoria, y después sacar el archivo del nodo, porque un respaldo que vive en el mismo disco que el original no es un respaldo (Capítulo 3). El Paso 5 cierra armando un contexto nuevo con el token de la ServiceAccount del Paso 2 y demostrando que el llavero no cambia nada: el contexto nuevo lee Pods, y el mismo contexto es rechazado en el borrado por el mismo RBAC (Capítulos 2 y 3). Ninguna comprobación lee su historial de comandos: las cinco vuelven a consultar el clúster vivo en el momento de calificar, tres de ellas lanzan sus propias preguntas de autorización, y la del respaldo vuelve a abrir el archivo que usted sacó del nodo para confirmar que sigue siendo un snapshot íntegro.

## Prerrequisitos

- Una máquina Linux con kind, kubectl, docker, jq, openssl y curl en el PATH, y con al menos 3 GB de RAM libres para el clúster. El laboratorio crea su propio clúster kind llamado cka-comico-p01 y lo elimina en el teardown.
- AISLAMIENTO, y esto no es un detalle de estilo. El clúster de este laboratorio NUNCA toca su kubeconfig de siempre: se crea con --kubeconfig ~/cka-comico-lab/p01/kubeconfig desde el primer comando, y absolutamente todos los kubectl del laboratorio pasan --kubeconfig y --context explícitamente. Si usted ya tiene otros clústeres de kind corriendo en esta máquina, este laboratorio no los ve, no los modifica y no los borra. Compruébelo usted mismo: después del setup, un kubectl config get-contexts sin --kubeconfig no debe mostrar ni rastro de cka-comico-p01.
- Acceso a internet en el momento de montar el laboratorio: kind descarga la imagen del nodo y el clúster descarga la imagen de pausa fijada por digest que usa el Pod de prueba. La calificación en sí no necesita internet, solo el clúster vivo y el demonio de Docker.
- VERSIONES FIJADAS, verificadas el 2026-08-21 en esta misma máquina. kind v0.32.0. Imagen del nodo kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, que es la imagen por defecto de esa versión de kind y que aquí se pasa explícita con --image porque un tag es mutable y un digest no. Imagen del Pod de prueba registry.k8s.io/pause:3.10@sha256:ee6521f290b2168b6e0935a181d4cff9be1ac3f505666ef0e3c98fae8199917a. Ese nodo trae Kubernetes v1.36.1 y etcd 3.6.8. Confirme lo que de verdad le quedó instalado con kind version y con kubectl version, nunca de memoria: si su nodo trae otra línea de etcd, el Paso 4 le va a cambiar de herramienta y el laboratorio se lo explica ahí mismo.
- Haber leído los Capítulos 1 a 3. Este laboratorio no vuelve a explicar qué hace cada componente del plano de control, ni la diferencia entre Role y ClusterRole, ni cómo se autentica una persona frente a una herramienta, ni para qué sirve un snapshot de etcd; le hace operar las tres cosas contra un clúster real y le califica el estado final.

## Pasos

El `0N-step.sh` está para que no se quede atascado: lea el paso, intente primero por su cuenta y corra el script cuando quiera comparar. Escribe también el archivo de respuesta que el paso pide, leyendo los valores del clúster vivo.

### 1. Cap. 1: Quién está en la nómina de la finca y quién trabaja por una hoja pegada en la pared (10 pts)

El Capítulo 1 le presentó la finca completa: la ventanilla única del kube-apiserver, el cerebro de la obra, y los oficios de cada casa. Lo que pasa es que ahí quedó una pregunta que el capítulo no podía responderle con un dibujo, y es la pregunta que el examen sí le hace: si el kube-apiserver es la ventanilla por la que pasa todo, ¿quién le dio permiso al kube-apiserver para existir?

No no no no, no se lo dio él mismo. Los cuatro componentes del plano de control en un clúster armado con kubeadm no los programa el scheduler ni los administra ningún controlador: el kubelet del nodo se despierta, mira una carpeta de archivos en el disco, y levanta lo que encuentre ahí. Esa carpeta es /etc/kubernetes/manifests, y esos Pods se llaman Pods estáticos. Es el trabajador que no está en la nómina de la oficina, sino que llega porque hay una hoja pegada en la pared que dice qué tiene que hacer.

Y aquí viene el detalle que hace clic y que no se le olvida más: usted igual los ve con kubectl get pods -n kube-system. Eso confunde a mucha gente, porque parece que el clúster sí los administra. Lo que ve ahí es un Pod espejo, una copia de solo lectura que el kubelet publica en el API server para que usted se entere de lo que hay corriendo. La documentación oficial de Pods estáticos es explícita en que borrar ese espejo con kubectl no mata el proceso: el kubelet lo vuelve a publicar, porque la verdad no vive en el API server sino en el archivo.

Su trabajo en este paso es demostrar esa diferencia con datos leídos de su propio clúster, no de una tabla. Entre al contenedor del nodo, cuente los manifiestos, y después mírele a esos Pods dos campos que los delatan: quién figura como dueño en ownerReferences, y qué dice la anotación kubernetes.io/config.source. Después haga lo mismo con kube-proxy, que sí es un DaemonSet de verdad, repartido por un controlador, y compare.

ENTREGABLE: archivo `~/cka-comico-lab/p01/01-respuesta.txt`, exactamente 4 líneas:

```text
MANIFIESTOS_ESTATICOS=<cuántos archivos hay en /etc/kubernetes/manifests del nodo de control>
DUENO_DEL_APISERVER=<el valor de ownerReferences[0].kind en el Pod del kube-apiserver>
FUENTE_DE_CONFIG=<el valor de la anotación kubernetes.io/config.source en ese mismo Pod>
DUENO_DEL_KUBE_PROXY=<el valor de ownerReferences[0].kind en un Pod de kube-proxy>
```

<details>
<summary>Qué debería ver</summary>

La carpeta /etc/kubernetes/manifests del nodo de control contiene cuatro archivos YAML y ni uno más: etcd.yaml, kube-apiserver.yaml, kube-controller-manager.yaml y kube-scheduler.yaml. Los cuatro Pods correspondientes existen en kube-system con el nombre del componente más un guion más el nombre del nodo, y en los cuatro el primer ownerReferences dice Node, no ReplicaSet ni DaemonSet ni nada parecido. La anotación kubernetes.io/config.source de esos mismos Pods dice file. kube-proxy, en cambio, aparece en la lista de DaemonSets, su Pod tiene ownerReferences de tipo DaemonSet, y el último docker exec falla con un error de que /etc/kubernetes/manifests/kube-proxy.yaml no existe. Ese error es el resultado correcto del paso, no un problema.

</details>

```bash
./01-step.sh
./01-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 2. Cap. 2: La llave de la empleada abre esta casa, no la finca entera (10 pts)

El Capítulo 2 dejó el llavero completo sobre la mesa: quién es usted, qué le dejan hacer, y las llaves de los que no son personas. Lo que pasa es que leer los cuatro objetos de RBAC en un cuadro no le enseña la lección de verdad, porque la lección de verdad no está en las definiciones sino en el alcance, y el alcance solo se ve cuando usted intenta abrir una puerta que no le toca.

En este paso usted fabrica la llave de la empleada de la casa. Una ServiceAccount, porque no es una persona sino un proceso. Una Role llamada lector-de-pods con dos verbos y nada más, get y list, sobre pods y nada más. Y un RoleBinding que le entrega esa Role a esa cuenta, dentro del namespace la-casa.

Y después viene la parte que separa a quien entendió de quien copió el YAML. Párese frente a la puerta y pregúntele a Justo Segura, el celador, antes de forzar la cerradura, que para eso existe kubectl auth can-i, y hágalo con --as para preguntar en nombre de otro. Pregunte cuatro cosas y una de yapa: ¿puede leer Pods en la-casa?, ¿puede listarlos?, ¿puede borrarlos?, ¿puede leerlos en la-finca-vecina?, ¿puede hacer todo en la-casa? Las respuestas tienen que salir yes, yes, no, no, no, y cada una de esas tres negativas es una lección distinta.

No no no no, y aquí está el atajo que le va a costar el punto: es tentadísimo entregar la llave con un ClusterRoleBinding porque funciona a la primera y nadie se queja. Funciona demasiado bien: le abre también la finca vecina. Este paso se califica precisamente por lo que NO puede hacer la cuenta, así que el atajo se nota. Lo que sí es válido, y el Capítulo 2 lo dice, es usar una ClusterRole reutilizable entregada con un RoleBinding local: el modelo de llave es genérico, la entrega es de esta casa.

ENTREGABLE: la ServiceAccount, la Role y la entrega aplicadas y en pie en el namespace la-casa, y el archivo `~/cka-comico-lab/p01/02-respuesta.txt`, exactamente 4 líneas:

```text
PUEDE_LEER_EN_LA_CASA=<la respuesta textual de auth can-i get pods en la-casa>
PUEDE_BORRAR_EN_LA_CASA=<la respuesta textual de auth can-i delete pods en la-casa>
PUEDE_LEER_EN_LA_VECINA=<la respuesta textual de auth can-i get pods en la-finca-vecina>
TIPO_DE_ENTREGA=<el Kind del objeto que le entrega los permisos a la cuenta>
```

<details>
<summary>Qué debería ver</summary>

Los tres objetos se crean sin ruido. La Role muestra una sola regla, con apiGroups en la cadena vacía, resources en pods y verbs en get y list, nada más. El roleRef del RoleBinding apunta a Role -> lector-de-pods. Y las cinco preguntas de auth can-i responden, en este orden exacto: yes, yes, no, no, no. Fíjese en que kubectl imprime la palabra yes o la palabra no y además sale con código 0 en el caso afirmativo y con código 1 en el negativo, así que sirve igual de bien para leerlo usted que para meterlo en un script. El auth can-i --list del final le imprime la tabla completa de lo que esa cuenta puede hacer en el namespace, y ahí no aparece delete por ningún lado.

</details>

```bash
./02-step.sh
./02-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 3. Cap. 2: una persona y una herramienta, cada una con su propia llave (10 pts)

El Capítulo 2 le entregó el llavero y le contó que en la finca hay dos clases de portadores de llave: las personas y las herramientas. Lo que pasa es que hay un detalle que sorprende la primera vez: Kubernetes no tiene ningún objeto User. No existe un kubectl create user ni una lista de personas guardada en la API; si usted pide kubectl get users, el servidor responde que no conoce ese tipo de recurso. Una persona existe para el clúster únicamente porque presenta algo que el kube-apiserver sabe validar, y aquí ese algo es un certificado de cliente firmado por la autoridad del propio clúster: el nombre común (CN) del certificado se convierte en el nombre de usuario, y la organización (O), en su grupo. La herramienta, en cambio, sí es un objeto del clúster, una ServiceAccount, y su credencial es un token que se pide con kubectl create token.

En este paso usted emite las dos llaves y las reparte dentro de una sola casa, la-casa, con verbos distintos. Para la persona, marcela, siga el procedimiento documentado para un usuario normal: genere con openssl una llave privada y una solicitud de firma con CN marcela y O cocina, envíela al clúster como un CertificateSigningRequest con signerName kubernetes.io/kube-apiserver-client y usages client auth, apruébela con kubectl certificate approve, extraiga el certificado emitido de .status.certificate y agréguelo a ESTE kubeconfig con config set-credentials y config set-context. Para la herramienta, el-medidor, cree la ServiceAccount. Después entregue a cada una su Role con un RoleBinding: marcela recibe una Role llamada encargada con get, list, create y delete sobre Pods; el-medidor, una Role distinta llamada medidor con get, list y watch sobre Pods. El RoleBinding de marcela nombra un sujeto de tipo User, que es justamente un nombre sin objeto detrás.

Y pruébelo con los dos métodos que va a usar el día del examen. Primero como administrador, preguntando en nombre de otro con --as, que para la herramienta es system:serviceaccount:la-casa:el-medidor. Después con la llave en la mano, usando el contexto marcela. Fíjese en un momento revelador: antes de entregar las Role, marcela ya está autenticada, auth whoami la reconoce, y aun así recibe Forbidden. Justo Segura, el celador, la reconoce en la puerta, pero reconocerla no le abre ninguna casa: autenticar (quién es usted) y autorizar (qué le dejan hacer) son dos puertas distintas. La documentación oficial del procedimiento está en https://kubernetes.io/docs/tasks/tls/certificate-issue-client-csr/ y la de los tipos de firmante en https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/.

ENTREGABLE: el CertificateSigningRequest marcela aprobado, el contexto marcela dentro de `~/cka-comico-lab/p01/kubeconfig` con el certificado emitido, la ServiceAccount el-medidor, las dos Role y los dos RoleBinding en la-casa, y el archivo `~/cka-comico-lab/p01/03-respuesta.txt`, exactamente 4 líneas:

```text
USUARIO_AUTENTICADO=<el Username que responde auth whoami con el contexto marcela>
FIRMANTE_DE_LA_CSR=<el signerName del CertificateSigningRequest>
LA_PERSONA_PUEDE_BORRAR=<la respuesta textual de auth can-i delete pods en la-casa usando el contexto marcela>
LA_HERRAMIENTA_PUEDE_BORRAR=<la respuesta textual de auth can-i delete pods en la-casa usando el token de el-medidor>
```

<details>
<summary>Qué debería ver</summary>

El primer comando falla con error: the server doesn't have a resource type "users": en Kubernetes no existe el objeto User. openssl genera la llave privada y la solicitud de firma sin imprimir nada relevante. El CertificateSigningRequest se crea y aparece primero como Pending, y tras kubectl certificate approve cambia a Approved,Issued. openssl x509 muestra el certificado emitido con subject O = cocina, CN = marcela y como issuer CN = kubernetes, es decir, la autoridad del propio clúster. Con el contexto marcela, auth whoami responde Username marcela y el grupo cocina más system:authenticated, y sin embargo get pods termina en Error from server (Forbidden) con el mensaje User "marcela" cannot list resource "pods": la persona ya está autenticada y todavía no está autorizada. Después de crear las dos Role y los dos RoleBinding, el bucle de can-i imprime, en orden, para marcela y para el-medidor: get yes yes, create yes no, delete yes no, watch no yes; y las dos preguntas sobre la-finca-vecina responden no. Con la llave de marcela en la mano, delete pods responde yes, watch pods responde no, get pods en la-finca-vecina responde no, y get pods lista la-alarma. Con el token, auth whoami responde system:serviceaccount:la-casa:el-medidor, get pods lista la-alarma y delete responde no.

</details>

```bash
./03-step.sh
./03-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 4. Cap. 3: El cuaderno de obra se guarda fuera de la obra, o no es respaldo (10 pts)

El Capítulo 3 lo dijo tal cual: etcd es el cuaderno de obra donde queda anotado el estado real de la finca, y como es el único que existe, es lo que más falta hace respaldar. Lo que pasa es que sacar ese respaldo tiene tres detalles que se olvidan en ese orden, y este paso lo obliga a los tres.

El primero es de dónde salen las rutas de los certificados. etcd no le habla a nadie sin TLS mutuo, ni siquiera al dueño de la finca, así que el comando lleva tres banderas de certificado. La tentación es copiarlas de memoria o de un blog. No no no no: usted las lee del manifiesto estático de etcd, el mismo archivo del Paso 1, que es la única fuente que no le va a mentir sobre su propio clúster. Un clúster armado a mano, o uno con los certificados en otra ruta, y su comando de memoria falla en el examen.

El segundo es cuál herramienta. La documentación oficial de Kubernetes le da el comando con ETCDCTL_API=3 y etcdctl, y así fue durante años. En esta máquina, con etcd 3.6.8, usted va a descubrir algo con las manos: el contenedor de etcd es una imagen distroless, no tiene shell, así que no hay dónde poner ese prefijo de variable de entorno, y de todas formas ya no hace falta porque etcdctl 3.6 habla v3 de nacimiento. Y hay más: pídale la ayuda a etcdctl snapshot y va a ver que solo le queda save. status y restore se mudaron a etcdutl, la herramienta pensada para trabajar directo sobre archivos de datos sin necesidad de un etcd corriendo, exactamente como se lo anunció el Capítulo 3. Lo peor de ese cambio es que etcdctl snapshot status no le da un error: le imprime la ayuda y sale con código 0, o sea que en un script pasaría como si hubiera funcionado.

El tercero es dónde queda el archivo, y es el que de verdad decide si esto fue un respaldo o un teatro. Un snapshot guardado en el mismo disco que se puede perder junto con el original no es un respaldo, es una ilusión de respaldo. Sáquelo del nodo.

ENTREGABLE: el archivo `~/cka-comico-lab/p01/respaldo-de-la-finca.db` fuera del nodo, y el archivo `~/cka-comico-lab/p01/04-respuesta.txt`, exactamente 3 líneas:

```text
RUTA_DEL_CERT_DE_SERVIDOR=<la ruta que el manifiesto de etcd declara en --cert-file>
REVISION_DEL_RESPALDO=<la revisión que reporta el estado del snapshot>
TOTAL_DE_LLAVES=<el total de llaves que reporta el estado del snapshot>
```

<details>
<summary>Qué debería ver</summary>

El grep del manifiesto le imprime las tres rutas de certificado que etcd usa y la lista de URLs en las que escucha, que empiezan por https porque etcd exige TLS mutuo. etcdctl reporta versión 3.6.8 con API versión 3.6. El snapshot save escribe varias líneas de log en formato JSON y termina con Snapshot saved at /var/lib/etcd/respaldo-de-la-finca.db. El etcdctl snapshot --help le muestra algo que sorprende: en esta línea de etcd el subcomando snapshot solo tiene save, porque status y restore se mudaron a etcdutl. Por eso el estado se consulta con etcdutl, y la tabla le devuelve cinco columnas: HASH, REVISION, TOTAL KEYS, TOTAL SIZE y VERSION. El docker cp deja el archivo en su máquina, y ls le muestra un tamaño de alrededor de 1.2 MB. La tabla redondea el tamaño, pero si usted repite el status con --write-out=json va a ver el número exacto, y el archivo en disco pesa exactamente 32 bytes más que ese totalSize: esos 32 bytes de más son el sha256 de integridad que snapshot save le pega al final.

</details>

```bash
./04-step.sh
./04-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 5. Cap. 2 y 3: Un llavero nuevo, la misma llave, y una puerta que sigue cerrada (10 pts)

El Capítulo 2 cerró con el llavero, y el Capítulo 3 le enseñó a mirar los archivos que el clúster escribe en el nodo. Este paso junta las dos cosas en el objeto que más se malinterpreta de todo Kubernetes: el kubeconfig.

Lo que pasa es que muchísima gente cree que el kubeconfig es la seguridad. No no no no. El kubeconfig no tiene ni un permiso adentro: es una libreta de direcciones con tres secciones que nunca se mezclan. clusters guarda a dónde ir. users guarda con qué credencial. contexts amarra un clúster con un user y un namespace y le pone nombre a esa combinación. Eso es todo. Cambiar de contexto es cambiar de llavero, no cambiar de cerradura.

Y la manera de demostrárselo a usted mismo, sin discusión posible, es esta: arme un contexto nuevo en el MISMO archivo, apuntando al MISMO clúster, y métale la llave de la empleada del Paso 2, que se saca con kubectl create token. Después use ese contexto. Va a poder listar los Pods de la-casa, porque la Role se lo permite. Y va a chocar de frente contra un Forbidden al intentar borrar, porque la Role no incluye ese verbo, y el kubeconfig más elegante del mundo no le va a agregar un verbo que RBAC no le dio.

Fíjese en el detalle del borrado, que además es una buena costumbre de examen: se hace con --dry-run=server. La autorización se evalúa antes que el dry-run, así que el rechazo es igual de real, pero si por alguna razón la cuenta SÍ tuviera el permiso, el Pod no se borraría. Es la forma de probar una puerta sin arriesgarse a tumbarla.

ENTREGABLE: el contexto nuevo dentro de `~/cka-comico-lab/p01/kubeconfig`, funcionando, y el archivo `~/cka-comico-lab/p01/05-respuesta.txt`, exactamente 4 líneas:

```text
CONTEXTO_NUEVO=<el nombre que usted le puso al contexto nuevo>
USUARIO_DEL_CONTEXTO=<la entrada de users a la que ese contexto apunta>
CLUSTER_DEL_CONTEXTO=<la entrada de clusters a la que ese contexto apunta>
PALABRA_DEL_RECHAZO=<la palabra que el API server pone entre paréntesis al negarle el borrado>
```

<details>
<summary>Qué debería ver</summary>

La primera consulta le muestra que su kubeconfig privado tiene dos contextos: el de administrador que creó kind y el marcela que usted agregó en el Paso 3. create token le devuelve una cadena larga de tres partes separadas por puntos. Después de los dos comandos de config, get-contexts lista tres contextos: el de administrador, marcela y el suyo nuevo, apuntando al MISMO clúster pero a un user distinto y con namespace la-casa. Y ahí viene la demostración: auth whoami responde que usted es system:serviceaccount:la-casa:la-empleada, get pods lista la-alarma sin problema, el delete es rechazado con Error from server (Forbidden) diciendo textualmente que ese usuario no puede borrar el recurso pods en ese namespace, y el get pods en la-finca-vecina también es rechazado con Forbidden. La última línea confirma que la-alarma sigue viva: el borrado fue rechazado antes de tocar nada.

</details>

```bash
./05-step.sh
./05-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

## Cómo correrlo

```bash
./00-setup.sh
./01-step.sh && ./01-check.sh
./02-step.sh && ./02-check.sh
./03-step.sh && ./03-check.sh
./04-step.sh && ./04-check.sh
./05-step.sh && ./05-check.sh
./99-teardown.sh
```

## Si algo falla

- **Síntoma (step 1):** docker exec responde que no existe el contenedor
  **Qué hacer:** El nombre del contenedor del nodo no es el nombre del clúster: kind le agrega el sufijo del rol. Nunca lo escriba a mano, derívelo con kubectl get nodes o con kind get nodes --name cka-comico-p01, que es lo que hace tanto el comando del paso como la comprobación. Si aun así no aparece, confirme que el clúster está arriba con kind get clusters.

- **Síntoma (step 1):** El campo ownerReferences sale vacío en algún Pod
  **Qué hacer:** Revise que está consultando el Pod correcto: el nombre de un Pod estático es el componente más un guion más el nombre del nodo, no solo el componente. Un kubectl get pods -n kube-system le muestra los nombres completos. Si consulta un Pod que usted mismo creó suelto, ownerReferences sí sale vacío, y ese es justamente el tercer caso que este paso no le pide.

- **Síntoma (step 2):** auth can-i responde no a todo, incluso a get pods en la-casa
  **Qué hacer:** Casi siempre es el sujeto mal escrito. El nombre de usuario de una ServiceAccount es system:serviceaccount:<namespace>:<nombre>, con dos puntos y sin espacios, y RBAC no le avisa cuando usted pregunta por un sujeto que no existe: simplemente responde no, porque en efecto ese sujeto inventado no puede nada. Compare su cadena carácter por carácter con la que imprime kubectl -n la-casa describe rolebinding entrega-de-llave en la sección Subjects.

- **Síntoma (step 2):** auth can-i responde yes a get pods en la-finca-vecina
  **Qué hacer:** La entrega quedó con alcance de clúster. Revise con kubectl get clusterrolebindings -o wide si alguna lo nombra a usted o a la cuenta, y bórrela. Recuerde que roleRef es inmutable: si se equivocó de objeto no lo puede editar, tiene que borrar la entrega entera y hacer una nueva, que es exactamente lo que dice el Capítulo 2.

- **Síntoma (step 3):** kubectl apply del CertificateSigningRequest falla con un error de decodificación en spec.request, o la CSR queda pero el certificado nunca aparece
  **Qué hacer:** El campo request debe ser el contenido de marcela.csr en base64 en UNA sola línea. En Linux, base64 parte la salida en líneas de 76 caracteres, y por eso el comando lleva tr -d '\n'. Si la CSR ya existe de un intento anterior, su spec no se puede editar: bórrela con kubectl delete csr marcela y vuelva a aplicarla. Si el signerName o los usages son otros, el firmante no la emite; para una persona tiene que ser kubernetes.io/kube-apiserver-client con client auth.

- **Síntoma (step 3):** kubectl get csr marcela sigue en Pending, o está Approved pero .status.certificate sale vacío
  **Qué hacer:** Pending significa que falta kubectl certificate approve marcela: ningún controlador aprueba solo una solicitud de cliente. Approved sin certificado casi siempre es cuestión de segundos mientras el kube-controller-manager firma; repita el get csr. Si sigue vacío, mire kubectl describe csr marcela y los registros del kube-controller-manager.

- **Síntoma (step 3):** auth can-i --as=marcela responde no a todo, o get pods con el contexto marcela sigue en Forbidden después de crear el RoleBinding
  **Qué hacer:** El sujeto del RoleBinding tiene que coincidir con el CN del certificado, letra por letra: --user=marcela. RBAC no avisa cuando el nombre no coincide con nada, simplemente responde no. Revise con kubectl -n la-casa get rolebinding llave-de-marcela -o yaml que subjects diga kind User, name marcela y apiGroup rbac.authorization.k8s.io, y que roleRef apunte a la Role encargada. Recuerde que roleRef es inmutable: si se equivocó, borre el RoleBinding y créelo de nuevo.

- **Síntoma (step 4):** kubectl exec al Pod de etcd responde que sh no existe en el PATH
  **Qué hacer:** Es el comportamiento correcto y no se arregla: la imagen de etcd es distroless y no trae shell. Invoque el binario directamente después del doble guion, sin sh -c y sin env, y sin comodines ni redirecciones, porque esas las expande un shell que ahí no existe. Si necesita de verdad un shell dentro del nodo, use docker exec al contenedor del nodo, que sí lo tiene, pero ahí no están ni etcdctl ni etcdutl.

- **Síntoma (step 4):** snapshot save falla con un error de conexión o de certificado
  **Qué hacer:** Compare sus tres rutas con las que imprime el grep del manifiesto, y revise el endpoint. Note que las banderas del cliente no se llaman igual que las del servidor: en el manifiesto se leen --cert-file, --key-file y --trusted-ca-file, pero etcdctl las recibe como --cert, --key y --cacert. Ese cambio de nombre es una de las confusiones clásicas y no hay manera de adivinarla, hay que mirarla.

- **Síntoma (step 4):** etcdutl no existe en su nodo, o etcdctl snapshot status sí funciona
  **Qué hacer:** Entonces su nodo trae una línea de etcd anterior a la 3.6, donde snapshot status todavía vivía en etcdctl. Use etcdctl snapshot status en ese caso: el resto del paso no cambia, y el archivo que usted saca del nodo es el mismo. Confirme siempre su versión primero con etcdctl versión en vez de asumirla, que es justo la razón por la que el comando del paso empieza por ahí.

- **Síntoma (step 5):** El contexto nuevo responde Unauthorized en vez de Forbidden
  **Qué hacer:** Son dos puertas distintas y conviene no confundirlas nunca. Unauthorized (401) es la primera puerta: el API server no sabe quién es usted, o sea que el token quedó mal pegado, quedó cortado, o ya se venció. Forbidden (403) es la segunda: ya sabe quién es usted y le está diciendo que no le alcanza. Vuelva a generar el token con create token --duration=24h y vuelva a ponerlo con set-credentials, en una sola línea y sin comillas de más.

- **Síntoma (step 5):** El contexto nuevo no encuentra el clúster o falla con un error de certificado
  **Qué hacer:** Reutilice la entrada de clusters que ya existe en vez de crear una nueva: eso es exactamente lo que hace --cluster=kind-cka-comico-p01 en el set-context. Si crea un clúster nuevo a mano tiene que volver a poner la CA, y ahí es donde aparece el error de certificado. Revise con kubectl --kubeconfig ~/cka-comico-lab/p01/kubeconfig config view que solo haya una entrada bajo clusters.

- **Síntoma (step 5):** kubectl config set-credentials le tocó su kubeconfig de siempre
  **Qué hacer:** Se le olvidó el --kubeconfig en ese comando concreto. Los subcomandos de kubectl config escriben en el archivo que resuelva la variable KUBECONFIG o, si no hay ninguna, en ~/.kube/config, y no en el archivo del contexto que usted venía usando. Borre la entrada que quedó suelta con kubectl config unset users.la-empleada y repita el comando con --kubeconfig, que es la razón por la que este laboratorio lo escribe explícito en cada línea.

## Para ir más lejos

- Borre el Pod espejo del kube-scheduler con kubectl -n kube-system delete pod kube-scheduler-<nodo> y vea qué pasa a los pocos segundos. Después mueva el manifiesto fuera de la carpeta con docker exec <nodo> mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/ y compare: una de las dos operaciones apaga de verdad el componente y la otra no. Devuélvalo a su sitio cuando termine, y de paso intente crear un Pod nuevo mientras el scheduler está apagado para ver dónde se queda atascado.
- Rehaga la entrega del Paso 2 con la combinación que el Capítulo 2 recomienda: cree una ClusterRole reutilizable con los mismos dos verbos y entréguela con un RoleBinding en la-casa. Vuelva a lanzar las cinco preguntas de auth can-i y confirme que las respuestas son idénticas. Después entregue esa MISMA ClusterRole con un ClusterRoleBinding y mire cuál de las cinco respuestas cambia: esa única diferencia es toda la lección de alcance del capítulo.
- Ponga a prueba el respaldo del Paso 4 de la manera que de verdad importa: restáurelo. Copie el archivo de vuelta al nodo y corra etcdutl snapshot restore con un --data-dir nuevo, y lea las líneas que imprime. Después cambie un solo byte del archivo con dd y vuelva a intentar la restauración: el error le va a nombrar el sha256 que esperaba y el que encontró. Compare eso con lo que le responde etcdutl snapshot status sobre ese mismo archivo dañado y saque su propia conclusión sobre cuál de los dos comandos es una verificación de respaldo y cuál no.
- Genere un segundo token para la misma cuenta con --duration=10m, métalo en un contexto aparte, y decodifique la parte del medio del token (la que va entre los dos puntos) con base64 para leer los campos exp e iat. Reste uno del otro y confirme que la duración es la que usted pidió. Eso es exactamente el token de corta duración que el Capítulo 2 menciona, y ver la fecha de vencimiento escrita adentro es lo que hace que la idea deje de ser abstracta.

## Referencias

- Kubernetes Project, Creating static Pods. The authority for Step 1: documents staticPodPath, the /etc/kubernetes/manifests convention, the mirror Pod the kubelet publishes to the API server, and the fact that deleting that mirror with kubectl does not stop the underlying Pod. https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/
- Kubernetes Project, Kubernetes Components. Names the control-plane components inspected in Step 1 (kube-apiserver, etcd, kube-scheduler, kube-controller-manager) and the node components. https://kubernetes.io/docs/concepts/overview/components/
- Kubernetes Project, DaemonSet. The contrast case in Step 1: kube-proxy is handed out by a DaemonSet controller rather than by a file on the node. https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/
- Kubernetes Project, Using RBAC Authorization. The basis of Steps 2 and 3: the four object types, the User and Group subjects of a RoleBinding, the rule that a RoleBinding may reference a ClusterRole to grant permissions within one namespace only, and the immutability of roleRef. https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- Kubernetes Project, Authorization. Documents kubectl auth can-i, including the --as impersonation flag and the --list form used in Steps 2 and 3. https://kubernetes.io/docs/reference/access-authn-authz/authorization/
- Kubernetes Project, Service Accounts. Documents ServiceAccounts as the identity for processes rather than people, and the short-lived, automatically rotated tokens obtained through the TokenRequest API that Steps 3 and 5 use via kubectl create token. https://kubernetes.io/docs/concepts/security/service-accounts/
- Kubernetes Project, Organizing Cluster Access Using kubeconfig Files. The basis of Step 5: the clusters, users and contexts sections, current-context, and the rule that a context binds a cluster to a user and a namespace. https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/
- Kubernetes Project, Operating etcd clusters for Kubernetes. The documented snapshot save command for Step 4, including the ETCDCTL_API=3 prefix and the --cert, --key and --cacert client flags, and the warning that a restore creates a new data directory the static Pod manifest must then be pointed at. https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/
- etcd Project, Disaster recovery. Documents snapshot save against a live member and the restore path, and is the reference for etcdutl as the tool that operates directly on snapshot files without a running cluster. https://etcd.io/docs/v3.6/op-guide/recovery/
- etcd Project, etcdutl README. The authority for the etcdutl subcommands used in Step 4, including snapshot status and snapshot restore, which is where they live on the etcd 3.6 line this lab's node image ships. https://github.com/etcd-io/etcd/blob/main/etcdutl/README.md
- Kubernetes Project, Issue a Certificate for a Kubernetes API Client Using a CertificateSigningRequest. The authority for Step 3: the documented procedure for a normal user (openssl key and CSR with CN and O, a CertificateSigningRequest with signerName kubernetes.io/kube-apiserver-client and usages client auth, kubectl certificate approve, extracting .status.certificate, kubectl config set-credentials and set-context, then a Role and RoleBinding for the user). Kubernetes has no User object: the user name is the certificate CN. https://kubernetes.io/docs/tasks/tls/certificate-issue-client-csr/
- Kubernetes Project, Certificates and Certificate Signing Requests. The reference for the CertificateSigningRequest API used in Step 3: signers, the kube-apiserver-client signer, expirationSeconds (not shorter than 10 minutes) and the approve and deny flow. The Normal user walkthrough that used to live here now lives in the task page above. https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/
- kind Project, Quick Start. Documents kind create cluster with --name, --image and --kubeconfig, kind delete cluster, the kind-<name> context naming, and the <name>-control-plane node container naming used throughout this lab. https://kind.sigs.k8s.io/docs/user/quick-start/

---

_Hecho con ❤️ por Luis Felipe Ariza Vesga._
