# Static Pods, Manual Scheduling, Labels and Selectors

## Table of Contents

- [Concepts](#concepts)
  - [Scheduler](#scheduler)
  - [Static Pods](#static-pods)
  - [Manual Scheduling](#manual-scheduling)
  - [Labels and Selectors](#labels-and-selectors)
- [Files](#files)
- [Task Walkthrough](#task-walkthrough)
  - [Task 1 — Static Pod Demo](#task-1--static-pod-demo)
  - [Task 2 — Manual Scheduling](#task-2--manual-scheduling)
  - [Task 3 — Labels and Selectors](#task-3--labels-and-selectors)
- [References](#references)

---

## Concepts

### Scheduler

The Kubernetes scheduler is a control plane component that watches for newly created pods and assigns them to an appropriate node. 
It runs continuously and makes scheduling decisions based on resource availability, taints, tolerations, affinity rules, etc.

### Static Pods

Control plane components (`kube-apiserver`, `etcd`, `controller-manager`, `scheduler`) are not managed by the scheduler — they are **static pods**.

- Managed directly by the **kubelet** on the control plane node
- Their manifests are stored in a watched directory: `/etc/kubernetes/manifests/`
- If a manifest is removed from that directory, the pod is terminated
- If the manifest is restored, the pod comes back up automatically

### Manual Scheduling

Normally the scheduler decides which node a pod lands on. 
Manual scheduling bypasses the scheduler by specifying a `nodeName` directly in the pod spec. The kubelet on that node picks it up and runs it.

### Labels and Selectors

**Labels** are key-value tags attached to Kubernetes resources. They provide logical grouping and separation — independent of namespaces.

- Multiple labels can be added to a single resource
- Labels on pods must match `selector.matchLabels` in a Deployment for the Deployment to manage those pods
- Selectors are used to filter resources by label at query time

---

## Files

| File | Purpose |
|---|---|
| `manual-schedule-pod.yaml` | Pod pinned to a specific node via `nodeName` |
| `label_pods.yaml` | Pod with multiple labels |
| `label-deployment.yaml` | Deployment using label selectors to manage pods |

---

## Task Walkthrough

### Task 1 — Static Pod Demo

**Goal:** Observe what happens when the scheduler static pod manifest is removed.

**1. Move the scheduler manifest out**
```bash
mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/
```

**2. Verify scheduler pod is gone**
```bash
kubectl get pods -n kube-system | grep scheduler
```
No scheduler pod listed.

**3. Try creating a regular pod**
```bash
kubectl run test-pod --image=nginx
kubectl get pods
```
Pod stays in `Pending` — no scheduler to assign it to a node.

**4. Restore the scheduler**
```bash
mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/
```

**5. Verify scheduler is back**
```bash
kubectl get pods -n kube-system | grep scheduler
```

**6. Watch the pending pod get scheduled**
```bash
kubectl get pods -w
```
Pod moves from `Pending` → `Running`.

---

### Task 2 — Manual Scheduling

**Goal:** Schedule a pod on a specific node without the scheduler.

**1. Apply the manifest**
```bash
kubectl apply -f manual-schedule-pod.yaml
```

**2. Verify it landed on the right node**
```bash
kubectl get pods -o wide
```
Check the `NODE` column — should show `cka-cluster-01-worker2`.

```bash
kubectl describe pod nginx
```

---

### Task 3 — Labels and Selectors

**1. Apply the labelled pod**
```bash
kubectl apply -f label_pods.yaml
```

**2. Apply the deployment**
```bash
kubectl apply -f label-deployment.yaml
```

**3. View pods with their labels**
```bash
kubectl get pods --show-labels
```

**4. Filter pods by label**
```bash
kubectl get pods --selector tier=backend
```

---

## References

- [Static Pods — Kubernetes Docs](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/)
- [Assigning Pods to Nodes — Kubernetes Docs](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Labels and Selectors — Kubernetes Docs](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)