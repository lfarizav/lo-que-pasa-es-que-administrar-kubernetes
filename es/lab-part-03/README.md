# Parte III - Laboratorio: el directorio del barrio que quedó desactualizado, la señora de la tienda que sigue contestando, Justo Segura, un celador que de verdad cierra la puerta, y un citófono que suena en el apartamento correcto

- Tiempo: 60 min
- Puntos: 40

## Objetivo

Este es un laboratorio Exam-Style: cada paso le dice solo el objetivo, y la secuencia exacta de comandos vive en el script NN-step.sh de ese paso, para que usted la revele después de haber intentado primero por su cuenta. El Paso 1 le hace montar un Deployment con su Service ClusterIP y comprobar en vivo que el EndpointSlice se lleno, y además le entrega un segundo Service que el montaje del laboratorio dejó roto a propósito: usted tiene que diagnosticar por qué no tiene ni un endpoint y arreglarlo sin tocar el Deployment (Capítulo 6). El Paso 2 le hace resolver el nombre completo del Service desde un Pod de depuración con imagen fijada, anotar la ClusterIP que devolvió el DNS, y además ver con sus propios ojos que un Service headless no devuelve una dirección sino la lista entera de las casas (Capítulo 6). El Paso 3 es el que de verdad separa este laboratorio de un blog: usted mide primero que el tráfico entre dos Pods pasa sin restricción, aplica una política de negación por defecto más una política que abre una sola puerta por etiqueta, y demuestra con códigos de salida que la visita autorizada entra y la colada se queda esperando hasta que se le acaba el tiempo (Capítulo 7). El Paso 4 cierra con la puerta de la calle: usted crea un Ingress con dos rutas hacia dos Services distintos y comprueba que cada botón del citófono suena en el apartamento correcto, atravesando el controlador de verdad (Capítulo 8). Ninguna comprobación lee su historial de comandos: todas vuelven a consultar el clúster en el momento de calificar, y tres de ellas generan tráfico nuevo por su cuenta para confirmar que el control sigue en pie.

## Prerrequisitos

- Una máquina Linux con kind, kubectl, docker, curl y base64 en el PATH, y con al menos 4 GB de RAM libres. El laboratorio crea su propio clúster kind llamado cka-comico-p03 y escribe su kubeconfig en un archivo privado, ~/cka-comico-lab/p03/kubeconfig, que no es el suyo de siempre. Todos los comandos del laboratorio pasan --kubeconfig apuntando a ese archivo, así que su ~/.kube/config no se modifica y ningún otro clúster suyo se toca. El teardown borra unicamente el clúster cka-comico-p03 y la carpeta ~/cka-comico-lab/p03.
- El puerto 8080 del host libre. El clúster se crea con un extraPortMapping que lleva el 8080 del host al puerto 80 del nodo, que es por donde usted va a tocar el citófono del Paso 4 desde afuera. Confirme con ss -ltn antes de empezar; si está ocupado, cambie el número en kind-p03.yaml y en los comandos del Paso 4.
- Acceso a internet en el momento de montar el laboratorio: el setup descarga los manifiestos de Calico y del controlador de Ingress, y las imágenes de contenedor de quay.io, registry.k8s.io y docker.io. La calificación en si no necesita internet, solo el clúster vivo y el puerto 8080 del host.
- IMAGEN DEL NODO FIJADA POR DIGEST, tomada del propio binario de kind v0.32.0 el 2026-08-21: kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5. Las notas de versión de kind dicen que hay que usar el digest @sha256 para garantizar una imagen construida para esa versión, no solo el tag. Confirme la suya con kind version y con docker images --digests, nunca de memoria.
- CNI FIJADO: Calico v3.32.1, la versión estable más nueva el 2026-08-21 según las releases del proyecto. Esta pieza no es decoración. El clúster se crea con disableDefaultCNI en true para parecerse a un clúster armado con kubeadm, que arranca sin ningún CNI y en el que usted mismo instala uno que aplique NetworkPolicy; Calico es una elección común. Los kind recientes ya traen un CNI propio que aplica NetworkPolicy, así que aquí Calico es parte del ejercicio y no una necesidad de kind. Lo que sí importa es que el CNI aplique las políticas, porque sin eso el Paso 3 entero sería teatro, exactamente el celador de mentiras del Capítulo 7, el que Justo Segura nunca sería. Ojo con un detalle que se paga caro: el archivo custom-resources.yaml que publica Calico trae por defecto un pool de IPs en 192.168.0.0/16, que es el rango de casi toda red casera. Por eso este laboratorio no usa ese archivo: escribe su propio recurso Installation con cidr 10.244.0.0/16, el mismo podSubnet que se le declara a kind. Confirme el pool que quedó vivo con kubectl get ippools -o wide.
- CONTROLADOR DE INGRESS FIJADO, y aquí hay que decir la verdad completa: ingress-nginx controller-v1.15.1, publicado el 2026-03-19, es la ÚLTIMA versión que existirá. El proyecto kubernetes/ingress-nginx fue retirado y su repositorio está archivado en modo solo lectura; no habrá más correcciones de errores ni parches de seguridad, nunca. Verificado el 2026-08-21 contra la API de GitHub, que reporta archived true para ese repositorio. El manifiesto sigue descargándose porque un repositorio archivado no se borra, y el laboratorio lo usa a propósito, con el pin explicito, porque Ingress sigue en el temario del CKA y porque saber que el citófono se quedó sin empresa que le haga mantenimiento es exactamente el tipo de cosa que un administrador tiene que saber. Para producción, lea la nota oficial del proyecto Kubernetes antes de instalar nada.
- IMÁGENES DE APLICACIÓN FIJADAS POR DIGEST, verificadas el 2026-08-21 con docker buildx imagetools inspect: nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de para los servidores web, busybox:1.37@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0 para los clientes que hacen wget en el Paso 3, y registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3@sha256:8b03e4185ecd305bc9b410faac15d486a3b1ef1946196d429245cdd3c7b152eb para el Pod de depuración de DNS del Paso 2, que es la imagen que usa la propia guía oficial de Kubernetes para depurar resolución de nombres. Un tag es mutable, un digest no.
- Haber leído los Capítulos 6, 7 y 8. Este laboratorio no vuelve a explicar qué es un Service, qué hace un EndpointSlice, por qué un podSelector vacío selecciona a todos, ni por qué crear un Ingress no basta para que suene el citófono; le hace operar las tres cosas contra un clúster real. El montaje del laboratorio le entrega además una avería deliberada, codificada en base64 para que usted no la lea de una ojeada en el setup. No es un escondite de verdad, es una cortesía para que usted diagnostique en vez de reconocer; la respuesta está en el campo cmd del Paso 1.

## Pasos

El `0N-step.sh` está para que no se quede atascado: lea el paso, intente primero por su cuenta y corra el script cuando quiera comparar. Escribe también el archivo de respuesta que el paso pide, leyendo los valores del clúster vivo.

### 1. Cap. 6: La señora de la tienda contesta, y el directorio viejo sigue mandando a la casa verde (10 pts)

El Capítulo 6 dejó el barrio pintado: doña Rosa se trastea cada dos por tres, y usted no la pierde porque no pregunta por una dirección, pregunta por un nombre en la tienda de la esquina. Lo que pasa es que en Kubernetes la tienda de la esquina no adivina nada: el Service no sabe quién vive dónde, el Service sabe una lista de etiquetas, y el plano de control se encarga de traducir esa lista a un EndpointSlice con las IPs de los Pods que hoy, en este segundo, coinciden.

En este paso usted monta el Deployment de doña Rosa con dos replicas, le pone su Service ClusterIP, y comprueba en vivo que el EndpointSlice se lleno. Hasta ahí, todo bonito.

Y entonces se encuentra con el directorio viejo. El montaje del laboratorio ya dejó puesto un segundo Service en el mismo namespace, llamado directorio-viejo, que lleva ahí desde antes de que usted llegara, y que no tiene ni un endpoint. Ni uno. El objeto EndpointSlice existe, tiene nombre, tiene edad, y por dentro está vacío. No no no no, eso no es que el Service esté roto ni que Kubernetes se haya trabado: es que alguien escribió un selector que ya no le queda a nadie. Doña Rosa vivía en la casa verde, se trasladó a la azul, y el directorio nunca se actualizo.

Su trabajo es diagnosticarlo con las herramientas del capítulo, no adivinarlo: mire el selector del Service por un lado, mire las etiquetas de la plantilla del Deployment por el otro, y encuentre cuál de las dos claves no cuadra. Y después arréglelo por el lado correcto, que es el directorio, no la señora. Si usted trastea a doña Rosa de vuelta a la casa verde para que el papel viejo tenga la razón, arregló el síntoma y daño el barrio.

La avería venia codificada en base64 dentro del setup a propósito. No es un escondite serio, es una cortesía para que usted diagnostique en vez de reconocer; la respuesta completa está en el script NN-step.sh de este paso, cuando usted decida revelarlo.

ENTREGABLE: el Deployment dona-rosa con 2 replicas listas, los dos Services con endpoints, y el archivo `~/cka-comico-lab/p03/01-respuesta.txt`, exactamente 2 líneas:

```text
ENDPOINTS_TIENDA=<cuántas direcciones listas tiene el EndpointSlice de tienda-de-la-esquina>
SELECTOR_ARREGLADO=<clave>=<valor que quedó en el selector de directorio-viejo después de arreglarlo>
```

<details>
<summary>Qué debería ver</summary>

El Deployment queda con 2 de 2 replicas listas y sus Pods llevan las etiquetas app=dona-rosa y casa=azul. El EndpointSlice de tienda-de-la-esquina aparece con dos direcciones en la columna ENDPOINTS, las mismas IPs que muestran los Pods. El de directorio-viejo aparece con ENDPOINTS en <unset>, es decir vacío, aunque el objeto EndpointSlice sí existe. Al imprimir los dos jsonpath se ve el choque: el selector del Service dice casa: verde y las etiquetas del Deployment dicen casa: azul. Después del patch, el EndpointSlice de directorio-viejo se llena con exactamente las mismas dos direcciones que el otro.

</details>

```bash
./01-step.sh
./01-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 2. Cap. 6: El directorio del barrio contesta con una dirección, y con la lista entera cuando usted pregunta por las casas (10 pts)

Ya tiene la tienda de la esquina montada. Ahora falta la parte que el Capítulo 6 explicó y que casi nadie prueba: cómo hace un Pod, desde adentro, para encontrar esa dirección sin memorizarla. La respuesta es CoreDNS, y el nombre que hay que preguntar tiene una forma fija que a usted le van a poner en pantalla el día del examen: nombre-del-service, punto, namespace, punto, svc, punto, clúster.local.

Lo que pasa es que para hacer esa prueba usted necesita un Pod que traiga nslookup adentro, y ahí hay una trampa vieja: la imagen que uno tiene a la mano casi nunca lo trae, o lo trae roto. Este laboratorio usa la imagen de depuración de DNS que recomienda la propia guía oficial de Kubernetes, fijada por digest, para que el resultado sea el mismo en su máquina y en la mía.

Haga las dos consultas, en este orden, y quédese leyendo la salida completa en vez de la última línea. Fíjese en las primeras dos líneas: ahí sale 10.96.0.10#53, que NO es la respuesta, es la dirección del servidor que le contestó. Es CoreDNS diciendo aquí estoy. La respuesta viene más abajo, en el bloque Name/Address.

Y ahí viene lo bonito. La primera consulta, contra el Service normal, devuelve UNA dirección: la IP virtual del Service, la de la señora de la tienda. La segunda consulta, contra el Service headless que usted acaba de crear con clusterIP en None, devuelve DOS: no la dirección de la tienda, sino la lista completa de las casas, las IPs de los dos Pods, para que usted mismo escoja a cuál tocarle la puerta. Compare esas dos direcciones con las que muestra kubectl get pods -o wide y vera que son exactamente las mismas.

ENTREGABLE: el Service headless creado, el Pod el-visitante corriendo en el-barrio, y el archivo `~/cka-comico-lab/p03/02-respuesta.txt`, exactamente 3 líneas:

```text
NOMBRE_COMPLETO=<el nombre completo, con svc.clúster.local, que usted le pregunto al DNS por la tienda>
CLUSTERIP_POR_DNS=<la dirección que el DNS devolvió para ese nombre>
REGISTROS_HEADLESS=<cuántas direcciones devolvió el DNS para el Service headless>
```

<details>
<summary>Qué debería ver</summary>

El Service las-casas-mismas aparece en la lista con CLUSTER-IP en None, que es como kubectl muestra un Service headless. El primer nslookup imprime un único bloque Name/Address, y esa dirección coincide exactamente con lo que devuelve el jsonpath de spec.clusterIP de tienda-de-la-esquina. El segundo nslookup, contra el Service headless, imprime DOS bloques Name/Address con el mismo nombre repetido y dos direcciones distintas, y esas dos direcciones son las IPs de los dos Pods de dona-rosa que muestra kubectl get pods -o wide. En los dos casos, las primeras líneas de la salida traen la dirección del servidor DNS con el puerto pegado, 10.96.0.10#53, que es CoreDNS contestando, no una respuesta.

</details>

```bash
./02-step.sh
./02-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 3. Cap. 7: Primero mida que el barrio está abierto, y solo después ponga a Justo Segura de celador (10 pts)

El Capítulo 7 terminó con la advertencia más importante del libro entero: un NetworkPolicy es apenas un pedazo de texto guardado en la API, y si el CNI del clúster no sabe leerlo, usted puede aplicar la política más elegante del mundo, verla listada con kubectl get, y que el tráfico siga pasando igualito. Un celador de mentiras, y no es Justo Segura.

Por eso este clúster no se creó como los demás. Se creó con disableDefaultCNI en true y con Calico instalado encima, a propósito, para que usted practique lo que pasa en un clúster armado con kubeadm: arranca sin CNI y usted instala uno que aplique NetworkPolicy. Y lo que importa de esa pieza es una sola cosa: que el CNI aplique las políticas. Con uno que no las aplique, todo lo que usted está a punto de hacer sería decoración.

Y por eso el orden de este paso no se puede invertir. Primero MIDA. Antes de aplicar nada, haga los dos wget y vea con sus propios ojos que los dos salen con código 0: el barrio no tiene chapas, cualquiera entra a cualquier casa. Esa línea base no es un trámite, es la única manera de saber después que lo que cambio fue la política y no otra cosa.

Después ponga a Justo Segura, el celador, y póngalo en dos piezas, que es como se hace de verdad. La primera es la negación por defecto: podSelector vacío, o sea TODOS los Pods del namespace, policyTypes con Ingress, y ninguna regla adentro. Acuérdese de la trampa del capítulo: un podSelector vacío no selecciona a nadie, selecciona a todo el mundo. La segunda es la que abre una sola puerta: aplica a los Pods con rol=servidor y deja entrar unicamente a los que traigan la etiqueta acceso=permitido.

Y ahora repita la medición. La visita autorizada entra como si nada. La colada se queda parada cinco segundos completos y se rinde. Fíjese en ese detalle porque el examen lo pregunta de mil formas: no le contestan que no, sencillamente no le contestan. Un paquete bloqueado por política de red no rebota, se pierde, y por eso lo que usted ve es un tiempo agotado y no un connection refused.

ENTREGABLE: los tres Pods corriendo en el-conjunto con sus etiquetas, las dos NetworkPolicies aplicadas, y el archivo `~/cka-comico-lab/p03/03-respuesta.txt`, exactamente 2 líneas:

```text
SALIDA_AUTORIZADA=<el código de salida del wget de visita-autorizada DESPUÉS de aplicar las políticas>
SALIDA_COLADA=<el código de salida del wget de visita-colada DESPUÉS de aplicar las políticas>
```

<details>
<summary>Qué debería ver</summary>

En la línea base los dos wget devuelven código de salida 0: el barrio está abierto y cualquier Pod le habla a cualquier otro, tal como dice el modelo de red de Kubernetes. Después de aplicar las dos políticas, el wget de visita-autorizada sigue devolviendo 0, y el de visita-colada se queda callado cinco segundos completos y devuelve un código distinto de cero, que es como se ve un tiempo agotado y no un rechazo: nadie le contesta que no, sencillamente no le contesta. kubectl get networkpolicies lista las dos políticas, y la de negación por defecto aparece con POD-SELECTOR en <none>, que es como kubectl muestra el selector vacío que selecciona a todos.

</details>

```bash
./03-step.sh
./03-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 4. Cap. 8: Dos botones en el citófono, y cada uno suena donde tiene que sonar (10 pts)

El Capítulo 8 fue tajante en una sola cosa: el panel de botones puede estar perfectamente atornillado a la pared, pero si nadie conectó el cableado detrás, apretar cualquier botón no suena en ningún apartamento. Crear un Ingress no tiene ningún efecto sin un Ingress controller que lo atienda.

En este clúster el cableado ya está puesto: el setup instaló ingress-nginx, y aquí toca decir la verdad completa, la misma que dicen los prerrequisitos. Ese proyecto fue retirado en marzo de 2026 y su repositorio quedó archivado en solo lectura. La versión que usted tiene instalada, controller-v1.15.1, es la última que existirá: no habrá más parches, ni siquiera de seguridad. El citófono funciona, pero la empresa que le hacia mantenimiento cerró. Se lo decimos porque un administrador que instala un controlador sin saber eso está tomando una decisión sin la mitad de la información.

Su trabajo es el panel de botones. Monte dos apartamentos, cada uno su Deployment y su Service, cada uno sirviendo un texto distinto para que después no haya duda de cuál contestó. Después escriba UN Ingress con dos rutas, /101 y /302, cada una apuntando al Service que le corresponde.

Y no se salte ingressClassName. El Capítulo 8 explicó para que existe: un mismo clúster puede tener varios controladores instalados, y ese campo es el que dice, sin ambigüedad, cuál de ellos atiende esta lista de reglas. Antes de escribirlo, mire con kubectl get ingressclass cuál hay disponible y confirme con jsonpath cuál controlador la respalda, en vez de escribir nginx de memoria.

Para tocar el timbre desde afuera use curl contra el puerto 8080 del host, que el setup mapeó al puerto 80 del nodo, y mande el encabezado Host que la regla espera. Eso es exactamente lo que hace un navegador cuando alguien escribe el dominio, solo que sin necesitar DNS. Y de ñapa, haga el tercer curl con un host que no existe en ninguna regla, para ver que el citófono contesta 404: existe el panel, pero ese edificio no está en la lista.

ENTREGABLE: los dos Deployments con sus Services en el-edificio, el Ingress citofono con las dos rutas, y el archivo `~/cka-comico-lab/p03/04-respuesta.txt`, exactamente 2 líneas:

```text
CLASE_DEL_CITOFONO=<el valor de spec.ingressClassName que usted le puso al Ingress>
HOST_DEL_CITOFONO=<el host que declaro la regla del Ingress>
```

<details>
<summary>Qué debería ver</summary>

kubectl get ingressclass lista la clase nginx, y el jsonpath imprime k8s.io/ingress-nginx, que es el nombre del controlador que la atiende. El Ingress queda listado con CLASS en nginx, HOSTS en edificio.local y PORTS en 80. El describe muestra las dos rutas con sus backends y, debajo de cada una, las direcciones de los Pods de atrás, no solo el nombre del Service. El primer curl imprime APARTAMENTO 101 y el segundo imprime APARTAMENTO 302, cada uno saliendo del Service correcto. El tercer curl, con un host que no aparece en ninguna regla, devuelve HTTP 404: el citófono existe, pero ese edificio no.

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

- **Síntoma (step 1):** kubectl get endpointslices no devuelve nada para directorio-viejo
  **Qué hacer:** Revise que esté consultando el namespace el-barrio y que la etiqueta del filtro sea exactamente kubernetes.io/service-name=directorio-viejo. Ese es el nombre de etiqueta que el plano de control le pone a cada EndpointSlice para amarrarlo a su Service; escrito de cualquier otra forma, el filtro no encuentra nada y usted concluye que no existe cuando sí existe.

- **Síntoma (step 1):** El patch falla con un error que dice que la ruta no existe
  **Qué hacer:** Un patch de tipo json con la operación replace exige que la ruta ya exista. Si usted ya borro la clave casa del selector, la operación correcta es add en vez de replace, o más fácil, edite el Service con kubectl edit svc directorio-viejo -n el-barrio y deje el selector como debe quedar. La comprobación califica el estado final, no el comando que usted uso para llegar.

- **Síntoma (step 2):** nslookup contesta NXDOMAIN o server can't find
  **Qué hacer:** Casi siempre es el nombre, no el DNS. Confirme que escribió las cuatro partes: servicio.namespace.svc.clúster.local. Un Pod que vive en otro namespace no puede preguntar solo por el nombre corto, tiene que dar por lo menos servicio.namespace. Si el nombre completo tampoco resuelve, revise que los Pods de CoreDNS estén Running con $K -n kube-system get pods -l k8s-app=kube-dns.

- **Síntoma (step 2):** El Pod el-visitante se queda en ContainerCreating o ImagePullBackOff
  **Qué hacer:** La imagen de dnsutils pesa y viene de registry.k8s.io, no de docker.io. Deje que termine de bajar, y si el pull falla, mire el evento exacto con $K -n el-barrio describe pod el-visitante. Sin salida a internet en ese momento, ese Pod no arranca y el Paso 2 no se puede hacer.

- **Síntoma (step 3):** Después de aplicar las políticas, visita-colada sigue entrando con código 0
  **Qué hacer:** Ese es exactamente el síntoma del celador de mentiras (el que Justo Segura nunca sería), y lo primero que hay que descartar es el CNI. Confirme que Calico quedó vivo con $K get tigerastatus y que los Pods de calico-system están Running; si el clúster se creó sin disableDefaultCNI, o si Calico nunca terminó de instalarse, las políticas quedan guardadas en la API y no las aplica nadie. Lo segundo que hay que revisar es que las dos políticas estén en el namespace el-conjunto, no en default: un NetworkPolicy solo actúa dentro de su propio namespace.

- **Síntoma (step 3):** Ahora visita-autorizada tampoco entra
  **Qué hacer:** Revise la política que abre la puerta, en este orden. Que su podSelector apunte a rol=servidor, que es la etiqueta de casa-vecina y no la del cliente. Que la regla ingress traiga from con un podSelector que diga acceso=permitido. Y que el puerto declarado sea el 80 TCP, que es donde escucha nginx: una regla que abre el puerto equivocado se ve perfecta en el YAML y bloquea igual que si no existiera.

- **Síntoma (step 3):** wget: unrecognized option: -T
  **Qué hacer:** Ese error significa que el wget que corrió no es el de busybox. Confirme que los Pods cliente se crearon con la imagen busybox fijada por digest de este paso, y no con otra que usted tuviera a la mano. Si prefiere usar otra imagen, use su equivalente de tiempo de espera, pero deje un tiempo acotado: sin el, el wget de la visita colada se queda colgado y usted nunca ve el código de salida.

- **Síntoma (step 4):** curl devuelve 404 en las dos rutas
  **Qué hacer:** Revise tres cosas en este orden. Que esté mandando el encabezado Host y que coincida letra por letra con el host de la regla: sin ese encabezado, el controlador no encuentra ninguna regla que aplicar. Que esté pidiendo /101/ con la barra final, porque el contenido vive en un subdirectorio y nginx responde 301 hacia la barra si usted la omite. Y que el describe del Ingress muestre direcciones de Pods debajo de cada backend: si aparece vacío, el problema no es el citófono sino que el Service de atrás se quedó sin endpoints.

- **Síntoma (step 4):** curl no conecta con localhost:8080
  **Qué hacer:** Ese puerto solo existe porque el clúster se creó con extraPortMappings. Confirme con docker port cka-comico-p03-control-plane que el 8080 del host está mapeado al 80 del nodo; si no aparece, el clúster se creó sin el archivo kind-p03.yaml y hay que rehacerlo, porque extraPortMappings no se puede agregar a un clúster ya creado.

- **Síntoma (step 4):** kubectl apply del Ingress falla con un error del webhook de admisión
  **Qué hacer:** ingress-nginx instala un ValidatingWebhookConfiguration que revisa cada Ingress antes de aceptarlo. Si el controlador todavía no terminó de arrancar, ese webhook no responde y el apply falla. Espere a que el Pod del controlador esté listo con $K wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s y vuelva a aplicar.

## Para ir más lejos

- Borre la etiqueta casa del selector de directorio-viejo en vez de corregirle el valor, y observe que el Service sigue funcionando igual. Después explique con sus propias palabras por qué un selector con menos claves selecciona MÁS Pods, no menos, y qué pasaría si otro Deployment del mismo namespace también llevara la etiqueta app=dona-rosa.
- Escale el Deployment dona-rosa a 4 replicas y vuelva a hacer el nslookup contra el Service headless. Cuente los registros. Después baje a 1 replica y repita. Sin tocar el DNS ni el Service, el número de respuestas cambia solo, y eso le muestra de dónde sale de verdad la lista que contesta CoreDNS.
- Agregue una tercera política de egreso en el-conjunto que impida a visita-autorizada salir a cualquier lado excepto al DNS del clúster, y compruebe que ahora el wget por nombre falla mientras el wget por IP sigue pasando. Es el error de producción más común con NetworkPolicy: cerrar el egreso y olvidarse de abrir el puerto 53.
- Agregue una segunda regla de host al mismo Ingress, con otro host y una sola ruta, y compruebe con curl que el mismo controlador atiende los dos dominios sin que usted haya instalado nada nuevo. Eso es el hospedaje virtual basado en nombre del que habla la documentación oficial, en un solo objeto.

## Referencias

- Kubernetes Project, Service. The authority on ClusterIP as the default type, on the four Service types, and on the selector that binds a Service to its Pods, the basis for Step 1. https://kubernetes.io/docs/concepts/services-networking/service/
- Kubernetes Project, EndpointSlices. States that the control plane automatically creates EndpointSlices for any Service that has a selector and keeps them updated as the Pod set changes, and documents the kubernetes.io/service-name label used to filter them in Step 1. https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
- Kubernetes Project, DNS for Services and Pods. Documents the service.namespace.svc.cluster.local form queried in Step 2, and states that a headless Service resolves to the set of Pod IPs instead of a single virtual IP. https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
- Kubernetes Project, Debugging DNS Resolution. The source of the dnsutils debug Pod image used in Step 2. https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/
- Kubernetes Project, Network Policies. Documents podSelector, policyTypes and the ingress rule list, states that an empty podSelector selects all Pods in the namespace, and warns that network policies are implemented by the network plugin and that creating the resource without a controller that implements it has no effect, which is the entire justification for this lab's CNI choice in Step 3. https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Kubernetes Project, Cluster Networking. States the model this lab measures as its Step 3 baseline: all Pods can communicate with all other Pods without NAT. https://kubernetes.io/docs/concepts/services-networking/
- Project Calico, release v3.32.1. The pinned CNI release used by this lab's setup, the newest stable release as of 2026-08-21. https://github.com/projectcalico/calico/releases/tag/v3.32.1
- Project Calico, Installation API reference. Documents the operator.tigera.io/v1 Installation resource and its calicoNetwork.ipPools fields, which this lab writes by hand instead of using the published custom-resources.yaml so the pool does not land on 192.168.0.0/16. https://docs.tigera.io/calico/latest/reference/installation/api
- Kubernetes Project, Ingress. Defines the Ingress resource, the host, path, pathType and backend fields used in Step 4, and states that ingressClassName selects which controller serves the rules. https://kubernetes.io/docs/concepts/services-networking/ingress/
- Kubernetes Project, Ingress Controllers. States as its first prerequisite that you must have an Ingress controller to satisfy an Ingress and that creating the resource alone has no effect, the point Step 4 makes readers prove. https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/
- Kubernetes Project blog, joint statement on Ingress NGINX (2026-01-29). The primary source for this lab's disclosure that ingress-nginx was retired and receives no further releases, bug fixes or security patches. https://kubernetes.io/blog/2026/01/29/ingress-nginx-statement/
- kubernetes/ingress-nginx, release controller-v1.15.1 (2026-03-19). The final release of the project, and the source of the kind provider manifest this lab pins; the repository itself is archived read-only, verified 2026-08-21. https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.15.1
- kind Project, Configuration. Documents networking.disableDefaultCNI, networking.podSubnet and nodes[].extraPortMappings, the three settings this lab's cluster configuration depends on. https://kind.sigs.k8s.io/docs/user/configuration/
- kind Project, release v0.32.0. The source of the digest-pinned kindest/node:v1.36.1 image and of the instruction to pin node images by @sha256 rather than by tag. https://github.com/kubernetes-sigs/kind/releases/tag/v0.32.0

---

_Hecho con ❤️ por Luis Felipe Ariza Vesga._
