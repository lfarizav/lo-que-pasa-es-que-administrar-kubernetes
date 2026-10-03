# Lo que pasa es que administrar Kubernetes

**Los laboratorios del libro.** · **The book's labs.**

Si usted llegó aquí desde el libro, está en el lugar correcto. Aquí están los cinco
laboratorios completos, uno por cada parte del libro, listos para clonar y ejecutar.

If you got here from the book, you are in the right place. These are the five labs,
one per part of the book, ready to clone and run.

---

## Español

### El libro

**Lo que pasa es que administrar Kubernetes.** *Guía completa de administración de Kubernetes en lenguaje sencillo.*
Catorce capítulos en cinco partes, con un laboratorio por parte. Cubre los dominios de la
certificación **CKA** (Certified Kubernetes Administrator): arquitectura, instalación y
configuración del clúster, cargas de trabajo y planificación, servicios y redes,
almacenamiento y diagnóstico de problemas. Es un libro con la misma apuesta del resto de la
serie: si usted entiende el mecanismo, no tiene que memorizar la respuesta. La analogía es
una finca con sus casas, sus llaves y sus cuadrillas, y el restaurante La Cuchara de Oro.

Material de estudio independiente. No está afiliado a la Linux Foundation ni a la Cloud
Native Computing Foundation, ni cuenta con su respaldo. Los laboratorios imitan el formato
de la certificación (tareas calificadas por el estado final del clúster) y nunca su contenido.

### Qué son estos laboratorios

Cada laboratorio es una práctica de 45 a 60 minutos de trabajo real contra un clúster de
verdad (kind, dentro de Docker). Cada paso le da un objetivo y un entregable, y se califica
por el **estado final del clúster**, no por lo que usted escribió ni por el camino que tomó.
Es el mismo formato de la certificación: una tarea, un clúster, un resultado verificable.

### Cuándo hacer cada laboratorio

Hay un laboratorio por cada parte del libro, y cada uno usa **todo** lo de esa parte, no
solo el último capítulo. El momento de hacerlo es cuando usted termina la parte completa.

| Termine de leer | Y entonces corra | Tiempo | Puntos |
|---|---|---|---|
| Capítulo 3, *Contratar los oficios: instalar, actualizar y respaldar la finca* (cierra la Parte 1) | `es/lab-part-01` | 60 min | 50 |
| Capítulo 5, *La lista de mercado del empleado: ConfigMaps, Secrets y dónde lo sientan a trabajar en La Cuchara de Oro* (cierra la Parte 2) | `es/lab-part-02` | 55 min | 40 |
| Capítulo 8, *La puerta de la calle: Ingress y la Gateway API* (cierra la Parte 3) | `es/lab-part-03` | 60 min | 40 |
| Capítulo 10, *Reservar el lote: aprovisionamiento dinámico y storage classes* (cierra la Parte 4) | `es/lab-part-04` | 55 min | 40 |
| Capítulo 14, *La llamada que no entra: diagnosticar servicios y redes* (cierra la Parte 5) | `es/lab-part-05` | 60 min | 40 |

### Antes de empezar

Necesita estas herramientas instaladas y funcionando:

| Herramienta | Para qué | Versión con la que se probó |
|---|---|---|
| `docker` | correr los nodos del clúster | 29.8.2 |
| `kind` | crear los clústeres de práctica | v0.33.0 |
| `kubectl` | hablarle al clúster | v1.37.0 |

Además, según el laboratorio: `jq` (todos), `openssl` y `curl` (Parte I), `curl` (Parte III) y
`python3` (Parte V). Versiones cercanas también sirven. Los clústeres se crean con la imagen
`kindest/node:v1.36.1`, fijada por digest, y los laboratorios necesitan internet al montarse.

### Empiece aquí

```bash
git clone https://github.com/lfarizav/lo-que-pasa-es-que-administrar-kubernetes.git
cd lo-que-pasa-es-que-administrar-kubernetes/es/lab-part-01
cat README.md
```

El repositorio tiene dos carpetas: `es/` (español) y `en/` (inglés). Los scripts son los
mismos; cambia el idioma del `README.md` de cada laboratorio. Cada laboratorio se corre
siempre igual: montaje, cada paso con su verificador, y desmontaje.

```bash
./00-setup.sh                  # crea el clúster y deja todo listo
./01-step.sh && ./01-check.sh  # haga el paso, compruebe que quedó bien
./02-step.sh && ./02-check.sh
./99-teardown.sh               # borra el clúster y el espacio de trabajo
```

El verificador imprime `ok` cuando el paso quedó bien y sale con error cuando no. Los
`0N-step.sh` están para que no se quede atascado, pero el laboratorio se aprovecha leyendo el
`README.md` y escribiendo usted los comandos: corra el script para comparar.

### Su clúster de todos los días no se toca

Cada laboratorio crea su propio clúster kind, con su propio archivo de kubeconfig en
`~/cka-comico-lab/pNN/kubeconfig`, y **todos** los `kubectl` del laboratorio pasan
`--kubeconfig` de forma explícita. Su `~/.kube/config` no se lee ni se modifica, y el
`99-teardown.sh` borra únicamente el clúster de ese laboratorio, por nombre. Sus otros
clústeres de kind siguen donde estaban. Nunca corra en producción un comando de un libro, de
un blog o de un video sin entender qué hace. Este libro incluido.

### Qué hace cada laboratorio

| | Capítulos | Laboratorio |
|---|---|---|
| 1 | 1 a 3 | quién trabaja en la finca por una hoja pegada en la pared, la llave que solo abre una casa, la persona y la herramienta que reciben cada una la suya, el cuaderno de obra que se guarda afuera, y el llavero nuevo que no puede más que la llave |
| 2 | 4 a 5 | cambiar la receta sin cerrar La Cuchara de Oro, devolverse cuando reclaman, la mesa reservada que solo entra con brazalete, el pedido que no cabe en ninguna cocina, y la carta que el cocinero lee por dentro |
| 3 | 6 a 8 | el directorio del barrio que quedó desactualizado, la señora de la tienda que sigue contestando, Justo Segura, un celador que de verdad cierra la puerta, y un citófono que suena en el apartamento correcto |
| 4 | 9 a 10 | un depósito que usted mismo construye, un despensero que se muda y vuelve, una constructora, con su catálogo de lotes, que no mueve tierra hasta que alguien firme, y unas escrituras que sobreviven al contrato |
| 5 | 11 a 14 | el restaurante La Cuchara de Oro que no abre, el nodo que dejó de reportarse, el bulto que no cabe en la bodega, y la portería que no pasa la llamada |

### Si algo no funciona

Revise primero el `README.md` del laboratorio (sección de problemas frecuentes). Si el
problema sigue, abra un issue contando qué comando falló, con la versión de Kubernetes y el
sistema operativo. Los reportes de error son bienvenidos.

---

## English

### The book

**Here's What's Actually Going On with Kubernetes Administration.** *The complete Kubernetes administration guide in plain language.*
Fourteen chapters in five parts, with one lab per part. It covers the domains of the **CKA**
(Certified Kubernetes Administrator) certification: cluster architecture, installation and
configuration, workloads and scheduling, services and networking, storage, and
troubleshooting. It makes the same bet as the rest of the series: once you understand the
mechanism, there is no answer left to memorize. The analogy is an estate with its houses,
its keys and its work crews, and the restaurant The Golden Spoon.

Independent study material. Not affiliated with, endorsed by, or sponsored by the Linux
Foundation or the Cloud Native Computing Foundation. The labs emulate the certification's
format (tasks graded on the final state of the cluster) and never its content.

### What these labs are

Each lab is 45 to 60 minutes of real work against a real cluster (kind, inside Docker). Each
step gives you an objective and a deliverable, and is graded on the **final state of the
cluster**, not on what you typed or the path you took. It is the same format as the
certification: a task, a cluster, a verifiable result.

### When to do each lab

There is one lab per part of the book, and each one uses **everything** in that part, not
just the last chapter. The moment to do it is when you finish the whole part.

| Finish reading | Then run | Time | Points |
|---|---|---|---|
| Chapter 3, *Hiring the trades: installing, upgrading, and backing up the estate* (closes Part 1) | `en/lab-part-01` | 60 min | 50 |
| Chapter 5, *The employee's grocery list: ConfigMaps, Secrets, and where they get seated to work at The Golden Spoon* (closes Part 2) | `en/lab-part-02` | 55 min | 40 |
| Chapter 8, *The street door: Ingress and the Gateway API* (closes Part 3) | `en/lab-part-03` | 60 min | 40 |
| Chapter 10, *Reserving the lot: dynamic provisioning and storage classes* (closes Part 4) | `en/lab-part-04` | 55 min | 40 |
| Chapter 14, *The call that won't connect: troubleshooting services and networking* (closes Part 5) | `en/lab-part-05` | 60 min | 40 |

### Before you start

You need these tools installed and working:

| Tool | What for | Version this was tested on |
|---|---|---|
| `docker` | running the cluster's nodes | 29.8.2 |
| `kind` | creating the practice clusters | v0.33.0 |
| `kubectl` | talking to the cluster | v1.37.0 |

Also, depending on the lab: `jq` (all), `openssl` and `curl` (Part I), `curl` (Part III) and
`python3` (Part V). Nearby versions are fine too. The clusters are created from
`kindest/node:v1.36.1`, pinned by digest, and the labs need internet access when they are set up.

### Start here

```bash
git clone https://github.com/lfarizav/lo-que-pasa-es-que-administrar-kubernetes.git
cd lo-que-pasa-es-que-administrar-kubernetes/en/lab-part-01
cat README.md
```

The repository has two folders: `es/` (Spanish) and `en/` (English). The scripts are the
same; what changes is the language of each lab's `README.md`. Every lab runs the same way:
setup, each step with its grader, and teardown.

```bash
./00-setup.sh                  # creates the cluster and gets everything ready
./01-step.sh && ./01-check.sh  # do the step, then check that it landed
./02-step.sh && ./02-check.sh
./99-teardown.sh               # deletes the cluster and the workspace
```

The grader prints `ok` when the step is right and exits with an error when it is not. The
`0N-step.sh` scripts are there so you never get stuck, but you get the most out of a lab by
reading its `README.md` and typing the commands yourself: run the script to compare.

### Your everyday cluster is never touched

Each lab creates its own kind cluster with its own kubeconfig file at
`~/cka-comico-lab/pNN/kubeconfig`, and **every** kubectl in the lab passes `--kubeconfig`
explicitly. Your `~/.kube/config` is neither read nor modified, and `99-teardown.sh` deletes
only that lab's cluster, by name. Your other kind clusters stay exactly where they were. Never
run a command from a book, a blog or a video on a production cluster without understanding
what it does. This book included.

### What each lab does

| | Chapters | Lab |
|---|---|---|
| 1 | 1 to 3 | who works the estate because of a sheet of paper on the wall, the key that opens one house only, the person and the tool that each get their own, the site notebook kept off site, and the new keyring that cannot do more than its key |
| 2 | 4 to 5 | changing the recipe without closing The Golden Spoon, walking it back when the customers complain, the reserved table that only opens with a wristband, the order that fits in no kitchen, and the menu the cook reads from the inside |
| 3 | 6 to 8 | the neighborhood directory that went stale, the corner shop lady who still answers, Justo Segura, a watchman who really does lock the door, and an intercom that rings in the right apartment |
| 4 | 9 to 10 | a storage room you build yourself, a pantry keeper who moves out and comes back, a builder, with its catalogue of lots, who breaks no ground until somebody signs, and a deed that outlives the contract |
| 5 | 11 to 14 | The Golden Spoon restaurant that will not open, the node that stopped reporting, the load that does not fit in the warehouse, and the gatehouse that never puts the call through |

### If something does not work

Check the lab's `README.md` first (troubleshooting section). If the problem persists, open an
issue saying which command failed, with your Kubernetes version and operating system. Bug
reports are welcome.

---

_Hecho con ❤️ por Luis Felipe Ariza Vesga._
