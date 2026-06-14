# Kubernetes — ReplicationController, ReplicaSet & Deployments

---

## Table of Contents

- [What is a Replica?](#what-is-a-replica)
- [ReplicationController](#replicationcontroller)
- [ReplicaSet](#replicaset)
- [ReplicationController vs ReplicaSet](#replicationcontroller-vs-replicaset)
- [What is a Deployment?](#what-is-a-deployment)
- [Task 1 — Create a ReplicationController](#task-1--create-a-replicationcontroller)
- [Task 2 — Create a ReplicaSet](#task-2--create-a-replicaset)
- [Task 3 — Create a Deployment](#task-3--create-a-deployment)
- [Quick Reference](#quick-reference)
- [References](#references)

---

## What is a Replica?

A **Replica** is a copy of a Pod running simultaneously in the cluster. Kubernetes uses replicas to:

- **Ensure High Availability** — if one pod crashes, others keep the app running
- **Load Balancing** — distribute traffic across multiple pod instances
- **Fault Tolerance** — automatically replace failed pods to maintain the desired count
- **Scaling** — run more copies to handle increased traffic

> **Example:** If you set `replicas: 3`, Kubernetes always ensures exactly 3 copies of your pod are running at any time. If one dies, a new one is automatically created.

---

## ReplicationController

A **ReplicationController (RC)** is the **legacy** way of managing pod replicas in Kubernetes.

- Ensures a specified number of pod replicas are running at all times
- If a pod fails or is deleted, the RC automatically creates a new one
- If there are too many pods, it removes the extras
- **Limitation:** It can only manage pods that were **created as part of that ReplicationController** — it cannot adopt or manage pre-existing pods
- Uses `selector` with simple **equality-based** matching only (e.g. `app: nginx`)

> **Note:** ReplicationController is considered **legacy**. It has been replaced by ReplicaSet, which is more powerful and flexible. Avoid using RC in new setups.

---

## ReplicaSet

A **ReplicaSet (RS)** is the **modern and recommended** replacement for ReplicationController.

- Does everything a ReplicationController does, but with more flexibility
- **Key advantage:** Can manage **existing pods** that were NOT created as part of the ReplicaSet — it does this using `matchLabels` or `matchExpressions` under the `selector` field
- Supports both **equality-based** and **set-based** label selectors
- ReplicaSets are typically not used directly — they are managed automatically by **Deployments**

### How `matchLabels` Works

The ReplicaSet uses `matchLabels` to find and manage any pod in the cluster that has matching labels — even pods that existed before the ReplicaSet was created. This makes it far more powerful than the ReplicationController.

```
ReplicaSet (selector: app=nginx)
        │
        ├── Finds Pod A  (label: app=nginx) ✅ — manages it
        ├── Finds Pod B  (label: app=nginx) ✅ — manages it
        └── Ignores Pod C (label: app=redis) ❌ — not a match
```

---

## ReplicationController vs ReplicaSet

| Feature | ReplicationController | ReplicaSet |
|---|---|---|
| **Status** | Legacy (deprecated) | Current standard |
| **Selector type** | Equality-based only | Equality + Set-based |
| **Manage existing pods** | ❌ No | ✅ Yes (via `matchLabels`) |
| **Used by Deployments** | ❌ No | ✅ Yes |
| **Recommended** | ❌ Avoid in new setups | ✅ Use this |

---

## Task 1 — Create a ReplicationController

### 1. Create the YAML File

```bash
vim replication-controller.yaml
```

```yaml
apiVersion: v1  #kubectl explain rc
kind: ReplicationController
metadata:
  name: nginx-rc
  labels:
    env: demo
spec:
  template:
    metadata:
      labels:
        env: demo
      name: nginx
    spec:
      containers:
      - image: nginx
        name: nginx-pod
  replicas: 3
```

**Key Fields:**

| Field | Description |
|---|---|
| `replicas` | Number of pod copies to maintain |
| `selector` | Matches pods the RC will manage |
| `template` | Pod blueprint used to create new pods |


### 1a. Apply the File

```bash
kubectl apply -f replication-controller.yaml
```



### 1b. List and Describe the ReplicationController

```bash
# List all ReplicationControllers
kubectl get rc

# Describe the RC in detail (events, pod status, selectors)
kubectl describe rc/nginx-rc

# List all pods created by the RC
kubectl get pods
```


### 1c. Delete the ReplicationController

```bash
kubectl delete rc/nginx-rc
```

> **Note:** Deleting the RC also deletes all pods it manages. To delete the RC but keep the pods, use:
> ```bash
> kubectl delete rc/nginx-rc --cascade=orphan
> ```

---

## Task 2 — Create a ReplicaSet

### 2. Create the YAML File

```bash
vim replicaset.yaml
```

```yaml
apiVersion: apps/v1   #kubectl explain rs
kind: ReplicaSet
metadata:
  name: nginx-rs
  labels:
    env: demo
spec:
  template:
    metadata:
      labels:
        env: demo
      name: nginx
    spec:
      containers:
      - image: nginx
        name: nginx-pod
  replicas: 3
  selector:
    matchLabels:     # every pod running with this particular label is now managed by replicaset
      env: demo
```


### 2a. Apply the ReplicaSet

```bash
kubectl apply -f replicaset.yaml
```


### 2b. View the ReplicaSet

```bash
# List all ReplicaSets
kubectl get rs

# Detailed view with pod count and selector info
kubectl describe rs/nginx-rs

# List pods managed by the ReplicaSet
kubectl get pods
```


### 2c. Edit the ReplicaSet

Open the ReplicaSet in your default editor to make live changes:

```bash
kubectl edit rs/nginx-rs
```

> **Tip:** You can change the `replicas` count or image version directly here. Changes take effect immediately after saving.


### 2d. Scale the ReplicaSet

Scale up or down the number of pod replicas without editing the YAML:

```bash
kubectl scale --replicas=10 rs/nginx-rs
```

Scale back down:

```bash
kubectl scale --replicas=3 rs/nginx-rs
```

> **CKA Tip:** `kubectl scale` is the fastest way to change replica count during the exam. You can also scale using `kubectl edit` or by updating and re-applying the YAML file.

---

## What is a Deployment?

A **Deployment** is the most commonly used and **recommended way** to manage stateless applications in Kubernetes. It sits one level above ReplicaSet and provides powerful features for managing your application lifecycle.

A Deployment:
- **Manages ReplicaSets** — which in turn manage Pods
- **Automates rollouts** — when you update an image or config, it rolls out the change gradually (zero downtime)
- **Supports rollback** — instantly revert to a previous version if something goes wrong
- **Maintains history** — keeps a revision history of all changes made to the deployment

### Deployment Hierarchy

```
Deployment
    │
    └── ReplicaSet (current version)
            │
            ├── Pod 1
            ├── Pod 2
            └── Pod 3
```

When you update a Deployment (e.g. change the image), Kubernetes creates a **new ReplicaSet** and gradually shifts pods from the old one to the new one. The old ReplicaSet is kept for rollback purposes.

```
Before Update:                    After Update:
Deployment                        Deployment
    │                                 │
    └── ReplicaSet v1 (3 pods)        ├── ReplicaSet v1 (0 pods) ← kept for rollback
                                      └── ReplicaSet v2 (3 pods) ← new version
```

### Why Use Deployment over ReplicaSet?

| Feature | ReplicaSet | Deployment |
|---|---|---|
| Manage pods | ✅ | ✅ |
| Auto-healing | ✅ | ✅ |
| Rolling updates | ❌ | ✅ |
| Rollback support | ❌ | ✅ |
| Revision history | ❌ | ✅ |
| Recommended for production | ❌ | ✅ |

---

## Task 3 — Create a Deployment

### 1. Generate the Deployment YAML

Use `--dry-run=client` to generate a YAML template without creating the resource:

```bash
kubectl create deployment nginx-deploy --image=nginx --dry-run=client -o yaml > nginx-deploy.yaml
```

This generates a file `nginx-deploy.yaml` with the following content:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
  labels:
    env: demo
spec:
  template:
    metadata:
      labels:
        env: demo
      name: nginx
    spec:
      containers:
      - image: nginx
        name: nginx-pod
  replicas: 3
  selector:
    matchLabels:
      env: demo
```

> **CKA Tip:** Always use `--dry-run=client -o yaml` to generate base YAML during the exam. Edit the file to add replicas, ports, env vars, or any other fields before applying.


### 1a. Apply the Deployment and List Resources

```bash
# Apply the deployment
kubectl apply -f nginx-deploy.yaml

# List all pods created by the deployment
kubectl get pods

# List all deployments
kubectl get deployments

# Detailed view — shows ReplicaSet, pod status, image, and events
kubectl describe deployments/nginx-deploy
```


### 1c. Update the Image — Imperative Way

Update the container image of a running deployment without editing the YAML:

```bash
kubectl set image deployments/nginx-deploy nginx=nginx:1.9.1
```

| Part | Description |
|---|---|
| `deployments/nginx-deploy` | The deployment to update |
| `nginx` | The container name inside the pod spec |
| `nginx:1.9.1` | The new image to roll out |

Kubernetes will automatically trigger a **rolling update** — replacing old pods with new ones gradually, ensuring zero downtime.

Check the rollout status live:

```bash
kubectl rollout status deployment/nginx-deploy
```

---

### 1d. Rollout Commands

#### View Rollout History

See all previous revisions of the deployment:

```bash
kubectl rollout history deployment/nginx-deploy
```

To inspect a specific revision in detail:

```bash
kubectl rollout history deployment/nginx-deploy --revision=2
```

#### Undo a Rollout (Rollback)

Roll back to the previous version if the update causes issues:

```bash
kubectl rollout undo deployment/nginx-deploy
```

Roll back to a specific revision:

```bash
kubectl rollout undo deployment/nginx-deploy --to-revision=1
```

> **CKA Tip:** If a deployment update causes pods to crash or get stuck, `kubectl rollout undo` is the fastest way to recover. Always check `kubectl rollout history` first to see available revisions.

#### Pause and Resume a Rollout

Pause a rollout to make multiple changes before applying them all at once:

```bash
# Pause the rollout
kubectl rollout pause deployment/nginx-deploy

# Make your changes...

# Resume the rollout
kubectl rollout resume deployment/nginx-deploy
```

---

## Quick Reference

**ReplicationController**

| Action | Command |
|---|---|
| Apply ReplicationController | `kubectl apply -f replication-controller.yaml` |
| List ReplicationControllers | `kubectl get rc` |
| Describe ReplicationController | `kubectl describe rc/nginx-rc` |
| Delete ReplicationController | `kubectl delete rc/nginx-rc` |

**ReplicaSet**

| Action | Command |
|---|---|
| Apply ReplicaSet | `kubectl apply -f replicaset.yaml` |
| List ReplicaSets | `kubectl get rs` |
| Describe ReplicaSet | `kubectl describe rs/nginx-rs` |
| Edit ReplicaSet | `kubectl edit rs/nginx-rs` |
| Scale ReplicaSet | `kubectl scale --replicas=10 rs/nginx-rs` |

**Deployment**

| Action | Command |
|---|---|
| Generate Deployment YAML | `kubectl create deployment nginx-deploy --image=nginx --dry-run=client -o yaml > nginx-deploy.yaml` |
| Apply Deployment | `kubectl apply -f nginx-deploy.yaml` |
| List Deployments | `kubectl get deployments` |
| Describe Deployment | `kubectl describe deployments/nginx-deploy` |
| Update image | `kubectl set image deployments/nginx-deploy nginx=nginx:1.9.1` |
| Check rollout status | `kubectl rollout status deployment/nginx-deploy` |
| View rollout history | `kubectl rollout history deployment/nginx-deploy` |
| Rollback to previous | `kubectl rollout undo deployment/nginx-deploy` |
| Rollback to revision | `kubectl rollout undo deployment/nginx-deploy --to-revision=1` |
| Pause rollout | `kubectl rollout pause deployment/nginx-deploy` |
| Resume rollout | `kubectl rollout resume deployment/nginx-deploy` |
| List all Pods | `kubectl get pods` |

---

## References

- [Kubernetes Docs — ReplicationController](https://kubernetes.io/docs/concepts/workloads/controllers/replicationcontroller/)
- [Kubernetes Docs — ReplicaSet](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
- [Kubernetes Docs — Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes Docs — Performing a Rolling Update](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)