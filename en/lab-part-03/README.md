# Part III - Lab: the neighborhood directory that went stale, the corner shop lady who still answers, Justo Segura, a watchman who really does lock the door, and an intercom that rings in the right apartment

- Time: 60 min
- Points: 40

## Objective

This is an Exam-Style lab: each step states only the objective, and that step's exact command sequence lives in its NN-step.sh script for you to reveal after you have tried on your own first. Step 1 has you build a Deployment with its ClusterIP Service and confirm live that the EndpointSlice filled in, and it also hands you a second Service that the lab setup shipped deliberately broken: you have to diagnose why it has no endpoints at all and fix it without touching the Deployment (Chapter 6). Step 2 has you resolve the Service's fully qualified name from a debug Pod on a pinned image, record the ClusterIP that DNS returned, and see with your own eyes that a headless Service returns not one address but the whole list of houses (Chapter 6). Step 3 is what really separates this lab from a blog post: you first measure that traffic between two Pods passes unrestricted, then apply a default-deny policy plus a policy that opens exactly one door by label, and prove with exit codes that the authorized visitor gets in while the gatecrasher waits until time runs out (Chapter 7). Step 4 closes on the street door: you create an Ingress with two paths to two different Services and confirm each intercom button rings in the right apartment, travelling through the real controller (Chapter 8). No check reads your command history: every one of them re-queries the cluster at grading time, and three of them generate fresh traffic of their own to confirm the control is still standing.

## Prerequisites

- A Linux machine with kind, kubectl, docker, curl and base64 on PATH, and at least 4 GB of free RAM. The lab creates its own kind cluster named cka-comico-p03 and writes its kubeconfig to a private file, ~/cka-comico-lab/p03/kubeconfig, which is not your usual one. Every command in the lab passes --kubeconfig pointing at that file, so your ~/.kube/config is never modified and no other cluster of yours is touched. The teardown deletes only the cka-comico-p03 cluster and the ~/cka-comico-lab/p03 folder.
- Host port 8080 free. The cluster is created with an extraPortMapping taking host 8080 to the node's port 80, which is how you ring the Step 4 intercom from outside. Confirm with ss -ltn before you start; if it is taken, change the number in kind-p03.yaml and in the Step 4 commands.
- Internet access when you set the lab up: the setup downloads the Calico and Ingress controller manifests plus container images from quay.io, registry.k8s.io and docker.io. Grading itself needs no internet, only the live cluster and host port 8080.
- NODE IMAGE PINNED BY DIGEST, taken from the kind v0.32.0 binary itself on 2026-08-21: kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5. The kind release notes say you must use the @sha256 digest to guarantee an image built for that release, not just the tag. Confirm yours with kind version and docker images --digests, never from memory.
- PINNED CNI: Calico v3.32.1, the newest stable release on 2026-08-21 per the project's releases. This piece is not decoration. The cluster is created with disableDefaultCNI set to true to resemble a cluster built with kubeadm, which starts with no CNI at all and where you install one yourself that enforces NetworkPolicy; Calico is a common choice. Recent kind releases already ship their own CNI that enforces NetworkPolicy, so here Calico is part of the exercise and not a kind requirement. What matters is that the CNI enforces the policies, because without that the whole of Step 3 would be theatre, exactly the lying watchman of Chapter 7, the one Justo Segura would never be. Watch one detail that costs dearly: the custom-resources.yaml that Calico publishes defaults to an IP pool of 192.168.0.0/16, which is the range of nearly every home network. That is why this lab does not use that file: it writes its own Installation resource with cidr 10.244.0.0/16, the same podSubnet declared to kind. Confirm the pool that actually came up with kubectl get ippools -o wide.
- PINNED INGRESS CONTROLLER, and here the whole truth has to be said: ingress-nginx controller-v1.15.1, published 2026-03-19, is the LAST version that will ever exist. The kubernetes/ingress-nginx project was retired and its repository is archived read-only; there will be no more bug fixes and no more security patches, ever. Verified on 2026-08-21 against the GitHub API, which reports archived true for that repository. The manifest still downloads because an archived repository is not deleted, and the lab uses it deliberately, with an explicit pin, because Ingress is still on the CKA curriculum and because knowing the intercom lost the company that used to maintain it is exactly the kind of thing an administrator has to know. For production, read the official Kubernetes statement before installing anything.
- APPLICATION IMAGES PINNED BY DIGEST, verified on 2026-08-21 with docker buildx imagetools inspect: nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de for the web servers, busybox:1.37@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0 for the clients that run wget in Step 3, and registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3@sha256:8b03e4185ecd305bc9b410faac15d486a3b1ef1946196d429245cdd3c7b152eb for the Step 2 DNS debug Pod, which is the image Kubernetes' own name resolution debugging guide uses. A tag is mutable, a digest is not.
- Having read Chapters 6, 7 and 8. This lab does not re-explain what a Service is, what an EndpointSlice does, why an empty podSelector selects everything, or why creating an Ingress is not enough to make the intercom ring; it makes you operate all three against a real cluster. The lab setup also hands you a deliberate fault, base64-encoded so you cannot read it at a glance in the setup. That is not real concealment, it is a courtesy so you diagnose instead of recognize; the answer is in Step 1's cmd field.

## Steps

The `0N-step.sh` script is there so you never get stuck: read the step, try on your own first and run the script when you want to compare. It also writes the answer file the step asks for, reading the values off the live cluster.

### 1. Ch. 6: The corner shop lady answers, and the old directory still sends you to the green house (10 pts)

Chapter 6 painted the neighborhood: dona Rosa moves house constantly, and you never lose her because you do not ask for an address, you ask for a name at the corner shop. Here's what's actually going on in Kubernetes: the corner shop guesses nothing. A Service does not know who lives where, a Service knows a list of labels, and the control plane translates that list into an EndpointSlice holding the IPs of the Pods that match today, this second.

In this step you build dona Rosa's Deployment with two replicas, give it its ClusterIP Service, and confirm live that the EndpointSlice filled in. So far, so pretty.

And then you run into the old directory. The lab setup already left a second Service in the same namespace, called directorio-viejo, that has been sitting there since before you arrived, and that has no endpoints at all. Not one. The EndpointSlice object exists, it has a name, it has an age, and inside it is empty. That is not a broken Service and Kubernetes has not jammed: somebody wrote a selector that no longer fits anybody. Dona Rosa used to live in the green house, she moved to the blue one, and the directory was never updated.

Your job is to diagnose it with the chapter's own tools, not to guess it: look at the Service's selector on one side, look at the Deployment's pod template labels on the other, and find which of the two keys does not line up. Then fix it on the correct side, which is the directory, not the lady. If you move dona Rosa back into the green house so the old piece of paper turns out to be right, you fixed the symptom and broke the neighborhood.

The fault came base64-encoded inside the setup on purpose. It is not serious concealment, it is a courtesy so you diagnose instead of recognize; the full answer is in this step's NN-step.sh script, whenever you decide to reveal it.

DELIVERABLE: the dona-rosa Deployment with 2 ready replicas, both Services carrying endpoints, and the file `~/cka-comico-lab/p03/01-respuesta.txt`, exactly 2 lines:

```text
ENDPOINTS_TIENDA=<how many ready addresses the tienda-de-la-esquina EndpointSlice holds>
SELECTOR_ARREGLADO=<key>=<the value left in the directorio-viejo selector after you fixed it>
```

<details>
<summary>What you should see</summary>

The Deployment ends up with 2 of 2 replicas ready and its Pods carry the labels app=dona-rosa and casa=azul. The EndpointSlice for tienda-de-la-esquina shows two addresses in the ENDPOINTS column, the same IPs the Pods show. The one for directorio-viejo shows ENDPOINTS as <unset>, meaning empty, even though the EndpointSlice object itself does exist. Printing the two jsonpaths reveals the clash: the Service selector says casa: verde while the Deployment labels say casa: azul. After the patch, the directorio-viejo EndpointSlice fills up with exactly the same two addresses as the other one.

</details>

```bash
./01-step.sh
./01-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 2. Ch. 6: The neighborhood directory answers with one address, and with the whole list when you ask for the houses (10 pts)

You have the corner shop up. Now for the part Chapter 6 explained and almost nobody tests: how a Pod, from the inside, finds that address without memorizing it. The answer is CoreDNS, and the name you have to ask for has a fixed shape they will put on your screen on exam day: service-name, dot, namespace, dot, svc, dot, cluster.local.

Here's what's actually going on: to run that test you need a Pod with nslookup inside it, and there is an old trap there. The image you happen to have around usually does not carry it, or carries it broken. This lab uses the DNS debugging image that Kubernetes' own official guide recommends, pinned by digest, so the result is the same on your machine and on mine.

Run both queries, in this order, and stay to read the whole output instead of the last line. Look at the first two lines: that is where 10.96.0.10#53 appears, which is NOT the answer, it is the address of the server that answered you. That is CoreDNS saying here I am. The answer comes further down, in the Name/Address block.

And then comes the good part. The first query, against the ordinary Service, returns ONE address: the Service's virtual IP, the corner shop lady's. The second query, against the headless Service you just created with clusterIP set to None, returns TWO: not the shop's address but the full list of houses, the IPs of the two Pods, so you can choose whose door to knock on yourself. Compare those two addresses with what kubectl get pods -o wide shows and you will see they are exactly the same.

DELIVERABLE: the headless Service created, the el-visitante Pod running in el-barrio, and the file `~/cka-comico-lab/p03/02-respuesta.txt`, exactly 3 lines:

```text
NOMBRE_COMPLETO=<the full name, ending in svc.cluster.local, that you asked DNS about the shop>
CLUSTERIP_POR_DNS=<the address DNS returned for that name>
REGISTROS_HEADLESS=<how many addresses DNS returned for the headless Service>
```

<details>
<summary>What you should see</summary>

The las-casas-mismas Service shows up in the list with CLUSTER-IP as None, which is how kubectl displays a headless Service. The first nslookup prints a single Name/Address block, and that address matches exactly what the spec.clusterIP jsonpath of tienda-de-la-esquina returns. The second nslookup, against the headless Service, prints TWO Name/Address blocks with the same name repeated and two different addresses, and those two addresses are the IPs of the two dona-rosa Pods that kubectl get pods -o wide shows. In both cases the first lines of the output carry the DNS server's address with the port attached, 10.96.0.10#53, which is CoreDNS answering, not an answer.

</details>

```bash
./02-step.sh
./02-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 3. Ch. 7: First measure that the neighborhood is wide open, and only then post watchman Justo Segura (10 pts)

Chapter 7 ended on the most important warning in the whole book: a NetworkPolicy is just a piece of text stored in the API, and if the cluster's CNI cannot read it, you can apply the most elegant policy in the world, watch it listed by kubectl get, and see traffic keep flowing exactly as before. A lying watchman, and not Justo Segura.

That is why this cluster was not created like the others. It was created with disableDefaultCNI set to true and Calico installed on top, deliberately, so you practice what happens on a cluster built with kubeadm: it starts with no CNI and you install one that enforces NetworkPolicy. And what matters about that piece is a single thing: that the CNI enforces the policies. With one that does not, everything you are about to do would be decoration.

And that is why this step's order cannot be reversed. MEASURE first. Before applying anything, run both wgets and see with your own eyes that both exit 0: the neighborhood has no locks, anyone walks into any house. That baseline is not paperwork, it is the only way to know afterwards that what changed was the policy and not something else.

Then post Justo Segura, the watchman, and post him in two pieces, which is how it is really done. The first is the default deny: empty podSelector, meaning ALL Pods in the namespace, policyTypes carrying Ingress, and no rule inside. Remember the chapter's trap: an empty podSelector does not select nobody, it selects everybody. The second is the one that opens a single door: it applies to Pods with rol=servidor and lets in only those carrying the label acceso=permitido.

Now repeat the measurement. The authorized visitor walks in as if nothing happened. The gatecrasher stands there for a full five seconds and gives up. Notice that detail because the exam asks it a thousand ways: nobody tells it no, nobody answers it at all. A packet blocked by a network policy does not bounce, it is dropped, and that is why what you see is a timeout and not a connection refused.

DELIVERABLE: the three Pods running in el-conjunto with their labels, both NetworkPolicies applied, and the file `~/cka-comico-lab/p03/03-respuesta.txt`, exactly 2 lines:

```text
SALIDA_AUTORIZADA=<the exit code of visita-autorizada's wget AFTER applying the policies>
SALIDA_COLADA=<the exit code of visita-colada's wget AFTER applying the policies>
```

<details>
<summary>What you should see</summary>

In the baseline both wgets return exit code 0: the neighborhood is wide open and any Pod talks to any other, exactly as the Kubernetes networking model says. After applying both policies, visita-autorizada's wget still returns 0, and visita-colada's goes silent for a full five seconds and returns a non-zero code, which is what a timeout looks like rather than a refusal: nobody tells it no, nobody answers it at all. kubectl get networkpolicies lists both policies, and the default-deny one shows POD-SELECTOR as <none>, which is how kubectl displays the empty selector that selects everything.

</details>

```bash
./03-step.sh
./03-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 4. Ch. 8: Two buttons on the intercom, and each one rings where it should (10 pts)

Chapter 8 was blunt about one thing: the button panel can be perfectly bolted to the wall, but if nobody wired it up behind, pressing any button rings in no apartment at all. Creating an Ingress has no effect without an Ingress controller to serve it.

On this cluster the wiring is already in place: the setup installed ingress-nginx, and here the whole truth has to be said, the same truth the prerequisites tell. That project was retired in March 2026 and its repository is archived read-only. The version you have installed, controller-v1.15.1, is the last one that will ever exist: no more patches, not even security ones. The intercom works, but the company that used to maintain it shut down. We tell you because an administrator who installs a controller without knowing that is making a decision with half the information missing.

Your job is the button panel. Build two apartments, each with its Deployment and its Service, each serving different text so there is no doubt afterwards about which one answered. Then write ONE Ingress with two paths, /101 and /302, each pointing at the Service it belongs to.

And do not skip ingressClassName. Chapter 8 explained what it is for: a single cluster can have several controllers installed, and that field is what says, unambiguously, which of them serves this list of rules. Before writing it, look at what is available with kubectl get ingressclass and confirm with jsonpath which controller backs it, instead of typing nginx from memory.

To ring the bell from outside, use curl against host port 8080, which the setup mapped to the node's port 80, and send the Host header the rule expects. That is exactly what a browser does when somebody types the domain, only without needing DNS. As a bonus, run a third curl with a host that exists in no rule, and watch the intercom answer 404: the panel is there, but that building is not on the list.

DELIVERABLE: both Deployments with their Services in el-edificio, the citofono Ingress with both paths, and the file `~/cka-comico-lab/p03/04-respuesta.txt`, exactly 2 lines:

```text
CLASE_DEL_CITOFONO=<the spec.ingressClassName value you gave the Ingress>
HOST_DEL_CITOFONO=<the host the Ingress rule declared>
```

<details>
<summary>What you should see</summary>

kubectl get ingressclass lists the nginx class, and the jsonpath prints k8s.io/ingress-nginx, the name of the controller that serves it. The Ingress is listed with CLASS nginx, HOSTS edificio.local and PORTS 80. The describe shows both paths with their backends and, under each one, the addresses of the Pods behind them, not just the Service name. The first curl prints APARTAMENTO 101 and the second prints APARTAMENTO 302, each coming out of the correct Service. The third curl, with a host that appears in no rule, returns HTTP 404: the intercom exists, but that building does not.

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

- **Symptom (step 1):** kubectl get endpointslices returns nothing for directorio-viejo
  **What to do:** Confirm you are querying the el-barrio namespace and that the filter label is exactly kubernetes.io/service-name=directorio-viejo. That is the label name the control plane puts on every EndpointSlice to bind it to its Service; written any other way the filter finds nothing and you conclude it does not exist when it does.

- **Symptom (step 1):** The patch fails with an error saying the path does not exist
  **What to do:** A json-type patch with the replace operation requires the path to already exist. If you already deleted the casa key from the selector, the right operation is add instead of replace, or more simply edit the Service with kubectl edit svc directorio-viejo -n el-barrio and leave the selector as it should be. The check grades the end state, not the command you used to get there.

- **Symptom (step 2):** nslookup answers NXDOMAIN or server can't find
  **What to do:** It is almost always the name, not DNS. Confirm you typed all four parts: service.namespace.svc.cluster.local. A Pod living in another namespace cannot ask for the short name alone, it has to give at least service.namespace. If the full name does not resolve either, check that the CoreDNS Pods are Running with $K -n kube-system get pods -l k8s-app=kube-dns.

- **Symptom (step 2):** The el-visitante Pod stays in ContainerCreating or ImagePullBackOff
  **What to do:** The dnsutils image is heavy and comes from registry.k8s.io, not docker.io. Let the download finish, and if the pull fails look at the exact event with $K -n el-barrio describe pod el-visitante. With no internet access at that moment that Pod does not start and Step 2 cannot be done.

- **Symptom (step 3):** After applying the policies, visita-colada still gets in with exit code 0
  **What to do:** That is exactly the lying watchman's symptom (the one Justo Segura would never be), and the first thing to rule out is the CNI. Confirm Calico came up with $K get tigerastatus and that the calico-system Pods are Running; if the cluster was created without disableDefaultCNI, or Calico never finished installing, the policies sit in the API and nobody enforces them. The second thing to check is that both policies are in the el-conjunto namespace and not in default: a NetworkPolicy only acts inside its own namespace.

- **Symptom (step 3):** Now visita-autorizada cannot get in either
  **What to do:** Check the policy that opens the door, in this order. That its podSelector points at rol=servidor, which is casa-vecina's label and not the client's. That the ingress rule carries a from with a podSelector saying acceso=permitido. And that the declared port is 80 TCP, which is where nginx listens: a rule opening the wrong port looks perfect in the YAML and blocks just as if it did not exist.

- **Symptom (step 3):** wget: unrecognized option: -T
  **What to do:** That error means the wget that ran is not busybox's. Confirm the client Pods were created with this step's digest-pinned busybox image and not with something else you had lying around. If you prefer another image, use its timeout equivalent, but do leave a bounded timeout: without one, the gatecrasher's wget hangs and you never see the exit code.

- **Symptom (step 4):** curl returns 404 on both paths
  **What to do:** Check three things in this order. That you are sending the Host header and that it matches the rule's host letter for letter: without that header the controller finds no rule to apply. That you are requesting /101/ with the trailing slash, because the content lives in a subdirectory and nginx answers 301 towards the slash if you leave it off. And that the Ingress describe shows Pod addresses under each backend: if it comes up empty, the problem is not the intercom but that the Service behind it has no endpoints.

- **Symptom (step 4):** curl cannot connect to localhost:8080
  **What to do:** That port only exists because the cluster was created with extraPortMappings. Confirm with docker port cka-comico-p03-control-plane that host 8080 is mapped to the node's 80; if it does not show up, the cluster was created without the kind-p03.yaml file and has to be rebuilt, because extraPortMappings cannot be added to an existing cluster.

- **Symptom (step 4):** kubectl apply of the Ingress fails with an admission webhook error
  **What to do:** ingress-nginx installs a ValidatingWebhookConfiguration that reviews every Ingress before accepting it. If the controller has not finished starting, that webhook does not answer and the apply fails. Wait for the controller Pod to be ready with $K wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s and apply again.

## Going further

- Delete the casa key from directorio-viejo's selector instead of correcting its value, and observe that the Service keeps working just the same. Then explain in your own words why a selector with fewer keys selects MORE Pods, not fewer, and what would happen if another Deployment in the same namespace also carried the app=dona-rosa label.
- Scale the dona-rosa Deployment to 4 replicas and re-run the nslookup against the headless Service. Count the records. Then scale down to 1 replica and repeat. Without touching DNS or the Service, the number of answers changes on its own, and that shows you where the list CoreDNS answers with really comes from.
- Add a third, egress policy in el-conjunto stopping visita-autorizada from reaching anywhere except the cluster DNS, and confirm that wget by name now fails while wget by IP still passes. It is the most common production mistake with NetworkPolicy: closing egress and forgetting to open port 53.
- Add a second host rule to the same Ingress, with a different host and a single path, and confirm with curl that the same controller serves both domains without you installing anything new. That is the name-based virtual hosting the official documentation talks about, in a single object.

## References

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
