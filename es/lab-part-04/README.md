# Parte IV - Laboratorio: un depósito que usted mismo construye, un despensero que se muda y vuelve, una constructora, con su catálogo de lotes, que no mueve tierra hasta que alguien firme, y unas escrituras que sobreviven al contrato

- Tiempo: 55 min
- Puntos: 40

## Objetivo

Este es un laboratorio Exam-Style: cada paso le dice solo el objetivo y el entregable, y la secuencia exacta de comandos vive en el script NN-step.sh de ese paso para que usted la revele después de haberlo intentado primero con sus propias manos. El Paso 1 le hace hacer el aprovisionamiento estático completo del Capítulo 9: usted construye el depósito a mano (un PersistentVolume hostPath anclado al nodo worker, con un tamaño fijo) y después escribe el contrato (un PersistentVolumeClaim) que tiene que enlazarse con ese depósito y no con otro, y la calificación exige que los dos se apunten mutuamente, no que cada uno diga Bound por su cuenta. El Paso 2 mete al despensero: un Pod que monta ese PVC, escribe un archivo dentro del depósito, se muda (usted borra el Pod), y vuelve a entrar; la calificación entra al Pod vivo, lee el archivo, y además comprueba que el Pod monte de verdad el PVC y no un emptyDir disfrazado. El Paso 3 pasa al Capítulo 10 y al aprovisionamiento dinámico: usted lee de su propio clúster qué StorageClass es la de por defecto y con qué volumeBindingMode trabaja, crea un PVC sin ningún PV esperándolo, y demuestra que se queda en Pending mientras nadie lo consuma y que solo se enlaza cuando aparece el primer Pod. El Paso 4 cierra con la política de reclamo: usted rescata un volumen aprovisionado dinámicamente cambiándole la política a Retain, borra su PVC, y demuestra que el PV sobrevive en estado Released en vez de desaparecer, que es la diferencia entre perder los datos de un cliente y recuperarlos.

## Prerrequisitos

- Una máquina Linux con kind, kubectl y docker en el PATH, acceso a internet, y al menos 4 GB de RAM libre. Este laboratorio crea su propio clúster de kind llamado cka-comico-p04, de dos nodos (un control-plane y un worker), y lo borra al final. Todo lo que hace pasa por un kubeconfig privado en ~/cka-comico-lab/p04/kubeconfig, que se pasa con --kubeconfig en cada comando: su kubeconfig de siempre nunca se toca, su contexto actual nunca cambia, y ningún otro clúster suyo se ve afectado. No ejecute este laboratorio contra un clúster de producción.
- Versiones fijadas y verificadas el 2026-08-21 en la máquina donde se ejecutó este laboratorio: kind v0.32.0, imagen de nodo kindest/node:v1.36.1 fijada por digest sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, y la imagen de carga de trabajo busybox:1.37.0 fijada por digest sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0. Confirme su kind con kind version y su kubectl con kubectl version --client antes de empezar, en vez de creerle a este párrafo.
- Los dos nodos son obligatorios, no un lujo. Los Pasos 1 y 2 anclan un PV de tipo hostPath al nodo worker con nodeAffinity, y esa ancla es lo único que garantiza que el Pod recreado del Paso 2 vuelva al mismo disco donde dejó el archivo. En un clúster de un solo nodo el laboratorio parecería funcionar y le estaría enseñando algo falso, así que el script de setup se niega a continuar si no encuentra un worker.
- La calificación del Paso 2 usa date -u -d para convertir una marca de tiempo RFC 3339 a segundos desde el epoch, que es comportamiento de GNU coreutils. En una máquina Linux normal funciona sin hacer nada; en macOS con el date de BSD no, y tendría que instalar coreutils y usar gdate.
- Haber leído los Capítulos 9 y 10. Este laboratorio no vuelve a explicar qué es un PersistentVolume, qué significa cada modo de acceso, ni por qué existe el aprovisionamiento dinámico; le hace operar las cuatro cosas contra un clúster real y calificarlas contra su estado real.

## Pasos

El `0N-step.sh` está para que no se quede atascado: lea el paso, intente primero por su cuenta y corra el script cuando quiera comparar. Escribe también el archivo de respuesta que el paso pide, leyendo los valores del clúster vivo.

### 1. Cap. 9: Usted construye el depósito, y después firma el contrato que le corresponde (10 pts)

El Capítulo 9 le explicó que el depósito de la finca no es el corredor de ninguna casa. Este paso le hace construir el depósito con sus propias manos, que es lo que se llama aprovisionamiento estático: primero existe el volumen, y después alguien lo reclama.

Lo que pasa es que aquí hay dos objetos y mucha gente los confunde porque los dos terminan diciendo Bound. El PersistentVolume es el depósito físico: tiene un tamaño, tiene una ubicación real en un disco, y no pertenece a ningún namespace, porque el depósito de la finca no es de una casa sino de la finca entera. El PersistentVolumeClaim es el contrato que firma una casa: vive dentro de un namespace, pide un tamaño y unos modos de acceso, y no sabe ni le importa dónde está el depósito. Entre esos modos de acceso, ReadWriteOnce es la llave del depósito entregada a una obra completa (un nodo), cuyas personas pueden entrar todas, y ReadWriteOncePod es la llave con el nombre de una sola persona. El controlador es el administrador que los empareja, y cuando los empareja escribe la pareja en los dos lados: el PVC queda con volumeName apuntando al PV, y el PV queda con claimRef apuntando al namespace y al nombre del PVC. Esa doble anotación es la que hace que el depósito quede apartado y nadie más pueda reclamarlo.

Dos detalles que en el examen cuestan puntos. El primero: storageClassName con la cadena vacía no es lo mismo que no poner el campo. La cadena vacía significa "no quiero que nadie me aprovisione nada, quiero un volumen que ya exista"; omitir el campo hace que le asignen la clase por defecto, y entonces le construyen un volumen nuevo y su depósito hecho a mano se queda ahí, Available, mirando. El segundo: el depósito está en un disco concreto de un nodo concreto, así que hay que decirlo con nodeAffinity. Sin esa ancla, el planificador puede mandar el Pod al otro nodo, donde ese directorio no existe, y usted va a jurar que Kubernetes le borró los datos.

ENTREGABLE: el PV `deposito-de-la-finca` y el PVC `contrato-de-la-cocina` (en el namespace cuchara-de-oro) enlazados el uno al otro, y el archivo `~/cka-comico-lab/p04/01-respuesta.txt`, exactamente 2 líneas:

```text
PV_DEL_CONTRATO=<el nombre que el PVC contrato-de-la-cocina lleva en su campo spec.volumeName>
CLAIMREF_DEL_PV=<el namespace y el nombre que el PV deposito-de-la-finca lleva en su claimRef, escrito en formato namespace/nombre>
```

<details>
<summary>Qué debería ver</summary>

Recién creado, el PV aparece con STATUS Available y con la columna CLAIM vacía: existe un depósito y todavía no lo reclama nadie. Segundos después de aplicar el PVC, las dos consultas cambian a la vez: el PV pasa a Bound y ahora muestra cuchara-de-oro/contrato-de-la-cocina en CLAIM, y el PVC pasa a Bound mostrando deposito-de-la-finca en VOLUME. En la máquina donde se ejecutó este laboratorio el enlace ya estaba hecho en la primera vuelta del bucle, o sea en menos de cinco segundos. Las dos consultas finales con jsonpath imprimen claimRef=cuchara-de-oro/contrato-de-la-cocina y volumeName=deposito-de-la-finca, que es la misma pareja vista desde los dos lados.

</details>

```bash
./01-step.sh
./01-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 2. Cap. 9: El despensero se muda, y al volver el depósito sigue teniendo sus cosas (10 pts)

El Capítulo 9 dijo que lo que usted guarda en el corredor de una casa se lo lleva la mudanza, y lo que guarda en el depósito no. Este paso lo comprueba con una mudanza de verdad.

Usted monta el PVC del Paso 1 dentro de un Pod, escribe un archivo ahí adentro, y después borra el Pod. Borrar el Pod es la mudanza: el contenedor desaparece, su sistema de archivos desaparece, la IP desaparece. Después vuelve a aplicar el mismo manifiesto y entra un Pod nuevo, que no es el mismo aunque se llame igual. Lo que pasa es que el archivo sigue ahí, intacto, porque nunca vivió en el Pod: vivió en el depósito, y el depósito es de la finca.

Ojo con el atajo que parece inocente y no lo es. Si usted monta un emptyDir en /deposito y hace que el contenedor escriba el archivo al arrancar, el cat le va a mostrar exactamente lo mismo. Se ve idéntico y no demuestra nada, porque un emptyDir se crea vacío cada vez que el Pod nace y se borra con él. Por eso la calificación de este paso no se conforma con leer el archivo: mira cómo está montado el volumen, y mira la edad del archivo contra la edad del Pod. Un archivo más viejo que el Pod que lo lee es la única evidencia que un emptyDir no puede fabricar.

Y una cosa más, que en el examen se paga caro: fíjese en qué nodo quedó el Pod. Quedó en el worker, y no fue casualidad ni suerte del planificador: fue la nodeAffinity que usted le puso al PV en el Paso 1. Si el depósito está en un disco de un nodo, el despensero tiene que vivir en ese nodo.

ENTREGABLE: el Pod `despensero` corriendo en el namespace cuchara-de-oro con el PVC `contrato-de-la-cocina` montado en /deposito, el archivo `/deposito/marca.txt` escrito por un Pod anterior y sobreviviente a la mudanza, y el archivo `~/cka-comico-lab/p04/02-respuesta.txt`, exactamente 2 líneas:

```text
MARCA=<el contenido exacto de /deposito/marca.txt, leído desde el Pod recreado>
VOLUMEN_DEL_POD=<el nombre del PVC que el Pod declara en su lista de volumes>
```

<details>
<summary>Qué debería ver</summary>

El primer Pod queda Running en el nodo worker, no en el control-plane, porque la nodeAffinity del PV del Paso 1 obligó al planificador a mandarlo ahí. El archivo se escribe y se lee sin drama. Después de borrar el Pod y volver a aplicar el mismo manifiesto, el Pod nuevo tiene otra IP y otro identificador, y aun así el cat imprime el mismo contenido de antes. La comparación final es la prueba dura: en la máquina donde se ejecutó este laboratorio el mtime del archivo fue 1787318413 y el startTime del Pod recreado fue 1787318448, es decir, el archivo es 35 segundos más viejo que el Pod que lo está leyendo. Sus dos números van a ser otros; lo que no puede cambiar es cuál de los dos es menor.

</details>

```bash
./02-step.sh
./02-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 3. Cap. 10: La constructora no mueve tierra hasta que alguien diga dónde va a vivir (10 pts)

Hasta aquí usted hizo de albañil. El Capítulo 10 le presenta a la constructora: usted deja de construir depósitos a mano y empieza a encargarlos. Un PVC que no nombra ningún volumen, sobre una StorageClass, y la constructora aparece con el terreno listo.

Empiece leyendo el catálogo de su propio clúster, no el de este libro. Cuál StorageClass tiene la anotación de por defecto, qué provisioner la respalda, con qué volumeBindingMode trabaja, y de una vez si permite ampliaciones. En un clúster de kind la respuesta va a ser el aprovisionador local-path de Rancher, pero eso lo tiene que ver usted en su pantalla, porque en el examen la clase por defecto puede ser cualquier otra y la costumbre de leerla antes de usarla es exactamente lo que se está entrenando.

Lo que pasa es que después de crear el PVC no va a pasar absolutamente nada, y eso es lo correcto. Van a pasar quince segundos, treinta, los que usted quiera, y el PVC va a seguir en Pending, sin volumeName, y no va a existir ningún PV nuevo. No es un error, es volumeBindingMode: WaitForFirstConsumer haciendo lo que promete: la constructora no mueve tierra hasta que usted le diga en qué lote va a vivir, porque el lote se escoge según dónde el planificador vaya a poner al Pod. Los eventos del PVC lo dicen con todas las letras. En cuanto usted crea el Pod que lo consume, el enlace ocurre y aparece un PV con nombre de UID que nadie escribió a mano.

Una limitación que hay que decir con honestidad, porque este laboratorio no la va a esconder detrás de un ejercicio falso: en este sustrato la clase por defecto no permite ampliar un PVC. El campo allowVolumeExpansion ni siquiera está puesto, que es lo mismo que decir false, y por eso aquí no hay ningún paso de expansión. El Capítulo 10 le enseña a leer ese campo antes de prometerle a nadie que puede crecer un volumen, y esa lectura es justamente lo que usted acaba de hacer.

ENTREGABLE: el PVC `lote-por-encargo` enlazado a un PV que usted no creó, el Pod `constructor` corriendo y consumiéndolo, y el archivo `~/cka-comico-lab/p04/03-respuesta.txt`, exactamente 3 líneas:

```text
APROVISIONADOR=<el provisioner de la StorageClass por defecto de este clúster>
MODO_DE_ENLACE=<el volumeBindingMode de esa misma StorageClass>
FASE_SIN_CONSUMIDOR=<la fase en la que estuvo lote-por-encargo mientras ningún Pod lo usaba>
```

<details>
<summary>Qué debería ver</summary>

La primera consulta le muestra una sola StorageClass marcada (default), y las cuatro propiedades leídas con jsonpath dicen, en el clúster donde se ejecutó este laboratorio: provisioner rancher.io/local-path, volumeBindingMode WaitForFirstConsumer, reclaimPolicy Delete y allowVolumeExpansion vacío, o sea el campo ni siquiera está puesto. Quince segundos después de crear el PVC sigue en Pending, su volumeName imprime como un par de corchetes vacíos, no existe ningún PV nuevo, y el evento del describe dice waiting for first consumer to be created before binding con reason WaitForFirstConsumer. En cuanto el Pod entra, el PVC pasa a Bound contra un PV recién nacido cuyo nombre empieza por pvc- seguido de un UID, con la anotación provisioned-by en rancher.io/local-path, storageClassName standard y reclaimPolicy Delete.

</details>

```bash
./03-step.sh
./03-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 4. Cap. 9 y 10: Se acaba el contrato, y las escrituras no se van a la basura (10 pts)

Este es el paso que separa al que sabe la teoría del que ya salvó datos de verdad. El Capítulo 9 le enseñó las políticas de reclamo y el Capítulo 10 le enseñó que la StorageClass es la que decide con cuál nacen los volúmenes que ella aprovisiona. Aquí los dos capítulos se encuentran en la operación real: alguien va a borrar un PVC, y de lo que usted haya hecho antes depende que los datos se puedan recuperar o no.

Lo que pasa es que el valor por defecto de la constructora es borrar. El PV que ella crea nace con la política que la clase le dicte, y en este clúster esa política es Delete, lo cual quiere decir que el día que el PVC se borre, el volumen se borra detrás y los datos se van con él, sin preguntar y sin confirmación. No hay papelera de reciclaje. Ese comportamiento está bien para un caché y es una tragedia para una base de datos, y la diferencia entre las dos situaciones la pone el administrador, no la constructora.

Entonces usted hace lo que hace un administrador que ya vivió el susto: le cambia la política a ese volumen concreto, de Delete a Retain, antes de que nadie borre nada. Después llega el borrado, primero el Pod y después el PVC (en ese orden, porque un PVC que un Pod está usando no se borra, se queda esperando por el finalizador de protección), y usted se queda mirando la lista de PV. El volumen sigue ahí. No está Available, está Released, que es distinto: significa que su contrato murió pero él quedó reservado a nombre del difunto, precisamente para que nadie más lo reclame por accidente y le pise los datos. El claimRef del muerto sigue escrito, y sacarlo es una decisión consciente y manual, no un descuido.

Una última cosa, y en esta no experimente por curiosidad sobre datos que le importen: volver a poner Delete sobre un PV que ya está Released no lo devuelve al estado anterior. Es la orden de ejecución, y se cumple en segundos.

Este paso necesita que la StorageClass del Paso 3 siga como estaba, así que no la modifique para llegar aquí.

ENTREGABLE: el PV que quedó Released con política Retain y sin PVC, el PVC `lote-de-rescate` borrado, y el archivo `~/cka-comico-lab/p04/04-respuesta.txt`, exactamente 4 líneas:

```text
PV_RESCATADO=<el nombre del PV que sobrevivió a la muerte de su PVC>
POLITICA_ANTES=<la política de reclamo con la que ese PV nació, heredada de la StorageClass>
POLITICA_DESPUES=<la política de reclamo que usted le dejó>
FASE_FINAL=<la fase en la que quedó el PV después de que el PVC desapareciera>
```

<details>
<summary>Qué debería ver</summary>

El PV que la constructora aprovisiona nace con la política que heredó de la StorageClass, y en este clúster esa política es Delete: la línea política ANTES imprime Delete. Después del patch, la línea política DESPUES imprime Retain, y ese es el único cambio que usted hizo sobre el volumen. Al borrar el Pod y después el PVC, el PV no desaparece: en la máquina donde se ejecutó este laboratorio ya estaba en Released en la primera vuelta del bucle, o sea en menos de cinco segundos. El listado final de PV lo muestra con STATUS Released, RECLAIM POLICY Retain y la columna CLAIM todavía diciendo cuchara-de-oro/lote-de-rescate, aunque el listado de PVC del namespace ya no tenga ese contrato. Ese claimRef que sobrevive al PVC es exactamente lo que impide que el volumen se le entregue a otro reclamo por accidente.

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

- **Síntoma (step 1):** El PVC se queda en Pending para siempre y el PV sigue diciendo Available
  **Qué hacer:** El controlador solo empareja lo que es compatible en las tres dimensiones a la vez: la capacidad del PV tiene que ser mayor o igual a lo que pide el PVC, los modos de acceso pedidos tienen que estar todos en la lista del PV, y el storageClassName tiene que coincidir carácter por carácter. Compare los tres campos lado a lado con kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig get pv deposito-de-la-finca -o yaml y kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig -n cuchara-de-oro get pvc contrato-de-la-cocina -o yaml, y revise sobre todo storageClassName: si el PVC dice standard es porque usted omitió el campo y el plugin de admisión se lo llenó. Los eventos del PVC lo dicen en palabras: kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig -n cuchara-de-oro describe pvc contrato-de-la-cocina.

- **Síntoma (step 1):** Borró el PVC para volver a empezar y ahora el PV dice Released y no acepta el contrato nuevo
  **Qué hacer:** Eso no es un bug, es exactamente la política Retain del Capítulo 9 haciendo su trabajo: el depósito no se borra cuando el contrato se acaba, pero se queda reservado a nombre del contrato viejo, y ese claimRef muerto es lo que impide que se enlace otra vez. Para volver a ponerlo disponible hay que quitarle la reserva a mano con kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig patch pv deposito-de-la-finca -p '{"spec":{"claimRef":null}}'; en cuanto el claimRef desaparece el PV pasa a Available y el PVC nuevo se enlaza en segundos. Los datos que hubiera adentro siguen ahí, porque nunca se borraron.

- **Síntoma (step 2):** El Pod se queda en Pending y describe dice algo sobre node(s) had volume node affinity conflict
  **Qué hacer:** El planificador está haciendo su trabajo: el PV está anclado a un nodo y usted le pidió al Pod que corra en otro, casi siempre por un nodeSelector o una tolerancia puesta a mano. Compare a qué nodo apunta el PV con kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig get pv deposito-de-la-finca -o jsonpath='{.spec.nodeAffinity}' y compárelo con lo que pide el Pod. La solución es quitarle al Pod la restricción que sobra, no quitarle la nodeAffinity al PV: sin esa ancla el Pod podría caer en el otro nodo, encontrar el directorio vacío, y usted perdería la prueba entera.

- **Síntoma (step 2):** El archivo se lee bien pero la comprobación falla y usted no ve por qué
  **Qué hacer:** Casi siempre es el mtime. Ejecute usted mismo la misma comparación que hace la calificación: kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig -n cuchara-de-oro exec despensero -- stat -c '%Y' /deposito/marca.txt para la edad del archivo, y date -u -d "$(kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig -n cuchara-de-oro get pod despensero -o jsonpath='{.status.startTime}')" +%s para la del Pod. Si el número del archivo es mayor o igual al del Pod, es que el archivo se escribió durante la vida de este Pod y no del anterior. Vuelva a hacer el paso en el orden correcto: escriba el archivo, después borre el Pod, después recréelo, y no vuelva a tocar el archivo.

- **Síntoma (step 3):** El PVC se enlaza de inmediato, sin esperar a ningún Pod, y usted no ve el Pending por ningún lado
  **Qué hacer:** Revise el volumeBindingMode real de la clase que le tocó, con kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig get sc -o custom-columns=NOMBRE:.metadata.name,MODO:.volumeBindingMode. Si dice Immediate, el enlace ocurre apenas se crea el PVC y el comportamiento de este paso no existe en su clúster; el script de setup se detiene precisamente por eso, así que si llegó hasta aquí es porque alguien cambió la clase después. La otra causa posible es que su PVC se haya enlazado a un PV estático que ya estaba Available y que le calzaba en tamaño y modos de acceso, por ejemplo si usted dejó suelto algún volumen de los pasos anteriores.

- **Síntoma (step 3):** El Pod constructor se queda en Pending y el PVC también
  **Qué hacer:** Con WaitForFirstConsumer los dos se esperan mutuamente hasta que el planificador escoge nodo, así que un Pod que no se puede planificar por cualquier otra razón deja el PVC congelado en Pending para siempre y parece un problema de almacenamiento sin serlo. Lea la causa real en los eventos del Pod, con kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig -n cuchara-de-oro describe pod constructor, y revise si hay taints, recursos insuficientes o un nodeSelector imposible. Arregle la planificación y el volumen se aprovisiona solo.

- **Síntoma (step 4):** El PVC lote-de-rescate se queda en Terminating y no se borra nunca
  **Qué hacer:** Es el finalizador kubernetes.io/pvc-protection, y está haciendo exactamente lo que debe: Kubernetes no le deja borrar un PVC mientras algún Pod lo esté usando, para que nadie le quite el piso a una carga de trabajo viva. Vea quién lo está usando con kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig -n cuchara-de-oro describe pvc lote-de-rescate y mire la línea Used By. Borre ese Pod y el PVC termina de borrarse solo, en segundos. Nunca quite el finalizador a mano para apurar el proceso: eso deja objetos huérfanos y montajes colgados en el nodo.

- **Síntoma (step 4):** Borró el PVC y el PV desapareció con él, y ahora no hay nada que calificar
  **Qué hacer:** El patch de Retain no alcanzó a aplicarse antes del borrado, o se aplicó sobre otro PV. Confirme siempre la política del volumen antes de borrar nada, con kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig get pv, mirando la columna RECLAIM POLICY del volumen cuyo CLAIM sea cuchara-de-oro/lote-de-rescate. Como el volumen ya no existe, este paso se rehace desde cero: cree otra vez el PVC y el Pod, espere a que el PVC quede Bound, lea el nombre del PV nuevo, aplíquele el patch, verifique que diga Retain, y solo entonces borre. El orden importa, y ese es justamente el aprendizaje del paso.

## Para ir más lejos

- Tome el PV que quedó en Released al final del Paso 4 y devuélvalo al servicio como si fuera un volumen nuevo: quítele la reserva del contrato muerto con kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig patch pv <nombre> -p '{"spec":{"claimRef":null}}', confirme que pasa a Available, y después cree un PVC nuevo con storageClassName vacío y el mismo tamaño para ver si se enlaza. Revise después, montándolo en un Pod, si los datos del despensero anterior siguen ahí. Esa respuesta es el argumento más fuerte que existe a favor de tener un procedimiento escrito para reciclar volúmenes Released, en vez de reciclarlos a ojo.
- Cree un segundo PVC con exactamente los mismos modos de acceso y el mismo tamaño que el `contrato-de-la-cocina` del Paso 1, con storageClassName vacío, y déjelo ahí. Observe que se queda en Pending para siempre aunque el PV deposito-de-la-finca exista y le calce en todo, y explique con sus propias palabras por qué: un PersistentVolume se enlaza con un solo reclamo a la vez, y ReadWriteOnce nunca quiso decir un solo Pod, quiso decir un solo nodo. Es una de las confusiones más caras del examen.
- Intente ampliar el PVC `lote-por-encargo` del Paso 3 de 256Mi a 512Mi editándolo con kubectl edit, y lea con calma el error que le devuelve el API server. Después consulte kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig get sc <clase> -o jsonpath='{.allowVolumeExpansion}' y relacione una cosa con la otra. Este laboratorio no incluyó un paso de expansión precisamente porque este sustrato no la permite, y verlo fallar con sus propias manos vale más que la tabla de cualquier libro.
- Cree una StorageClass propia que apunte al mismo provisioner que la de por defecto pero con reclaimPolicy Retain, sin marcarla como la clase por defecto, y aprovisione un PVC contra ella. Compruebe que el PV nace ya con Retain sin que usted tenga que hacerle ningún patch, y compare esa forma de trabajar con la del Paso 4. Después pregúntese cuál de las dos preferiría tener escrita el día que un compañero borre un PVC de producción a las tres de la mañana.

## Referencias

- Kubernetes Project, Persistent Volumes. Primary source for the PV and PVC lifecycle, for the binding that writes volumeName on the claim and claimRef on the volume, for the meaning of the empty storageClassName string versus an absent field, for the Available/Bound/Released/Failed phases, and for the Retain and Delete reclaim policies read and changed in Steps 1, 2 and 4. https://kubernetes.io/docs/concepts/storage/persistent-volumes/
- Kubernetes Project, Storage Classes. Primary source for the provisioner, reclaimPolicy, allowVolumeExpansion and volumeBindingMode fields, for the storageclass.kubernetes.io/is-default-class annotation used to find the default class, and for the WaitForFirstConsumer semantics that Step 3 observes live. https://kubernetes.io/docs/concepts/storage/storage-classes/
- Kubernetes Project, Dynamic Volume Provisioning. Primary source for how a PVC with no matching PV triggers a provisioner, for the DefaultStorageClass admission plugin that fills in an absent storageClassName, and for the pv.kubernetes.io/provisioned-by annotation the grading of Steps 3 and 4 relies on to tell a provisioned volume from a hand-made one. https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/
- Kubernetes Project, Volumes. Primary source for the difference between emptyDir and a persistentVolumeClaim volume, for the hostPath type field including DirectoryOrCreate, and for the volumes and volumeMounts pairing the Pods in Steps 2, 3 and 4 declare. https://kubernetes.io/docs/concepts/storage/volumes/
- Rancher, local-path-provisioner. The provisioner kind installs and marks as the default StorageClass, whose behavior Step 3 reads off the live cluster rather than asserting. Documents that it provisions node-local paths, which is why its class defers binding until a Pod is scheduled. https://github.com/rancher/local-path-provisioner
- kubernetes-sigs/kind, release v0.32.0. Publishes the pre-built node images for this kind release, including the kindest/node:v1.36.1 digest the setup script pins, and documents the --config and --kubeconfig flags this lab uses to build its own two-node cluster without touching any other kubeconfig. https://github.com/kubernetes-sigs/kind/releases/tag/v0.32.0
- kind Project, Quick Start. Documents kind create cluster and kind delete cluster with the --name flag, the multi-node cluster configuration file, and the kubeconfig handling that keeps this lab's cluster isolated in a private file. https://kind.sigs.k8s.io/docs/user/quick-start/
- Kubernetes Project, JSONPath Support. Documents the jsonpath output format, including the filter expressions this lab uses to find the default StorageClass by annotation and to find a PV by its claimRef instead of by a name that changes on every run. https://kubernetes.io/docs/reference/kubectl/jsonpath/

---

_Hecho con ❤️ por Luis Felipe Ariza Vesga._
