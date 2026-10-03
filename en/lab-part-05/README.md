# Part V - Lab: The Golden Spoon restaurant that will not open, the node that stopped reporting, the load that does not fit in the warehouse, and the gatehouse that never puts the call through

- Time: 60 min
- Points: 40

## Objective

This is an Exam-Style lab and it is pure DIAGNOSTICS: each step states only the objective, and that step's exact command sequence lives in its NN-step.sh script for you to reveal AFTER you have tried to solve it with your own hands. All four steps start with the system already broken, because the setup script applies four faults from base64-encoded payloads. That is not cryptography and does not pretend to be: it is a courtesy blindfold, so you do not read the answer in the same script that breaks the cluster. The faults are identical for every reader on every run, and the full answer key sits in each step's NN-step.sh script. Step 1 hands you two dead Deployments in the same namespace for two different reasons, and you have to tell them apart with describe and events before fixing anything (Chapter 11). Step 2 hands you a node the API server no longer knows to be alive, and you have to reach the system service that stopped reporting and switch it back on (Chapter 12). Step 3 hands you a workload that never gets scheduled because it asks for more than fits, and you have to read the node's Allocatable with your own hands and adjust the request without deleting it (Chapter 13). Step 4 closes with an application unreachable for two stacked reasons, and you have to walk the whole path, Pod ready, endpoints, port and gatehouse, until a live curl from another Pod returns 200 (Chapter 14). No check believes what you wrote down: every one of them re-queries the cluster at grading time, one steps inside the node's container to ask the operating system directly, and another spins up a brand new Pod to confirm the control that was in the way is still in the way of whoever it should be.

## Prerequisites

- A disposable Linux x86_64 machine with kind, kubectl, docker (reachable without sudo), base64 and python3 3.10 or later on PATH, and at least 6 GB of free RAM. Confirm each tool with its own --version before you start, do not trust this prose. Verified on 2026-08-21 with kind v0.32.0, kubectl v1.36.1 and Docker 29.7.2.
- ISOLATION, and this one is not optional. The lab creates its own three-node kind cluster called cka-comico-p05 and writes its kubeconfig into a PRIVATE file, ~/cka-comico-lab/p05/kubeconfig, from the very first command. Every kubectl command in this lab carries --kubeconfig pointing at that file, and you must do the same. Never rely on the current context of your ~/.kube/config: if you have another cluster open, a kubectl delete without --kubeconfig lands on that one and not on this one. The lab touches no other cluster, context or container on your machine.
- IMAGES PINNED BY DIGEST, verified on 2026-08-21. The cluster nodes: kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, the image kind v0.32.0 declares as its own. The working Pods: nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de. Step 4's client Pod and the intruder Pod the check spins up: curlimages/curl@sha256:d94d07ba9e7d6de898b6d96c1a072f6f8266c687af78a74f380087a0addf5d17. A tag is mutable and a digest is not: the chapters teach you to look up the current version, the lab pins it so the exercise is reproducible.
- Internet egress during setup, to pull the three pinned images. Step 1 also needs internet for a less obvious reason: one of the two faults is an image tag that does not exist, and the node has to be able to ask the registry so the registry can answer that it is not there. Without internet that Pod fails for a different reason and the diagnosis changes. Grading itself needs no internet, only the live cluster and your machine's docker.
- Setup takes about two and a half minutes and hands the cluster back ALREADY BROKEN, on purpose. If you want to restart a step from scratch, run the full teardown and run setup again: the faults are applied during setup, not step by step. Teardown deletes exactly the cka-comico-p05 cluster and the ~/cka-comico-lab/p05 directory, nothing else.
- Having read Chapters 11 to 14. This lab does not re-explain the diagnostic triangle, what each node condition means, what Allocatable is, or why a Service can have endpoints and still not answer; it makes you operate all four against a real cluster that is already sick.

## Steps

The `0N-step.sh` script is there so you never get stuck: read the step, try on your own first and run the script when you want to compare. It also writes the answer file the step asks for, reading the values off the live cluster.

### 1. Ch. 11: Two patients in The Golden Spoon, and they do not have the same illness (10 pts)

Neither of the two kitchens opened at The Golden Spoon today, and the owner is already saying "the system is broken". Take it easy. Chapter 11 was very clear about this: a good doctor does not prescribe before examining, and two patients lying in the same ward have no obligation to have the same illness. There are exactly two patients here, `sancocho` and `bandeja`, both in the `cuchara-de-oro` namespace, both at 0/1, and the two illnesses are different.

Start with the thermometer, which is `kubectl get pods`. The first clue is already visible there: the STATUS column does not say the same thing on all four Pods. Continue with the medical history, which is `kubectl describe`, and scroll down to the events: the kubelet writes down there, in technical but perfectly readable English, exactly what it tried to do and why it could not. One of the two will tell you about an image it went looking for at the registry and was told does not exist. The other will tell you about something the Pod needed to have on hand before starting the container, and that was not in the house.

And here comes the part that separates the person who diagnoses from the person who guesses. Both fixes are easy ONCE you know which is which. The hard part is not mixing them up, because the guesser applies the same fix to both and breaks the one that was halfway working. `sancocho` is missing the correct image: the good one is the same one its ward mate is already using, pinned by digest, and you can read it off the cluster itself instead of inventing it. `bandeja` is missing a pointer to the ConfigMap that does exist, and watch out for the trap here: the price of lunch is read off the menu, not memorized. If you delete the `valueFrom` and type 15000 by hand into the manifest, the Pod boots, the number comes out right, the owner is happy, and you fixed nothing. The check will notice.

DELIVERABLE: both Deployments at 2/2, and the file `~/cka-comico-lab/p05/01-respuesta.txt`, exactly 4 lines:

```text
RAZON_SANCOCHO=<the steady-state reason sancocho's container shows, exactly as Kubernetes writes it>
RAZON_BANDEJA=<the reason bandeja's container shows, exactly as Kubernetes writes it>
RECURSO_FALTANTE=<the exact name of the object bandeja's manifest asked for and that does not exist>
TAG_INEXISTENTE=<only the image tag sancocho asked for and the registry does not have, without the repository name>
```

<details>
<summary>What you should see</summary>

Before you fix anything, kubectl get pods shows four Pods at 0/1 in TWO different states: sancocho's two in ImagePullBackOff and bandeja's two in CreateContainerConfigError. The first one's message says it could not resolve the reference docker.io/library/nginx:1.29-alpinita, which does not exist; the second one says, verbatim, configmap 'la-carta-vieja' not found. One honest detail: in the first few seconds sancocho may show ErrImagePull instead of ImagePullBackOff. That is the same failure before the kubelet enters its back-off; the steady state, and the one you should record, is ImagePullBackOff. After the fix both Deployments sit at 2/2 and printenv prints 15000.

</details>

```bash
./01-step.sh
./01-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 2. Ch. 12: The node that stopped answering the dispatcher's call (10 pts)

In a workshop you learn one thing fast: a car that will not start does not mean the engine is dead. Sometimes it is the battery, sometimes it ran out of fuel, and sometimes the alternator simply stopped reporting to the dashboard, and the dashboard, which knows nothing on its own, started lighting up red warning lamps.

That is a node in NotReady. Chapter 12 said it: the API server does not watch the nodes, the nodes report themselves. Each node's kubelet sends its status to the dispatcher every few seconds, and if the dispatcher stops receiving that report for a while, it does not conclude the node is dead, it concludes something far more honest: that it no longer knows. That is why the conditions do not go to False, they go to `Unknown`, and why the reason you will see written talks about the kubelet having stopped posting status, not about the node having caught fire.

Your job here has two halves and it is the second one almost nobody does. The first half is kubectl work: find which of the three nodes it is, and read its conditions with `describe node` until you have the exact reason and message. The second half is not kubectl work at all, because kubectl cannot repair an operating-system service. You have to go down to the node's floor. In a kind cluster each node is a Docker container running systemd inside, so the front door is `docker exec` and once inside you are on an ordinary Linux, with `systemctl` and `journalctl`, exactly as in Chapter 12.

And a warning about the shortcut, because it will be sitting there tempting you: if you delete the node from the cluster, `kubectl get nodes` stops showing you the problem. The red lamp goes out. The car is still stranded. The check counts nodes and it is going to ask for three.

DELIVERABLE: all three nodes Ready with their kubelet running, and the file `~/cka-comico-lab/p05/02-respuesta.txt`, exactly 3 lines:

```text
NODO_CAIDO=<the exact name of the node that was NotReady>
RAZON_CONDICION=<the reason Kubernetes wrote into that node's Ready condition>
SERVICIO_CULPABLE=<the name of the systemd service that was switched off inside the node>
```

<details>
<summary>What you should see</summary>

kubectl get nodes shows two nodes Ready and one NotReady. In describe node, all four conditions on that node (MemoryPressure, DiskPressure, PIDPressure and Ready) go to Unknown, with reason NodeStatusUnknown and the message 'Kubelet stopped posting node status.'. Inside the node's container, systemctl is-active kubelet answers inactive and exits non-zero. After systemctl start kubelet it answers active, and the node returns to Ready in about ten seconds. Notice the asymmetry in the timings: the node took roughly a minute to flip to NotReady when the kubelet died, but comes back to Ready almost immediately when it revives, because the first is a deadline expiring and the second is a fresh report arriving.

</details>

```bash
./02-step.sh
./02-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 3. Ch. 13: The load that asked for more warehouse than the warehouse has (10 pts)

In a neighborhood warehouse there is a rule nobody wrote down and everybody respects: you do not send the truck before asking whether the load fits. And the load that arrived today, whose name is `arroz`, asked for a warehouse that does not exist on this block or the next one.

Look at the symptom calmly, because this one does not resemble the other two. The Pod is not restarting, not failing, not downloading anything. It is `Pending`, which means it has not even been scheduled onto any node. Nobody rejected it for being bad: the scheduler rejected it for being big. And the scheduler, being well brought up, writes down exactly why in an event, node by node. Go and read it, because half the answer is there.

The other half is on the node, and this is where Chapter 13 asked you to make a distinction a lot of people forget: Capacity is not the same thing as Allocatable. Capacity is what the machine ships with; Allocatable is what is left after the node reserved its share for the operating system and for the kubelet itself. The scheduler looks only at Allocatable. Read it yourself with `describe node` or with jsonpath, because the number depends on YOUR machine and that is why this text cannot tell it to you.

And now the trap, which in this step is especially comfortable: you can delete the whole `resources` block, the Pod boots immediately and everything looks green. No. A Pod with no requests is a Pod the scheduler believes weighs nothing, and that is the one that later takes the whole node down with it. Fixing here means putting in a number that fits, not removing the number. The check demands both requests still be declared, with a sensible floor and with the real ceiling of the node the Pod landed on.

DELIVERABLE: the `arroz` Deployment at 1/1 with its requests in place, and the file `~/cka-comico-lab/p05/03-respuesta.txt`, exactly 3 lines:

```text
EVENTO=<the reason of the event with which the scheduler rejected the Pod, exactly as Kubernetes writes it>
CPU_ASIGNABLE=<the cpu Allocatable value of node cka-comico-p05-worker, exactly as the API reports it>
MEMORIA_ASIGNABLE=<the memory Allocatable value of that same node, exactly as the API reports it, suffix included>
```

<details>
<summary>What you should see</summary>

The arroz Pod sits in Pending with no node assigned, its PodScheduled condition False and reason Unschedulable. The scheduler's event is of type Warning and its reason is FailedScheduling, with a message that starts '0/3 nodes are available:' and enumerates why each node is ruled out: one for a taint the Pod does not tolerate (the control plane node) and the other two for Insufficient cpu and Insufficient memory. What your node reports as Allocatable depends on your machine, and that is exactly the point: the right answer is not in this text, it is in your cluster. After the adjustment the Pod goes Running within seconds, now with a node assigned.

</details>

```bash
./03-step.sh
./03-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 4. Ch. 14: The phone rings, the gatehouse is staffed, and the call never goes through (10 pts)

Nobody is answering the intercom in the residential complex, and three versions are already going around: that the network went down, that Justo Segura, the watchman, went to lunch, and that "this has never worked anyway". Chapter 14 left you the procedure for staying out of that conversation: you do not guess, you walk the path in order, and at each point you ask exactly one thing.

The first point is whether anyone is on duty. Look at the `portero` Deployment's Pods: if they are 1/1 and Running, stop blaming the application, because the application is standing. The second point is the directory, which in Kubernetes is the Service's EndpointSlice. Here comes a surprise worth more than the whole step: the directory is NOT empty. It has both addresses recorded. An empty directory means the selector finds nobody; a full directory means the selector is fine and the problem lies further down the line. Look carefully at that EndpointSlice's port column, and then look at which port the container actually declares. There is your wrongly written number: somebody wrote an extension into the directory that nobody in that apartment picks up.

Fix it and call again. And this is where the step stops being a port exercise and becomes a character exercise, because the call STILL does not go through. You did not make a mistake: there are two layers, and that is real life. The second one is the silent gatehouse, the `NetworkPolicy`, which turns nobody away with a message but simply does not let anyone through and leaves you waiting until you give up. Read it. You will see it authorizes one kind of resident, and the one calling is not one of those.

And now the temptation, which in this step is enormous and takes half a second: delete the NetworkPolicy and the intercom rings. It really rings, it returns 200, it looks perfect. And you have just taken the door off a building so one visitor could get in. The check spins up a new Pod, with a label nobody authorized, and asks the gatehouse whether it lets it in. If it does, you did not fix the call: you opened the complex.

DELIVERABLE: a curl from the `visitante` Pod returning 200 against the Service's DNS name, with the NetworkPolicy still standing and still filtering, and the file `~/cka-comico-lab/p05/04-respuesta.txt`, exactly 3 lines:

```text
TARGETPORT_MALO=<the targetPort the Service carried and that matched no port on the container>
TARGETPORT_BUENO=<the port the portero container actually declares>
POLITICA_CULPABLE=<the exact name of the NetworkPolicy object that was blocking the call>
```

<details>
<summary>What you should see</summary>

At first the curl from the visitante Pod hangs and ends in 'Connection timed out', with code 000 and curl exit 28. Both portero Pods are 1/1 and Running, and the Service's EndpointSlice DOES have the two IP addresses recorded: the directory is not empty, it is written wrong. The EndpointSlice's PORTS column says 8080 while the container declares port 80. After correcting targetPort to 80, the EndpointSlice switches to 80 and the curl STILL times out, because the second layer is missing. The solo-los-de-la-casa NetworkPolicy authorizes only Pods labeled app=residente, and the visitor is labeled app=visitante. When you add that authorization without deleting the policy, the curl answers 200 immediately.

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

- **Symptom (step 1):** sancocho's Pods show ErrImagePull instead of ImagePullBackOff, and the check fails
  **What to do:** They are the same failure at two different moments. ErrImagePull is the attempt that just failed; ImagePullBackOff is the kubelet saying it has had enough of retrying and will wait before the next attempt. The steady state, the one you see a minute after setup and the one the check asks for, is ImagePullBackOff. If you get the other one, wait thirty seconds and look again.

- **Symptom (step 1):** I fixed the image but the sancocho Deployment stalls halfway, with one new Pod and one old Pod
  **What to do:** That is the rolling update doing its job: the Deployment does not kill the old Pod until the new one is ready. With the good image, the new one is ready in seconds and the old one leaves on its own. Use kubectl rollout status deployment/sancocho to wait instead of re-running get pods every few seconds, and if it sits there for more than two minutes, check with describe that the new Pod is not failing for a different reason from the one you fixed.

- **Symptom (step 2):** I started the kubelet and systemctl says active, but the node still shows NotReady
  **What to do:** Give it five to fifteen seconds. The node does not return to Ready because the process started, it returns when the first fresh report reaches the API server and the API server updates the condition. Use kubectl wait --for=condition=Ready node/<name> --timeout=180s instead of re-running get nodes every few seconds. If it is still the same after two minutes, look at journalctl -u kubelet inside the node: it records whether the process started and then died again.

- **Symptom (step 2):** docker exec answers that it cannot find the node's container
  **What to do:** The container is named exactly like the node, and that name comes from kubectl get nodes: cka-comico-p05-worker2. Confirm with docker ps that the container is running. If it does not show up, what went down was not the kubelet but the node's whole container, and in that case the fix is docker start with that same name, not systemctl. That is a different fault from the one this step installed, so check you did not run a docker rm by accident.

- **Symptom (step 3):** I recorded memory Allocatable as 62Gi and the check fails
  **What to do:** The check compares exact text against what the API returns, and the API neither rounds nor converts: it reports memory in the unit it holds it in, for example 65246152Ki. Copy the value verbatim, suffix and all, from kubectl get node <name> -o jsonpath='{.status.allocatable.memory}'. Same with cpu: if the API says 24, write 24, not 24000m.

- **Symptom (step 3):** I lowered the request but the Pod is still Pending
  **What to do:** Look at the event again, because the scheduler's message changes when the reason changes. This Deployment carries a nodeSelector pinning it to node cka-comico-p05-worker on purpose, so Step 2's fault does not contaminate this step, which means the only node available to it is that one: if the number still does not fit there, it stays Pending even if it would fit elsewhere. And confirm the patch really applied, with kubectl get deployment arroz -o jsonpath of the requests block: a malformed patch returns an error and changes nothing.

- **Symptom (step 4):** I corrected targetPort and the curl still times out, and now I do not know whether the fix worked
  **What to do:** Confirm the layer you just fixed without depending on the curl: look at the PORTS column of kubectl get endpointslices, which should have flipped from 8080 to 80 within seconds. If it already says 80, that layer is good and what is missing is the other one. That is exactly the point of the step: there are two stacked faults and fixing the first one does not change the symptom. Move on to kubectl get networkpolicy in that namespace.

- **Symptom (step 4):** The curl answers 'Could not resolve host' instead of hanging
  **What to do:** That is no longer the gatehouse or the port, that is the switchboard: cluster DNS. A timeout means the name resolved and the connection did not go through; a resolution error means there was nobody to call in the first place. Check that the CoreDNS Pods are Running with kubectl -n kube-system get pods -l k8s-app=kube-dns, and confirm you are using the full name porteria.el-barrio.svc.cluster.local or running the curl from a Pod in the same namespace.

## Going further

- Go back to Step 1 and break bandeja a different way: leave the ConfigMap name correct but change the KEY to one that does not exist. Predict in writing, before applying anything, whether the reason you will see is the same CreateContainerConfigError or a different one, and then check. Record what you expected and what happened.
- In Step 2, instead of starting the kubelet right away, leave the node NotReady and schedule a one-replica Deployment onto that node. Observe how long the scheduler takes to decide and what event it leaves. Then measure the other side: with the node healthy, run kubectl drain on it with the flags Chapter 12 explains and watch where the Pods go. That is the difference between a node that fell over and a node you take out of service on purpose.
- In Step 3, instead of lowering the request, raise the arroz Deployment's replica count until the SUM of the requests exceeds the node's Allocatable. You will see some replicas start and others stay Pending, with the same event. That teaches you the scheduler does not compare one request against an empty node, it compares it against what is already reserved. Contrast it with the Allocated resources section describe node prints.
- In Step 4, do the check the other way around: instead of authorizing the visitor's label in the policy, give the visitante Pod the label the policy already authorized. Confirm the curl also returns 200 along that route and that the intruder Pod stays blocked. Both fixes are valid because both respect the control; write three lines on which one you would prefer in production and why.

## References

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
