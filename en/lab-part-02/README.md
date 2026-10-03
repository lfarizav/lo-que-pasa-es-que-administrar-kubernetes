# Part II - Lab: changing the recipe without closing The Golden Spoon, walking it back when the customers complain, the reserved table that only opens with a wristband, the order that fits in no kitchen, and the menu the cook reads from the inside

- Time: 55 min
- Points: 40

## Objective

This is an Exam-Style lab: each step gives you only the objective and the end state that gets graded, and that step's exact command sequence lives in its NN-step.sh script for you to reveal after you have tried on your own first. Step 1 has you run a full rollout cycle (create a Deployment on a pinned image, change its image to a second pinned image, watch the status and the history, and walk it back with rollout undo), and grading demands that the live image is the original one again, that the Deployment's revision number is at least 3, and that every replica is Ready (Chapter 4). Step 2 has you reserve a node with a dedicated=cuchara-de-oro:NoSchedule taint and place a Deployment there that carries the correct toleration and also targets that node; the shortcut is named up front: removing the taint makes the symptom go away and fails the step, because the check verifies the taint is still in place and stands up its own untolerating probe that must land in Pending (Chapter 5). Step 3 has you request more memory than any node has, watch the Pod sit in Pending with its FailedScheduling event, and then fix it by lowering the request to a sane value; the check does not take the fix on its own word: it re-launches an oversized request of its own, computed from your nodes' real memory, and demands that one goes Pending (Chapter 5). Step 4 has you consume a ConfigMap as environment variables and a Secret mounted as a file inside a Pod, and the check enters the container with kubectl exec at grading time and compares what is inside against the live objects and against what you wrote down (Chapter 5). No check reads your command history: every one of them re-queries the cluster, and two of them create fresh probe resources and delete them to confirm the substrate really does what the lab assumes.

## Prerequisites

- A Linux machine with kind, kubectl and Docker on PATH, and at least 4 GB of free RAM. This lab brings up its OWN three-node kind cluster named cka-comico-p02 and writes its kubeconfig to a private file, ~/cka-comico-lab/p02/kubeconfig, which is not your everyday one. It never touches ~/.kube/config, your current context, or any other cluster you already have running. That is why EVERY command in this lab carries --kubeconfig; forget the flag once and kubectl points at a different cluster without telling you.
- Three nodes, not one. The cluster is created from a kind config file declaring one control-plane and two workers, because Steps 2 and 3 need more than one node for a taint and a memory shortfall to mean anything. On a single-node cluster those two steps cannot be demonstrated.
- Internet access when you set the lab up: kind pulls the node image and the Pods pull the two digest-pinned nginx images. Grading itself needs no internet, only the live cluster.
- PINNED VERSIONS, verified on 2026-08-21 on this same machine. kind v0.32.0 and kubectl v1.36.1. Node image kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, which is the default image kind v0.32.0 ships and which this lab declares explicitly in the config file so it does not depend on whichever kind you happen to have. Confirm what actually got installed with kind version and kubectl version --client, never from memory, and confirm your nodes' real version with kubectl get nodes.
- TWO container images pinned by digest, verified on 2026-08-21 against Docker Hub. The old one, nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236, and the new one, nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de. Two, because Step 1 needs something real to move to and to come back from. A tag is mutable, a digest is not, which is why the Step 1 check compares the full string with the digest and not the bare tag.
- Having read Chapters 4 and 5. This lab does not re-explain what a ReplicaSet is, the difference between a request and a limit, or what a toleration is for; it makes you operate all five against a real cluster and grades you on the end state.

## Steps

The `0N-step.sh` script is there so you never get stuck: read the step, try on your own first and run the script when you want to compare. It also writes the answer file the step asks for, reading the values off the live cluster.

### 1. Ch. 4: Changing the recipe with a full dining room, and walking it back when the customer complains (10 pts)

Chapter 4 left The Golden Spoon open and the lesson in place: you do not close the business to change the dish of the day. You pull one cook out, bring in the one with the new recipe, confirm they are actually serving, and only then pull the next one. Here's what's actually going on in Kubernetes: you do not run that dance by hand. The Deployment runs it, creating a new ReplicaSet and scaling the old one down, one at a time, while the dining room stays full.

This step has you operate the whole cycle, with the two halves people almost never practice together. The first half is the change: create the Deployment on the digest-pinned old image, then set its image to the new one. The second half is the one that saves your shift the day the new recipe comes out badly: rollout undo, and The Golden Spoon goes back to the previous recipe without closing either.

And here is the detail that confuses everyone: after the undo, rollout history does NOT show you three rows. It shows two, 2 and 3. Revision 1 did not vanish and was not deleted: Kubernetes reused that very same old ReplicaSet and annotated it as revision 3, because it is the same set of Pods you rolled back to. If you were expecting three rows and see two, do not panic and do not do anything again: look at the Deployment's revision annotation, which does say 3, and look at the two ReplicaSets with their revision numbers. The whole story is right there.

And yes, before it occurs to you: deleting the Deployment and creating it again on the old image leaves everything looking the same and does not pass this step. It is graded on purpose so that it does not pass.

DELIVERABLE: the receta-del-dia Deployment running in the cuchara-de-oro namespace on the old image with its three replicas Ready, and the file `~/cka-comico-lab/p02/01-respuesta.txt`, exactly 3 lines:

```text
REVISION_ACTUAL=<what the Deployment's deployment.kubernetes.io/revision annotation says now>
IMAGEN_ACTUAL=<the full image string running now, tag and digest>
REPLICAS_LISTAS=<what .status.readyReplicas says now>
```

<details>
<summary>What you should see</summary>

After the create, the revision annotation says 1. After set image it says 2, and rollout status narrates the replacement replica by replica until it prints that the Deployment rolled out successfully. At that moment rollout history lists TWO rows, revision 1 and revision 2. After rollout undo the annotation says 3, the live image ends in the a8b39bd9 digest again, and readyReplicas says 3. And here is the surprise you have to see with your own eyes: rollout history AFTER the undo still lists two rows, but now they are 2 and 3, not 1 and 2. Revision 1 was not lost, it was reused: Kubernetes re-annotated the old ReplicaSet as revision 3. That is why the ReplicaSet listing shows two objects, the one on the new image with DESEADAS at 0 and the one on the old image with DESEADAS at 3.

</details>

```bash
./01-step.sh
./01-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 2. Ch. 5: The reserved table, and the wristband you have to be wearing to sit at it (10 pts)

Chapter 5 talked about reserved tables and the wristband, and the exam's most expensive confusion lives right there. Here's what's actually going on: a taint and a nodeSelector are NOT the same thing and do not do the same job, and people mix them up because both sound like "where does this Pod go".

The taint belongs to the node and pushes away: it is the RESERVED sign on the table. No wristband, no sitting there, full stop. The toleration belongs to the Pod and is the wristband: it does not walk you to any table, it only gives you permission to sit at the reserved one IF the host sends you over. And the one who sends you over is the nodeSelector or the affinity. That is why a Pod with a toleration and no nodeSelector can end up seated anywhere in the room: it has the wristband, but nobody told it to go to the reserved table.

This step has you place all three pieces: the sign on the node, the wristband on the Pod, and the instruction to go there. Reserve one worker (never the control-plane, which already ships its own taint), label it, and roll out two replicas carrying both the toleration and the destination.

And now the warning, plainly and with no fine print, because it is the trap half the world falls into when something will not start: removing the taint. On exam day that "fixes" the symptom in four seconds and voids the whole question, because what they asked you to do was tolerate the reservation, not cancel it. Here this step is graded exactly that way: the check confirms the sign is still up and stands up its own wristband-less customer to confirm the table really does turn it away.

DELIVERABLE: the reserved worker with its taint in place, the turno-de-la-noche Deployment with both replicas Ready and both running on that node, and the file `~/cka-comico-lab/p02/02-respuesta.txt`, exactly 3 lines:

```text
NODO_RESERVADO=<the exact name of the node you reserved>
LLAVE_DEL_TAINT=<the key of the taint you applied>
EFECTO_DEL_TAINT=<the effect of the taint you applied>
```

<details>
<summary>What you should see</summary>

Before the taint, the query shows the control-plane already ships a node-role.kubernetes.io/control-plane:NoSchedule taint out of the box and that neither worker carries any. After the taint, the chosen worker reports exactly dedicated=cuchara-de-oro:NoSchedule. The Deployment's rollout finishes cleanly, and kubectl get pods -o wide shows BOTH replicas with the NODE column pointing at the same worker you reserved, neither on the other one.

</details>

```bash
./02-step.sh
./02-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 3. Ch. 5: The order that fits in no kitchen, and the customer left standing at the door (10 pts)

Chapter 5 said it outright: a request is not a wish, it is a booking. Here's what's actually going on: the scheduler does not look at how much memory the node is using right now, it looks at how much it has already promised. And if what you ask for does not fit in what any node has left to promise, the Pod does not start badly and does not crash: it simply does not start. It stands at the door, in Pending, with no IP and no node, waiting for a kitchen it fits in.

This step has you provoke that situation on purpose and then read it properly, which is the part the exam grades. First read how much memory each node really offers, through status.allocatable.memory, not through what you think the machine has. Then ask for four times that. And now the important part: do not sit there staring at STATUS Pending, which explains nothing. Go to the message. The PodScheduled condition and the FailedScheduling event tell you, with numbers, how many nodes were ruled out for each reason. You are going to see two different reasons living side by side there, and both are yours: some nodes were ruled out for insufficient memory and others for taints this Pod does not tolerate, because the control-plane ships its own and the Step 2 worker carries the one you put there yourself.

And here is the mistake not to make: the output above, the one from kubectl get pods, says Pending and nothing else. If you stop there, you do not know whether the problem is memory, CPU, a taint, a volume or a label. All five look exactly the same from outside. The message is the only thing that tells them apart.

Then fix it where it should be fixed: by lowering the request to a value that does fit. This step shares a cluster with Step 2, so if you already reserved the worker, the message will count that node among the ones ruled out by a taint; that is correct and expected, do not undo it.

DELIVERABLE: the pedido-gigante Deployment running with its request lowered, and the file `~/cka-comico-lab/p02/03-respuesta.txt`, exactly 3 lines:

```text
MEMORIA_PEDIDA_INICIAL=<the oversized memory value you asked for at first, exactly as you wrote it, for example 260984608Ki>
RAZON_DEL_EVENTO=<the reason field of the event the stuck Pod produced>
MOTIVO_EXACTO=<the TWO word phrase inside the message that names the resource that came up short, spelled exactly as the message spells it>
```

<details>
<summary>What you should see</summary>

The allocatable query tells you how much memory each node really offers, and the request you build is four times that figure, so it fits on none of them. The Pod shows STATUS Pending with the IP and NODE columns at <none>, because it was never assigned to any node. The PodScheduled condition message and the FailedScheduling event say the same thing in the shape 0/3 nodes are available, and inside they carry the phrase Insufficient memory counting how many nodes came up short, plus the count of the ones ruled out by untolerated taints (the control-plane and the worker you reserved in Step 2). After lowering the request to 64Mi the rollout finishes, the Pod shows Running with IP and NODE filled in, and the Deployment reports 64Mi.

</details>

```bash
./03-step.sh
./03-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 4. Ch. 5: The menu taped up in the kitchen, and the ingredient nobody says out loud (10 pts)

Chapter 5 put it this way: the recipe is taped to the kitchen wall and the ingredient that makes the flavor is not said out loud. Here's what's actually going on in Kubernetes: that is not a pretty metaphor, those are two different objects with two different ways of reaching the container, and the exam is going to ask you for both.

The ConfigMap arrives as environment variables: the container starts and already has them, without having read any file. The Secret arrives mounted as a file inside a folder: the container reads it when it wants to. And there is one difference that has to stick with you: environment variables are frozen when the container starts, and if you edit the ConfigMap afterwards, the already-running process never finds out. The mounted file does update on its own, with nothing restarting, though it takes a while.

And now the thing that has to be said out loud because half the world has it backwards: a Secret is NOT encrypted. It is base64 encoded, which is a way of writing bytes down, not a way of hiding them. You are going to confirm it yourself in this step: you will pipe the output through base64 -d and the whole phrase comes out in the clear, with nobody asking you for a key. What actually protects a Secret is the RBAC deciding who may read it and encryption at rest in etcd, not the base64.

And one detail that always surprises: when you run ls -l in the mounted folder, sazon.txt will not be a file, it will be a symlink to ..data/sazon.txt. That is normal and deliberate: it lets kubelet swap the content in one stroke so nobody ever reads half a file. cat reads it just the same.

DELIVERABLE: the ConfigMap and the Secret created, the el-cocinero Pod running with the ConfigMap as environment variables AND the Secret mounted as a file, and the file `~/cka-comico-lab/p02/04-respuesta.txt`, exactly 3 lines:

```text
PLATO_EN_EL_CONTENEDOR=<what printenv PLATO_DEL_DIA prints INSIDE the container>
SAZON_EN_EL_CONTENEDOR=<the full content of the mounted file, read INSIDE the container>
RUTA_DEL_SECRETO=<the absolute path of the secret's file inside the container>
```

<details>
<summary>What you should see</summary>

The ConfigMap comes out in YAML with both keys in plain text. The Secret comes out with the sazon.txt key in base64, and kubectl itself reminds you through the Opaque type that this is encoding, not encryption: the base64 -d command hands you the whole phrase in the clear without asking you for any credential. Inside the container, printenv PLATO_DEL_DIA prints sancocho and printenv PORCIONES prints 40, without you having written those values into the Pod manifest. And ls -l /etc/cuchara-de-oro shows something that surprises you the first time: sazon.txt is not a file, it is a symlink pointing at ..data/sazon.txt, which is how kubelet mounts secrets so it can update them atomically. cat reads it just fine anyway and returns exactly the same phrase base64 -d returned.

</details>

```bash
./04-step.sh
./04-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

## How to run it

```bash
./00-setup.sh
./01-step.sh && ./01-check.sh
./02-step.sh && ./02-check.sh
./03-step.sh && ./03-check.sh
./04-step.sh && ./04-check.sh
./99-teardown.sh
```

## Troubleshooting

- **Symptom (step 1):** rollout status hangs waiting and never finishes
  **What to do:** Look at the Pods with kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig -n cuchara-de-oro get pods. If they are in ImagePullBackOff, the machine is not pulling the pinned image; check connectivity and that the digest was copied whole, with no line breaks. If they are Pending, there is no node they fit on: that is exactly what Step 3 will teach you to read.

- **Symptom (step 1):** set image replies that it could not find the container you named
  **What to do:** kubectl create deployment names the container after the image repository, not after the Deployment. With nginx:1.28-alpine the container is called nginx, which is why the command says nginx=. Confirm it with kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig -n cuchara-de-oro get deployment receta-del-dia -o jsonpath='{.spec.template.spec.containers[0].name}' instead of guessing.

- **Symptom (step 2):** The Pods sit in Pending after applying the Deployment
  **What to do:** Read the whole message with kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig -n cuchara-de-oro describe pod <pod> and look at the Events section. If it says untolerated taint, you are missing the toleration or you wrote it with a different key, value or effect than the taint's. If it says didn't match Pod's node affinity/selector, the nodeSelector points at a label the node does not have: confirm the real label with kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig get node <nodo> --show-labels.

- **Symptom (step 2):** The replicas got split, one on each worker
  **What to do:** That means you added the toleration but NOT the destination: the Pod had a wristband and the scheduler seated it wherever there was room. A toleration authorizes, it does not steer. Add the nodeSelector (or a required nodeAffinity) pointing at the reserved node and apply again.

- **Symptom (step 3):** The oversized Pod does NOT go Pending, it starts just fine
  **What to do:** Almost always the requested value got mistyped and ended up small. Mi and M are not the same (1Mi is 1048576 bytes and 1M is 1000000), and a number with no suffix is read as BYTES, so memory: 200 is two hundred bytes, not two hundred of anything else. Check what actually landed in the object with kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig -n cuchara-de-oro get deployment pedido-gigante -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' and compare it against the nodes' allocatable.

- **Symptom (step 3):** The FailedScheduling event is gone by the time you go to write it down
  **What to do:** Kubernetes events are short-lived and expire on their own. If you already fixed the Deployment and lost the message, do not revive the oversized request on top of the good one: create a separate Deployment, under another name, with the same oversized request, read its message, and delete it. That is exactly what the check does when it grades you.

- **Symptom (step 4):** printenv inside the container does not find the variable
  **What to do:** Check two things, in this order. That the ConfigMap is in the SAME namespace as the Pod (a ConfigMap from another namespace cannot be referenced, and the Pod hangs in CreateContainerConfigError). And that envFrom hangs off the container, not off the Pod spec: it is spec.containers[].envFrom, one level deeper than where people put it the first time.

- **Symptom (step 4):** The secret's file does not show up in the mounted folder
  **What to do:** The file name comes from the Secret's KEY, not from the Secret's name or the volume's. If you created the Secret with --from-literal=sazon=... the key is sazon and the file is called sazon, with no extension. Confirm the real keys with kubectl --kubeconfig ~/cka-comico-lab/p02/kubeconfig -n cuchara-de-oro get secret receta-secreta -o jsonpath='{.data}' before guessing the path.

## Going further

- Go back to the Step 1 Deployment and make it a second image change, this time without --record, which modern kubectl has retired: instead record the reason with kubectl annotate deployment receta-del-dia kubernetes.io/change-cause='...' before changing the image, then watch rollout history actually fill the CHANGE-CAUSE column. Then use rollout undo --to-revision=<n> to go back to a specific revision instead of the previous one, and watch which revision number you end up with.
- Change the Step 2 taint's effect from NoSchedule to NoExecute on a node that already has Pods running without the matching toleration, and watch what happens to them. NoSchedule only stops new ones from arriving; NoExecute evicts the ones that were already there. Then add tolerationSeconds to the toleration and watch the Pod survive that long before being pulled out.
- Create a ResourceQuota and a LimitRange in the cuchara-de-oro namespace and retry Step 3's oversized request. You will see a key difference: with a quota the object is rejected at the door by the API server, with a different message and without ever coming into existence, whereas without a quota the object is created perfectly and only then sits in Pending. It is the difference between having your booking refused and having your booking accepted with no table free.
- Edit the Step 4 ConfigMap with kubectl edit and change PLATO_DEL_DIA's value. Then run printenv inside the container again and confirm the variable did NOT change. Now change the Secret's value and keep watching the mounted file with watch cat: after a while it does change on its own. There, with your own hands, is the difference between an environment variable frozen at container start and a volume kubelet keeps in sync.

## References

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
