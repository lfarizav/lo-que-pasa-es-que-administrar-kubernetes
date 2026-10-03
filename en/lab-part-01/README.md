# Part I - Lab: who works the estate because of a sheet of paper on the wall, the key that opens one house only, the person and the tool that each get their own, the site notebook kept off site, and the new keyring that cannot do more than its key

- Time: 60 min
- Points: 50

## Objective

This is an Exam-Style lab: each step tells you only the objective and the deliverable, and that step's exact command sequence lives in its NN-step.sh script for you to reveal after you have tried on your own first. Step 1 has you open the estate up and separate two completely different ways of hiring staff: the components the kubelet starts by reading a folder of files on the node, without the kube-apiserver ever having authorized them, and the ones a cluster controller really does hand out (Chapter 1). Step 2 has you make a key: a ServiceAccount, a Role that only allows looking at Pods and a RoleBinding that hands it over inside one namespace, and then demands you prove that the key opens what it should and does NOT open either the forbidden verb or the neighbour's house (Chapter 2). Step 3 completes the keyring with the two kinds of key holder: a person, who in Kubernetes is not an object but a client certificate you request with a CertificateSigningRequest and put into the kubeconfig, and a tool, which is a ServiceAccount with its token; each gets a Role with different verbs, and you test with kubectl auth can-i, as the administrator with --as and with the key in hand, what each key opens and what it does not (Chapter 2). Step 4 has you take the etcd backup from inside the control-plane node, reading the certificate paths off the static Pod manifest instead of copying them from memory, and then move the file out of the node, because a backup living on the same disk as the original is not a backup (Chapter 3). Step 5 closes by assembling a new context with the Step 2 ServiceAccount's token and proving the keyring changes nothing: the new context reads Pods, and the same context is refused on delete by the very same RBAC (Chapters 2 and 3). No check reads your command history: all five re-query the live cluster at grading time, three of them fire their own authorization questions, and the backup one re-opens the file you pulled out of the node to confirm it is still an intact snapshot.

## Prerequisites

- A Linux machine with kind, kubectl, docker, jq, openssl and curl on PATH, and at least 3 GB of free RAM for the cluster. The lab creates its own kind cluster named cka-comico-p01 and deletes it in the teardown.
- ISOLATION, and this is not a matter of style. This lab's cluster NEVER touches your everyday kubeconfig: it is created with --kubeconfig ~/cka-comico-lab/p01/kubeconfig from the very first command, and absolutely every kubectl in the lab passes --kubeconfig and --context explicitly. If you already have other kind clusters running on this machine, this lab does not see them, does not modify them and does not delete them. Check it yourself: after the setup, a kubectl config get-contexts with no --kubeconfig must show no trace of cka-comico-p01.
- Internet access when you set the lab up: kind pulls the node image and the cluster pulls the digest-pinned pause image the test Pod uses. Grading itself needs no internet, only the live cluster and the Docker daemon.
- PINNED VERSIONS, verified on 2026-08-21 on this same machine. kind v0.32.0. Node image kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, which is that kind release's default image and which is passed explicitly here with --image because a tag is mutable and a digest is not. Test Pod image registry.k8s.io/pause:3.10@sha256:ee6521f290b2168b6e0935a181d4cff9be1ac3f505666ef0e3c98fae8199917a. That node ships Kubernetes v1.36.1 and etcd 3.6.8. Confirm what you actually got with kind version and kubectl version, never from memory: if your node ships a different etcd line, Step 4 changes tools on you and the lab explains that right where it happens.
- Having read Chapters 1 to 3. This lab does not re-explain what each control-plane component does, or the difference between Role and ClusterRole, or how a person authenticates compared with a tool, or what an etcd snapshot is for; it makes you operate all three against a real cluster and grades the end state.

## Steps

The `0N-step.sh` script is there so you never get stuck: read the step, try on your own first and run the script when you want to compare. It also writes the answer file the step asks for, reading the values off the live cluster.

### 1. Ch. 1: Who is on the estate payroll and who works off a sheet of paper on the wall (10 pts)

Chapter 1 introduced the whole estate: the kube-apiserver's single service window, the brain of the works, and each house's trades. Here's what's actually going on: the chapter left one question a drawing could not answer for you, and it is exactly the question the exam does ask. If the kube-apiserver is the window everything passes through, who gave the kube-apiserver permission to exist?

It did not give itself permission. In a kubeadm-built cluster the four control-plane components are not scheduled by the scheduler and not managed by any controller: the node's kubelet wakes up, looks at a folder of files on disk, and starts whatever it finds there. That folder is /etc/kubernetes/manifests, and those Pods are called static Pods. It is the worker who is not on the office payroll but shows up because there is a sheet of paper on the wall saying what to do.

And here is the detail that clicks and never leaves you: you still see them with kubectl get pods -n kube-system. That confuses a lot of people, because it looks as if the cluster manages them. What you are seeing is a mirror Pod, a read-only copy the kubelet publishes to the API server so you can tell what is running. The official static Pod documentation is explicit that deleting that mirror with kubectl does not kill the process: the kubelet publishes it again, because the truth does not live in the API server, it lives in the file.

Your job in this step is to demonstrate that difference with data read off your own cluster, not off a table. Get into the node container, count the manifests, then look at two fields on those Pods that give them away: who is listed as owner in ownerReferences, and what the kubernetes.io/config.source annotation says. Then do the same with kube-proxy, which really is a DaemonSet handed out by a controller, and compare.

DELIVERABLE: file `~/cka-comico-lab/p01/01-respuesta.txt`, exactly 4 lines:

```text
MANIFIESTOS_ESTATICOS=<how many files are in the control-plane node's /etc/kubernetes/manifests>
DUENO_DEL_APISERVER=<the ownerReferences[0].kind value on the kube-apiserver Pod>
FUENTE_DE_CONFIG=<the kubernetes.io/config.source annotation value on that same Pod>
DUENO_DEL_KUBE_PROXY=<the ownerReferences[0].kind value on a kube-proxy Pod>
```

<details>
<summary>What you should see</summary>

The control-plane node's /etc/kubernetes/manifests folder holds four YAML files and not one more: etcd.yaml, kube-apiserver.yaml, kube-controller-manager.yaml and kube-scheduler.yaml. The four matching Pods exist in kube-system named component plus hyphen plus node name, and on all four the first ownerReferences says Node, not ReplicaSet, not DaemonSet, nothing of the sort. The kubernetes.io/config.source annotation on those same Pods says file. kube-proxy, by contrast, shows up in the DaemonSet list, its Pod has an ownerReferences of kind DaemonSet, and the last docker exec fails saying /etc/kubernetes/manifests/kube-proxy.yaml does not exist. That error is the step's correct result, not a problem.

</details>

```bash
./01-step.sh
./01-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 2. Ch. 2: The housekeeper's key opens this house, not the whole estate (10 pts)

Chapter 2 left the whole keyring on the table: who you are, what they let you do, and the keys for the ones who are not people. Here's what's actually going on: reading the four RBAC objects in a table does not teach you the real lesson, because the real lesson is not in the definitions but in the scope, and scope only becomes visible when you try to open a door that is not yours.

In this step you make the housekeeper's key. A ServiceAccount, because this is not a person but a process. A Role called lector-de-pods with two verbs and nothing more, get and list, over pods and nothing more. And a RoleBinding handing that Role to that account, inside the la-casa namespace.

Then comes the part that separates whoever understood from whoever copied the YAML. Stand in front of the door and ask Justo Segura, the watchman, before forcing the lock, which is what kubectl auth can-i is for, and do it with --as to ask on someone else's behalf. Ask four things plus one for good measure: can it read Pods in la-casa? can it list them? can it delete them? can it read them in la-finca-vecina? can it do everything in la-casa? The answers must come back yes, yes, no, no, no, and each of those three negatives is a different lesson.

And here is the shortcut that will cost you the point: it is desperately tempting to hand the key over with a ClusterRoleBinding, because it works first try and nobody complains. It works too well: it opens the neighbouring estate as well. This step is graded precisely on what the account can NOT do, so the shortcut shows. What is valid, and Chapter 2 says so, is using a reusable ClusterRole handed over with a local RoleBinding: the key model is generic, the handover is for this house.

DELIVERABLE: the ServiceAccount, the Role and the grant applied and standing in the la-casa namespace, and the file `~/cka-comico-lab/p01/02-respuesta.txt`, exactly 4 lines:

```text
PUEDE_LEER_EN_LA_CASA=<the verbatim answer of auth can-i get pods in la-casa>
PUEDE_BORRAR_EN_LA_CASA=<the verbatim answer of auth can-i delete pods in la-casa>
PUEDE_LEER_EN_LA_VECINA=<the verbatim answer of auth can-i get pods in la-finca-vecina>
TIPO_DE_ENTREGA=<the Kind of the object that hands the permissions to the account>
```

<details>
<summary>What you should see</summary>

The three objects are created without noise. The Role shows a single rule, with apiGroups the empty string, resources pods and verbs get and list, nothing else. The RoleBinding's roleRef points at Role -> lector-de-pods. And the five auth can-i questions answer, in this exact order: yes, yes, no, no, no. Notice kubectl prints the word yes or the word no and also exits 0 on the affirmative and 1 on the negative, so it reads just as well for you as it scripts. The closing auth can-i --list prints the full table of what that account can do in the namespace, and delete is nowhere in it.

</details>

```bash
./02-step.sh
./02-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 3. Ch. 2: a person and a tool, each with its own key (10 pts)

Chapter 2 handed you the keyring and told you the estate has two kinds of key holders: people and tools. Here's what's actually going on, and it surprises you the first time: Kubernetes has no User object at all. There is no kubectl create user and no list of people stored in the API; if you ask kubectl get users, the server answers that it does not know that resource type. A person exists for the cluster only because they present something the kube-apiserver knows how to validate, and here that something is a client certificate signed by the cluster's own authority: the certificate's common name (CN) becomes the username, and the organization (O) becomes its group. The tool, by contrast, is an object in the cluster, a ServiceAccount, and its credential is a token requested with kubectl create token.

In this step you issue both keys and hand them out inside a single house, la-casa, with different verbs. For the person, marcela, follow the documented procedure for a normal user: generate a private key and a signing request with openssl using CN marcela and O cocina, send it to the cluster as a CertificateSigningRequest with signerName kubernetes.io/kube-apiserver-client and usages client auth, approve it with kubectl certificate approve, extract the issued certificate from .status.certificate and add it to THIS kubeconfig with config set-credentials and config set-context. For the tool, el-medidor, create the ServiceAccount. Then give each one its Role through a RoleBinding: marcela gets a Role called encargada with get, list, create and delete on Pods; el-medidor, a different Role called medidor with get, list and watch on Pods. Marcela's RoleBinding names a subject of kind User, which is precisely a name with no object behind it.

And test it with the two methods you will use on exam day. First as the administrator, asking on behalf of someone else with --as, which for the tool is system:serviceaccount:la-casa:el-medidor. Then with the key in hand, using the marcela context. Notice a revealing moment: before you hand out the Roles, marcela is already authenticated, auth whoami recognizes her, and she still gets Forbidden. Justo Segura, the watchman, recognizes her at the door, but recognizing her opens no house: authenticating (who you are) and authorizing (what you are allowed to do) are two different doors. The official documentation for the procedure is at https://kubernetes.io/docs/tasks/tls/certificate-issue-client-csr/ and the one for signer types at https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/.

DELIVERABLE: the approved marcela CertificateSigningRequest, the marcela context inside `~/cka-comico-lab/p01/kubeconfig` carrying the issued certificate, the el-medidor ServiceAccount, the two Roles and the two RoleBindings in la-casa, and the file `~/cka-comico-lab/p01/03-respuesta.txt`, exactly 4 lines:

```text
USUARIO_AUTENTICADO=<the Username auth whoami answers with the marcela context>
FIRMANTE_DE_LA_CSR=<the signerName of the CertificateSigningRequest>
LA_PERSONA_PUEDE_BORRAR=<the verbatim answer of auth can-i delete pods in la-casa using the marcela context>
LA_HERRAMIENTA_PUEDE_BORRAR=<the verbatim answer of auth can-i delete pods in la-casa using the el-medidor token>
```

<details>
<summary>What you should see</summary>

The first command fails with error: the server doesn't have a resource type "users": Kubernetes has no User object. openssl generates the private key and the signing request without printing anything relevant. The CertificateSigningRequest is created and first shows as Pending, and after kubectl certificate approve it changes to Approved,Issued. openssl x509 shows the issued certificate with subject O = cocina, CN = marcela and issuer CN = kubernetes, that is, the cluster's own authority. With the marcela context, auth whoami answers Username marcela and the group cocina plus system:authenticated, and yet get pods ends in Error from server (Forbidden) with the message User "marcela" cannot list resource "pods": the person is already authenticated and not yet authorized. After the two Roles and the two RoleBindings exist, the can-i loop prints, in order, for marcela and for el-medidor: get yes yes, create yes no, delete yes no, watch no yes; and the two questions about la-finca-vecina answer no. With marcela's own key in hand, delete pods answers yes, watch pods answers no, get pods in la-finca-vecina answers no, and get pods lists la-alarma. With the token, auth whoami answers system:serviceaccount:la-casa:el-medidor, get pods lists la-alarma and delete answers no.

</details>

```bash
./03-step.sh
./03-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 4. Ch. 3: The site notebook is kept off site, or it is not a backup (10 pts)

Chapter 3 said it without hedging: etcd is the site notebook where the estate's real state gets written down, and because it is the only one there is, it is the thing that most needs backing up. Here's what's actually going on: taking that backup has three details people forget in exactly this order, and this step forces all three on you.

The first is where the certificate paths come from. etcd talks to nobody without mutual TLS, not even the owner of the estate, so the command carries three certificate flags. The temptation is to copy them from memory or from a blog. You read them off etcd's static Pod manifest instead, the same file as Step 1, which is the only source that will not lie to you about your own cluster. A hand-built cluster, or one with certificates on a different path, and your memorized command fails on exam day.

The second is which tool. The official Kubernetes documentation gives you the command with ETCDCTL_API=3 and etcdctl, and that held for years. On this machine, with etcd 3.6.8, you are going to discover something with your own hands: the etcd container is a distroless image with no shell, so there is nowhere to put that environment variable prefix, and it is no longer needed anyway because etcdctl 3.6 speaks v3 natively. And there is more: ask etcdctl snapshot for help and you will see only save is left. status and restore moved to etcdutl, the tool meant to work directly on data files without a running etcd, exactly as Chapter 3 told you. The worst part of that change is that etcdctl snapshot status does not give you an error: it prints the help and exits 0, which means in a script it would pass as if it had worked.

The third is where the file ends up, and that one really decides whether this was a backup or theatre. A snapshot saved on the same disk that can be lost along with the original is not a backup, it is the illusion of one. Get it out of the node.

DELIVERABLE: the file `~/cka-comico-lab/p01/respaldo-de-la-finca.db` outside the node, and the file `~/cka-comico-lab/p01/04-respuesta.txt`, exactly 3 lines:

```text
RUTA_DEL_CERT_DE_SERVIDOR=<the path etcd's manifest declares in --cert-file>
REVISION_DEL_RESPALDO=<the revision the snapshot status reports>
TOTAL_DE_LLAVES=<the total key count the snapshot status reports>
```

<details>
<summary>What you should see</summary>

The manifest grep prints the three certificate paths etcd uses and the list of URLs it listens on, which start with https because etcd requires mutual TLS. etcdctl reports version 3.6.8 with API version 3.6. The snapshot save writes several JSON-formatted log lines and ends with Snapshot saved at /var/lib/etcd/respaldo-de-la-finca.db. The etcdctl snapshot --help shows you something surprising: on this etcd line the snapshot subcommand only has save, because status and restore moved to etcdutl. That is why status is queried with etcdutl, and the table returns five columns: HASH, REVISION, TOTAL KEYS, TOTAL SIZE and VERSION. The docker cp lands the file on your machine, and ls shows a size of around 1.2 MB. The table rounds the size, but repeat the status with --write-out=json and you will see the exact number, and the file on disk weighs exactly 32 bytes more than that totalSize: those extra 32 bytes are the integrity sha256 snapshot save appends at the end.

</details>

```bash
./04-step.sh
./04-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

### 5. Ch. 2 and 3: A new keyring, the same key, and a door that stays shut (10 pts)

Chapter 2 closed on the keyring, and Chapter 3 taught you to read the files the cluster writes on the node. This step joins the two in the single most misread object in all of Kubernetes: the kubeconfig.

Here's what's actually going on: an enormous number of people believe the kubeconfig is the security. It is not. The kubeconfig holds no permission at all: it is an address book with three sections that never mix. clusters stores where to go. users stores which credential to go with. contexts ties one cluster to one user and one namespace and gives that combination a name. That is the whole of it. Switching context is switching keyring, not switching lock.

And the way to prove it to yourself beyond argument is this: build a new context in the SAME file, pointing at the SAME cluster, and put the housekeeper's key from Step 2 into it, which you get with kubectl create token. Then use that context. You will be able to list the Pods in la-casa, because the Role allows it. And you will hit a Forbidden head on when you try to delete, because the Role does not include that verb, and the most elegant kubeconfig in the world will not add a verb RBAC did not give you.

Notice the detail on the delete, which is also a good exam habit: it is done with --dry-run=server. Authorization is evaluated before the dry run, so the refusal is just as real, but if for some reason the account DID have the permission, the Pod would not be deleted. It is the way to test a door without risking knocking it down.

DELIVERABLE: the new context inside `~/cka-comico-lab/p01/kubeconfig`, working, and the file `~/cka-comico-lab/p01/05-respuesta.txt`, exactly 4 lines:

```text
CONTEXTO_NUEVO=<the name you gave the new context>
USUARIO_DEL_CONTEXTO=<the users entry that context points at>
CLUSTER_DEL_CONTEXTO=<the clusters entry that context points at>
PALABRA_DEL_RECHAZO=<the word the API server puts in parentheses when it refuses the delete>
```

<details>
<summary>What you should see</summary>

The first query shows your private kubeconfig has two contexts: the admin one kind created and the marcela one you added in Step 3. create token returns a long string in three dot-separated parts. After the two config commands, get-contexts lists three contexts: the admin one, marcela and your new one, pointing at the SAME cluster but at a different user and with namespace la-casa. And then comes the demonstration: auth whoami answers that you are system:serviceaccount:la-casa:la-empleada, get pods lists la-alarma without trouble, the delete is refused with Error from server (Forbidden) saying verbatim that this user cannot delete the resource pods in that namespace, and the get pods in la-finca-vecina is refused with Forbidden too. The last line confirms la-alarma is still alive: the delete was refused before it touched anything.

</details>

```bash
./05-step.sh
./05-check.sh
```

The grader prints `ok` and exits 0 when the step is right and exits 1 when it is not. It does not take your word for it: it goes back and asks the live cluster.

## How to run it

```bash
./00-setup.sh
./01-step.sh && ./01-check.sh
./02-step.sh && ./02-check.sh
./03-step.sh && ./03-check.sh
./04-step.sh && ./04-check.sh
./05-step.sh && ./05-check.sh
./99-teardown.sh
```

## Troubleshooting

- **Symptom (step 1):** docker exec answers that the container does not exist
  **What to do:** The node container's name is not the cluster's name: kind appends the role suffix. Never type it by hand, derive it with kubectl get nodes or with kind get nodes --name cka-comico-p01, which is what both the step's command and the check do. If it still does not show up, confirm the cluster is running with kind get clusters.

- **Symptom (step 1):** The ownerReferences field comes back empty on some Pod
  **What to do:** Check you are querying the right Pod: a static Pod's name is the component plus a hyphen plus the node name, not just the component. A kubectl get pods -n kube-system shows you the full names. If you query a bare Pod you created yourself, ownerReferences really is empty, and that is precisely the third case this step does not ask you about.

- **Symptom (step 2):** auth can-i answers no to everything, even get pods in la-casa
  **What to do:** Almost always a mistyped subject. A ServiceAccount's username is system:serviceaccount:<namespace>:<name>, with colons and no spaces, and RBAC does not warn you when you ask about a subject that does not exist: it simply answers no, because that invented subject indeed cannot do anything. Compare your string character by character with the one kubectl -n la-casa describe rolebinding entrega-de-llave prints in its Subjects section.

- **Symptom (step 2):** auth can-i answers yes to get pods in la-finca-vecina
  **What to do:** The grant ended up cluster-scoped. Check with kubectl get clusterrolebindings -o wide whether one names you or the account, and delete it. Remember roleRef is immutable: if you picked the wrong object you cannot edit it, you have to delete the whole grant and make a new one, which is exactly what Chapter 2 says.

- **Symptom (step 3):** kubectl apply of the CertificateSigningRequest fails with a decoding error on spec.request, or the CSR exists but the certificate never shows up
  **What to do:** The request field must be the content of marcela.csr in base64 on ONE line. On Linux, base64 breaks the output into 76-character lines, which is why the command carries tr -d '\n'. If the CSR already exists from an earlier attempt, its spec cannot be edited: delete it with kubectl delete csr marcela and apply it again. If the signerName or the usages are different, the signer does not issue it; for a person it has to be kubernetes.io/kube-apiserver-client with client auth.

- **Symptom (step 3):** kubectl get csr marcela stays Pending, or is Approved but .status.certificate comes out empty
  **What to do:** Pending means kubectl certificate approve marcela is missing: no controller approves a client request on its own. Approved without a certificate is almost always a matter of seconds while the kube-controller-manager signs; repeat the get csr. If it stays empty, look at kubectl describe csr marcela and the kube-controller-manager logs.

- **Symptom (step 3):** auth can-i --as=marcela answers no to everything, or get pods with the marcela context is still Forbidden after creating the RoleBinding
  **What to do:** The RoleBinding subject has to match the certificate CN, letter by letter: --user=marcela. RBAC does not warn you when the name matches nothing, it simply answers no. Check with kubectl -n la-casa get rolebinding llave-de-marcela -o yaml that subjects says kind User, name marcela and apiGroup rbac.authorization.k8s.io, and that roleRef points at the encargada Role. Remember roleRef is immutable: if you got it wrong, delete the RoleBinding and create it again.

- **Symptom (step 4):** kubectl exec into the etcd Pod answers that sh is not in PATH
  **What to do:** That is correct behavior and it does not get fixed: the etcd image is distroless and ships no shell. Invoke the binary directly after the double hyphen, with no sh -c and no env, and with no globs or redirections, because those are expanded by a shell that does not exist there. If you genuinely need a shell inside the node, use docker exec into the node container, which does have one, but etcdctl and etcdutl are not there.

- **Symptom (step 4):** snapshot save fails with a connection or certificate error
  **What to do:** Compare your three paths with the ones the manifest grep prints, and check the endpoint. Note the client flags are not named like the server ones: the manifest reads --cert-file, --key-file and --trusted-ca-file, but etcdctl takes them as --cert, --key and --cacert. That rename is one of the classic confusions and there is no way to guess it, you have to look.

- **Symptom (step 4):** etcdutl does not exist on your node, or etcdctl snapshot status does work
  **What to do:** Then your node ships an etcd line older than 3.6, where snapshot status still lived in etcdctl. Use etcdctl snapshot status in that case: the rest of the step does not change, and the file you pull out of the node is the same. Always confirm your version first with etcdctl version instead of assuming it, which is exactly why the step's command starts there.

- **Symptom (step 5):** The new context answers Unauthorized instead of Forbidden
  **What to do:** They are two different doors and it pays never to confuse them. Unauthorized (401) is the first door: the API server does not know who you are, meaning the token was pasted wrong, got truncated, or already expired. Forbidden (403) is the second: it already knows who you are and is telling you that is not enough. Regenerate the token with create token --duration=24h and set it again with set-credentials, on one line and with no extra quotes.

- **Symptom (step 5):** The new context cannot find the cluster or fails with a certificate error
  **What to do:** Reuse the clusters entry that already exists instead of creating a new one: that is exactly what --cluster=kind-cka-comico-p01 does in the set-context. If you hand-create a new cluster entry you have to supply the CA again, and that is where the certificate error comes from. Check with kubectl --kubeconfig ~/cka-comico-lab/p01/kubeconfig config view that there is only one entry under clusters.

- **Symptom (step 5):** kubectl config set-credentials touched your everyday kubeconfig
  **What to do:** You forgot the --kubeconfig on that particular command. kubectl config subcommands write to whatever file the KUBECONFIG variable resolves to or, when there is none, to ~/.kube/config, not to the file of the context you happened to be using. Remove the stray entry with kubectl config unset users.la-empleada and repeat the command with --kubeconfig, which is the reason this lab writes it out explicitly on every line.

## Going further

- Delete the kube-scheduler mirror Pod with kubectl -n kube-system delete pod kube-scheduler-<node> and watch what happens a few seconds later. Then move the manifest out of the folder with docker exec <node> mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/ and compare: one of the two operations really does switch the component off and the other does not. Put it back when you are done, and while the scheduler is off, try creating a new Pod to see exactly where it gets stuck.
- Redo Step 2's grant with the combination Chapter 2 recommends: create a reusable ClusterRole with the same two verbs and hand it over with a RoleBinding in la-casa. Fire the five auth can-i questions again and confirm the answers are identical. Then hand that SAME ClusterRole over with a ClusterRoleBinding and watch which of the five answers changes: that single difference is the chapter's entire lesson on scope.
- Put Step 4's backup to the test the way that actually matters: restore it. Copy the file back into the node and run etcdutl snapshot restore with a fresh --data-dir, and read the lines it prints. Then change a single byte of the file with dd and try the restore again: the error will name the sha256 it expected and the one it found. Compare that with what etcdutl snapshot status says about that same damaged file and draw your own conclusion about which of the two commands is a backup verification and which is not.
- Generate a second token for the same account with --duration=10m, put it in a separate context, and decode the token's middle part (the one between the dots) with base64 to read the exp and iat fields. Subtract one from the other and confirm the lifetime is what you asked for. That is exactly the short-lived token Chapter 2 mentions, and seeing the expiry date written inside it is what stops the idea being abstract.

## References

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
