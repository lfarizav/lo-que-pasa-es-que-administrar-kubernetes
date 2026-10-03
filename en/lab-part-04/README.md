# Part IV - Lab: a storage room you build yourself, a pantry keeper who moves out and comes back, a builder, with its catalogue of lots, who breaks no ground until somebody signs, and a deed that outlives the contract

- Time: 55 min
- Points: 40

## Objective

This is an Exam-Style lab: each step tells you only the objective and the deliverable, and the exact command sequence lives in that step's NN-step.sh script for you to reveal after trying it first with your own hands. Step 1 has you do Chapter 9's full static provisioning: you build the storage room by hand (a hostPath PersistentVolume anchored to the worker node, with a fixed size) and then write the contract (a PersistentVolumeClaim) that has to bind to that room and no other, and grading demands the two point at each other, not that each separately says Bound. Step 2 moves the pantry keeper in: a Pod that mounts that PVC, writes a file inside the room, moves out (you delete the Pod), and moves back in; grading enters the live Pod, reads the file, and on top of that confirms the Pod really mounts the PVC and not an emptyDir in disguise. Step 3 moves to Chapter 10 and dynamic provisioning: you read off your own cluster which StorageClass is the default one and what volumeBindingMode it works with, create a PVC with no PV waiting for it, and demonstrate that it stays Pending while nobody consumes it and binds only when the first Pod shows up. Step 4 closes with the reclaim policy: you rescue a dynamically provisioned volume by changing its policy to Retain, delete its PVC, and demonstrate that the PV survives in Released state instead of disappearing, which is the difference between losing a customer's data and getting it back.

## Prerequisites

- A Linux machine with kind, kubectl and docker on PATH, internet access, and at least 4 GB of free RAM. This lab creates its own kind cluster named cka-comico-p04, with two nodes (one control-plane and one worker), and deletes it at the end. Everything it does goes through a private kubeconfig at ~/cka-comico-lab/p04/kubeconfig, passed with --kubeconfig on every single command: your usual kubeconfig is never touched, your current context never changes, and no other cluster of yours is affected. Do not run this lab against a production cluster.
- Versions pinned and verified on 2026-08-21 on the machine where this lab was executed: kind v0.32.0, node image kindest/node:v1.36.1 pinned by digest sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, and the workload image busybox:1.37.0 pinned by digest sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0. Confirm your kind with kind version and your kubectl with kubectl version --client before you start, rather than taking this paragraph's word for it.
- The two nodes are mandatory, not a luxury. Steps 1 and 2 anchor a hostPath PV to the worker node with nodeAffinity, and that anchor is the only thing guaranteeing that Step 2's recreated Pod comes back to the same disk where it left the file. On a single-node cluster the lab would appear to work while teaching you something false, so the setup script refuses to continue if it finds no worker.
- Step 2's grading uses date -u -d to convert an RFC 3339 timestamp into seconds since the epoch, which is GNU coreutils behavior. On an ordinary Linux machine it just works; on macOS with BSD date it does not, and you would need to install coreutils and use gdate.
- Having read Chapters 9 and 10. This lab does not re-explain what a PersistentVolume is, what each access mode means, or why dynamic provisioning exists; it makes you operate all four against a real cluster and grades them against its real state.

## Steps

The `0N-step.sh` script is there so you never get stuck: read the step, try on your own first and run the script when you want to compare. It also writes the answer file the step asks for, reading the values off the live cluster.

### 1. Ch. 9: You build the storage room, and then sign the contract that matches it (10 pts)

Chapter 9 explained that the estate's storage building is not the hallway of any house. This step has you build the storage room with your own hands, which is what static provisioning means: first the volume exists, and then somebody claims it.

What happens is that there are two objects here and a lot of people mix them up, because both end up saying Bound. The PersistentVolume is the physical storage room: it has a size, it has a real location on a disk, and it belongs to no namespace, because the estate's storage building does not belong to one house, it belongs to the whole estate. The PersistentVolumeClaim is the contract a house signs: it lives inside a namespace, it asks for a size and some access modes, and it neither knows nor cares where the room is. Among those access modes, ReadWriteOnce is the storage-building key handed to a whole work site (a node), whose people can all come in, and ReadWriteOncePod is the key with one single person's name on it. The controller is the manager who pairs them, and when it pairs them it writes the pairing on both sides: the PVC ends up with volumeName pointing at the PV, and the PV ends up with claimRef pointing at the PVC's namespace and name. That double annotation is what puts the room aside so nobody else can claim it.

Two details that cost points on exam day. The first: storageClassName set to the empty string is not the same as leaving the field out. The empty string means "I do not want anyone to provision anything for me, I want a volume that already exists"; leaving the field out gets you assigned the default class, and then a brand new volume is built for you while your hand-made storage room sits there, Available, watching. The second: the storage room is on a specific disk on a specific node, so you have to say so with nodeAffinity. Without that anchor the scheduler can send the Pod to the other node, where that directory does not exist, and you will swear Kubernetes deleted your data.

DELIVERABLE: the `deposito-de-la-finca` PV and the `contrato-de-la-cocina` PVC (in the cuchara-de-oro namespace) bound to each other, and the file `~/cka-comico-lab/p04/01-respuesta.txt`, exactly 2 lines:

```text
PV_DEL_CONTRATO=<the name the contrato-de-la-cocina PVC carries in its spec.volumeName field>
CLAIMREF_DEL_PV=<the namespace and name the deposito-de-la-finca PV carries in its claimRef, written as namespace/name>
```

<details>
<summary>What you should see</summary>

Freshly created, the PV shows up with STATUS Available and an empty CLAIM column: a storage room exists and nobody is claiming it yet. Seconds after applying the PVC, both queries change at once: the PV goes to Bound and now shows cuchara-de-oro/contrato-de-la-cocina under CLAIM, and the PVC goes to Bound showing deposito-de-la-finca under VOLUME. On the machine where this lab was executed the binding was already done on the loop's first pass, that is, in under five seconds. The two closing jsonpath queries print claimRef=cuchara-de-oro/contrato-de-la-cocina and volumeName=deposito-de-la-finca, which is the same pair seen from both sides.

</details>

```bash
./01-step.sh
./01-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 2. Ch. 9: The pantry keeper moves out, and on coming back the room still has their things (10 pts)

Chapter 9 said that what you keep in a house's hallway goes with the move, and what you keep in the storage room does not. This step verifies it with an actual move.

You mount Step 1's PVC inside a Pod, write a file in there, and then delete the Pod. Deleting the Pod is the move: the container disappears, its filesystem disappears, the IP disappears. Then you re-apply the same manifest and a new Pod comes in, which is not the same one even though it has the same name. What happens is that the file is still there, untouched, because it never lived in the Pod: it lived in the storage room, and the storage building belongs to the estate.

Watch out for the shortcut that looks innocent and is not. If you mount an emptyDir at /deposito and have the container write the file at startup, the cat will show you exactly the same thing. It looks identical and proves nothing, because an emptyDir is created empty every time the Pod is born and deleted along with it. That is why this step's grading is not satisfied by reading the file: it looks at how the volume is mounted, and it looks at the file's age against the Pod's age. A file older than the Pod reading it is the one piece of evidence an emptyDir cannot manufacture.

And one more thing, which is expensive on exam day: notice which node the Pod landed on. It landed on the worker, and that was neither coincidence nor the scheduler's luck: it was the nodeAffinity you put on the PV in Step 1. If the storage room is on one node's disk, the pantry keeper has to live on that node.

DELIVERABLE: the `despensero` Pod running in the cuchara-de-oro namespace with the `contrato-de-la-cocina` PVC mounted at /deposito, the file `/deposito/marca.txt` written by an earlier Pod and surviving the move, and the file `~/cka-comico-lab/p04/02-respuesta.txt`, exactly 2 lines:

```text
MARCA=<the exact content of /deposito/marca.txt, read from the recreated Pod>
VOLUMEN_DEL_POD=<the name of the PVC the Pod declares in its volumes list>
```

<details>
<summary>What you should see</summary>

The first Pod ends up Running on the worker node, not on the control-plane, because Step 1's PV nodeAffinity forced the scheduler to send it there. The file is written and read without drama. After deleting the Pod and re-applying the same manifest, the new Pod has a different IP and a different identity, and the cat still prints the same content as before. The final comparison is the hard proof: on the machine where this lab was executed the file's mtime was 1787318413 and the recreated Pod's startTime was 1787318448, that is, the file is 35 seconds older than the Pod reading it. Your two numbers will be different ones; what cannot change is which of the two is smaller.

</details>

```bash
./02-step.sh
./02-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 3. Ch. 10: The builder breaks no ground until somebody says where they will live (10 pts)

Up to here you have played bricklayer. Chapter 10 introduces the builder: you stop making storage rooms by hand and start ordering them. A PVC that names no volume, on top of a StorageClass, and the builder turns up with the ground ready.

Start by reading your own cluster's catalog, not this book's. Which StorageClass carries the default annotation, which provisioner backs it, what volumeBindingMode it works with, and while you are there whether it allows expansion. On a kind cluster the answer will be Rancher's local-path provisioner, but you have to see that on your own screen, because on exam day the default class can be any other one and the habit of reading it before using it is exactly what is being trained.

What happens is that after creating the PVC absolutely nothing will happen, and that is correct. Fifteen seconds will pass, thirty, as many as you like, and the PVC will still be Pending, with no volumeName, and no new PV will exist. It is not an error, it is volumeBindingMode: WaitForFirstConsumer doing what it promises: the builder breaks no ground until you say which lot you are going to live on, because the lot is chosen according to where the scheduler is going to put the Pod. The PVC's events spell it out. The moment you create the Pod that consumes it, the binding happens and a PV with a UID for a name appears, written by nobody.

One limitation worth stating honestly, because this lab is not going to hide it behind a fake exercise: on this substrate the default class does not allow expanding a PVC. The allowVolumeExpansion field is not even set, which is the same as saying false, and that is why there is no expansion step here. Chapter 10 teaches you to read that field before promising anyone a volume can grow, and that reading is precisely what you have just done.

DELIVERABLE: the `lote-por-encargo` PVC bound to a PV you did not create, the `constructor` Pod running and consuming it, and the file `~/cka-comico-lab/p04/03-respuesta.txt`, exactly 3 lines:

```text
APROVISIONADOR=<the provisioner of this cluster's default StorageClass>
MODO_DE_ENLACE=<the volumeBindingMode of that same StorageClass>
FASE_SIN_CONSUMIDOR=<the phase lote-por-encargo was in while no Pod was using it>
```

<details>
<summary>What you should see</summary>

The first query shows you a single StorageClass marked (default), and the four properties read with jsonpath say, on the cluster where this lab was executed: provisioner rancher.io/local-path, volumeBindingMode WaitForFirstConsumer, reclaimPolicy Delete and allowVolumeExpansion empty, meaning the field is not even set. Fifteen seconds after creation the PVC is still Pending, its volumeName prints as an empty pair of brackets, no new PV exists, and the describe event says waiting for first consumer to be created before binding with reason WaitForFirstConsumer. The moment the Pod comes in, the PVC goes Bound against a newborn PV whose name starts with pvc- followed by a UID, with the provisioned-by annotation set to rancher.io/local-path, storageClassName standard and reclaimPolicy Delete.

</details>

```bash
./03-step.sh
./03-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 4. Ch. 9 and 10: The contract ends, and the deed does not go in the bin (10 pts)

This is the step that separates whoever knows the theory from whoever has actually saved data. Chapter 9 taught you the reclaim policies and Chapter 10 taught you that the StorageClass is what decides which one the volumes it provisions are born with. Here the two chapters meet in the real operation: somebody is going to delete a PVC, and whether the data can be recovered or not depends on what you did beforehand.

What happens is that the builder's default is to delete. The PV it creates is born with whatever policy the class dictates, and on this cluster that policy is Delete, which means that the day the PVC is deleted, the volume is deleted right behind it and the data goes with it, without asking and without confirmation. There is no recycle bin. That behavior is fine for a cache and a tragedy for a database, and the difference between the two situations is put there by the administrator, not by the builder.

So you do what an administrator who has already had the fright does: you change the policy on that one specific volume, from Delete to Retain, before anybody deletes anything. Then the deletion arrives, first the Pod and then the PVC (in that order, because a PVC a Pod is using does not get deleted, it sits waiting on the protection finalizer), and you stand there looking at the PV listing. The volume is still there. It is not Available, it is Released, which is different: it means its contract died but it stayed reserved in the deceased's name, precisely so that nobody else claims it by accident and writes over your data. The dead claim's claimRef is still written down, and clearing it is a conscious, manual decision rather than an oversight.

One last thing, and do not experiment with this out of curiosity on data you care about: putting Delete back on a PV that is already Released does not return it to the previous state. It is the execution order, and it is carried out within seconds.

This step needs Step 3's StorageClass to stay as it was, so do not modify it to get here.

DELIVERABLE: the PV left Released with a Retain policy and no PVC, the `lote-de-rescate` PVC deleted, and the file `~/cka-comico-lab/p04/04-respuesta.txt`, exactly 4 lines:

```text
PV_RESCATADO=<the name of the PV that outlived the death of its PVC>
POLITICA_ANTES=<the reclaim policy that PV was born with, inherited from the StorageClass>
POLITICA_DESPUES=<the reclaim policy you left on it>
FASE_FINAL=<the phase the PV ended up in after the PVC disappeared>
```

<details>
<summary>What you should see</summary>

The PV the builder provisions is born with the policy it inherited from the StorageClass, and on this cluster that policy is Delete: the politica ANTES line prints Delete. After the patch, the politica DESPUES line prints Retain, and that is the only change you made to the volume. When you delete the Pod and then the PVC, the PV does not disappear: on the machine where this lab was executed it was already Released on the loop's first pass, that is, in under five seconds. The closing PV listing shows it with STATUS Released, RECLAIM POLICY Retain and the CLAIM column still saying cuchara-de-oro/lote-de-rescate, even though the namespace's PVC listing no longer has that contract. That claimRef outliving the PVC is exactly what stops the volume from being handed to another claim by accident.

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

- **Symptom (step 1):** The PVC stays Pending forever and the PV keeps saying Available
  **What to do:** The controller only pairs what is compatible on all three dimensions at once: the PV's capacity must be greater than or equal to what the PVC asks for, every requested access mode must be in the PV's list, and storageClassName must match character for character. Compare the three fields side by side with kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig get pv deposito-de-la-finca -o yaml and kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig -n cuchara-de-oro get pvc contrato-de-la-cocina -o yaml, and check storageClassName above all: if the PVC says standard it is because you left the field out and the admission plugin filled it in for you. The PVC's events say it in words: kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig -n cuchara-de-oro describe pvc contrato-de-la-cocina.

- **Symptom (step 1):** You deleted the PVC to start over and now the PV says Released and refuses the new contract
  **What to do:** That is not a bug, it is exactly Chapter 9's Retain policy doing its job: the storage room is not deleted when the contract ends, but it stays reserved in the old contract's name, and that dead claimRef is what stops it from binding again. To make it available again you have to clear the reservation by hand with kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig patch pv deposito-de-la-finca -p '{"spec":{"claimRef":null}}'; the moment the claimRef is gone the PV goes to Available and the new PVC binds within seconds. Whatever data was inside is still there, because it was never deleted.

- **Symptom (step 2):** The Pod stays Pending and describe says something about node(s) had volume node affinity conflict
  **What to do:** The scheduler is doing its job: the PV is anchored to one node and you asked the Pod to run on another, almost always because of a hand-written nodeSelector or toleration. Compare which node the PV points at with kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig get pv deposito-de-la-finca -o jsonpath='{.spec.nodeAffinity}' and compare it with what the Pod asks for. The fix is to remove the Pod's surplus constraint, not to remove the PV's nodeAffinity: without that anchor the Pod could land on the other node, find the directory empty, and you would lose the entire proof.

- **Symptom (step 2):** The file reads back fine but the check fails and you cannot see why
  **What to do:** It is almost always the mtime. Run the same comparison grading runs, yourself: kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig -n cuchara-de-oro exec despensero -- stat -c '%Y' /deposito/marca.txt for the file's age, and date -u -d "$(kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig -n cuchara-de-oro get pod despensero -o jsonpath='{.status.startTime}')" +%s for the Pod's. If the file's number is greater than or equal to the Pod's, the file was written during this Pod's life and not the previous one's. Redo the step in the right order: write the file, then delete the Pod, then recreate it, and do not touch the file again.

- **Symptom (step 3):** The PVC binds immediately, without waiting for any Pod, and you never see the Pending
  **What to do:** Check the real volumeBindingMode of the class you got, with kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig get sc -o custom-columns=NAME:.metadata.name,MODE:.volumeBindingMode. If it says Immediate, binding happens as soon as the PVC is created and this step's behavior does not exist on your cluster; the setup script stops for precisely that reason, so if you got this far it is because somebody changed the class afterwards. The other possible cause is that your PVC bound to a static PV that was already Available and matched it on size and access modes, for instance if you left a volume loose from the earlier steps.

- **Symptom (step 3):** The constructor Pod stays Pending and so does the PVC
  **What to do:** With WaitForFirstConsumer the two wait on each other until the scheduler picks a node, so a Pod that cannot be scheduled for any other reason leaves the PVC frozen at Pending forever and looks like a storage problem without being one. Read the real cause in the Pod's events, with kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig -n cuchara-de-oro describe pod constructor, and check for taints, insufficient resources or an impossible nodeSelector. Fix the scheduling and the volume provisions itself.

- **Symptom (step 4):** The lote-de-rescate PVC sits in Terminating and never goes away
  **What to do:** It is the kubernetes.io/pvc-protection finalizer, and it is doing exactly what it should: Kubernetes will not let you delete a PVC while some Pod is using it, so that nobody pulls the floor out from under a live workload. See who is using it with kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig -n cuchara-de-oro describe pvc lote-de-rescate and look at the Used By line. Delete that Pod and the PVC finishes deleting on its own, within seconds. Never strip the finalizer by hand to hurry it along: that leaves orphaned objects and dangling mounts on the node.

- **Symptom (step 4):** You deleted the PVC and the PV vanished with it, and now there is nothing to grade
  **What to do:** The Retain patch did not land before the deletion, or it landed on a different PV. Always confirm the volume's policy before deleting anything, with kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig get pv, looking at the RECLAIM POLICY column of the volume whose CLAIM is cuchara-de-oro/lote-de-rescate. Since the volume no longer exists, this step is redone from scratch: create the PVC and the Pod again, wait for the PVC to go Bound, read the new PV's name, apply the patch, verify it says Retain, and only then delete. Order matters, and that is precisely this step's lesson.

## Going further

- Take the PV left in Released at the end of Step 4 and put it back into service as if it were a new volume: clear the dead contract's reservation with kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig patch pv <name> -p '{"spec":{"claimRef":null}}', confirm it goes to Available, and then create a new PVC with an empty storageClassName and the same size to see whether it binds. Afterwards, mounting it in a Pod, check whether the previous pantry keeper's data is still there. That answer is the strongest argument there is for having a written procedure to recycle Released volumes, instead of recycling them by eye.
- Create a second PVC with exactly the same access modes and the same size as Step 1's `contrato-de-la-cocina`, with an empty storageClassName, and leave it there. Observe that it stays Pending forever even though the deposito-de-la-finca PV exists and matches it on everything, and explain in your own words why: a PersistentVolume binds to exactly one claim at a time, and ReadWriteOnce never meant one Pod, it meant one node. It is one of the exam's most expensive confusions.
- Try to expand Step 3's `lote-por-encargo` PVC from 256Mi to 512Mi by editing it with kubectl edit, and read the error the API server returns you carefully. Then query kubectl --kubeconfig ~/cka-comico-lab/p04/kubeconfig get sc <class> -o jsonpath='{.allowVolumeExpansion}' and connect the two. This lab included no expansion step precisely because this substrate does not allow it, and watching it fail with your own hands is worth more than any book's table.
- Create your own StorageClass pointing at the same provisioner as the default one but with reclaimPolicy Retain, without marking it as the default class, and provision a PVC against it. Confirm the PV is born with Retain already, without you having to patch anything, and compare that way of working with Step 4's. Then ask yourself which of the two you would rather have written down the day a colleague deletes a production PVC at three in the morning.

## References

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
