# Multi-Container Pods

## Table of Contents

- [Concepts](#concepts)
- [Files](#files)
- [Task Walkthrough](#task-walkthrough)
  - [Part 1 — Single Init Container](#part-1--single-init-container)
  - [Part 2 — Two Init Containers](#part-2--two-init-containers)
- [Key Behaviours to Remember](#key-behaviours-to-remember)
- [References](#references)
---

## Concepts

**Init Container** — runs before the app container starts. Used to do setup tasks (e.g., wait for a service, pre-populate a volume). The app container only starts after all init containers complete successfully.

**Sidecar Container** — runs alongside the main app container. Acts as a helper (e.g., log shipper, proxy, metrics exporter).

---

## Files

| File | Purpose |
|---|---|
| `myapp-pod.yaml` | Pod with 1 init container (waits for `myservice`) |
| `myapp-pod2.yaml` | Pod with 2 init containers (waits for `myservice` + `mydb`) |
| `2nginx-deploy.yaml` | nginx Deployment (backs `myservice`) |
| `3service-expose.yaml` | Service manifest exposing nginx as `myservice` |

---

## Task Walkthrough

### Part 1 — Single Init Container

**Goal:** Deploy a pod that waits for `myservice` to exist before starting.

**1. Apply the pod**
```bash
kubectl apply -f myapp-pod.yaml
```

**2. Check pod status**
```bash
kubectl get pods
```
Status will show `Init:0/1` — stuck because `myservice` doesn't exist yet.

**3. Check init container logs**
```bash
kubectl logs pods/myapp -c init-myservice
```
You'll see: `waiting for the service to be up` repeating every 2s.

**4. Create the nginx deployment**
```bash
kubectl create deployment nginx-deploy --image=nginx --port 80
```

**5. Expose it as `myservice`**
```bash
kubectl expose deployment nginx-deploy --name myservice --port 80
```

**6. Watch the pod progress**
```bash
kubectl get pods
```
Init container exits, app container starts. Pod moves to `Running`.

---

### Part 2 — Two Init Containers

> **Note:** Init containers cannot be added or removed from an existing pod. Delete and recreate.

**1. Delete the existing pod**
```bash
kubectl delete pod myapp
```

**2. Apply the updated pod with 2 init containers**
```bash
kubectl apply -f myapp-pod2.yaml
```

**3. Check status**
```bash
kubectl get pods
```
Status: `Init:1/2` — first init container passed (`myservice` exists), second is waiting for `mydb`.

**4. Create the mydb deployment**
```bash
kubectl create deployment mydb --image=redis --port 80
```

**5. Expose it as `mydb`**
```bash
kubectl expose deployment mydb --name mydb --port 80
```

**6. Verify services**
```bash
kubectl get service
```

**7. Watch pod come up**
```bash
kubectl get pods -w
```
Both init containers complete → pod moves to `Running`.

---


## Key Behaviours to Remember

- Init containers run **sequentially**, not in parallel.
- The app container only starts after **all** init containers exit with code 0.
- If an init container fails, Kubernetes restarts it until it succeeds (subject to `restartPolicy`).
- **You cannot add or remove init containers from a running pod** — delete and recreate.
- `nslookup <service>.default.svc.cluster.local` is how init containers poll for a service's DNS entry.

---

## References

- [Init Containers — Kubernetes Docs](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Sidecar Containers — Kubernetes Docs](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)
