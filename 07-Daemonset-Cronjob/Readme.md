# DaemonSet and CronJob

## Table of Contents

- [Concepts](#concepts)
  - [DaemonSet](#daemonset)
  - [Job and CronJob](#job-and-cronjob)
- [Files](#files)
- [Task Walkthrough](#task-walkthrough)
  - [Task 1 — DaemonSet](#task-1--daemonset)
  - [Task 2 — CronJob](#task-2--cronjob)
- [Key Behaviours to Remember](#key-behaviours-to-remember)
- [References](#references)

---

## Concepts

### DaemonSet

A DaemonSet ensures a copy of a pod runs on **every node** in the cluster. When a new node is added, a pod is automatically scheduled on it. When a node is removed, the pod is garbage collected.

Typical use cases:
- Cluster storage daemon on every node (e.g., Ceph)
- Log collection daemon on every node (e.g., Fluentd)
- Node monitoring daemon on every node (e.g., Prometheus Node Exporter)
- Kubernetes internals like `kube-proxy` and `Calico` also run as DaemonSets

### Job and CronJob

**Job** — runs a pod to completion. Used for one-off tasks (e.g., database migration, batch processing). The pod exits after the task finishes.

**CronJob** — a Job scheduled on a recurring basis using cron syntax. Used for regular automated tasks such as backups, report generation, cleanup scripts, etc. Think of it as a task scheduler inside Kubernetes.

---

## Files

| File | Purpose |
|---|---|
| `daemonset.yaml` | DaemonSet running nginx on every worker node |
| `example-cron.yaml` | CronJob that prints a hello message every 2 minutes |

---

## Task Walkthrough

### Task 1 — DaemonSet

**1. Create the DaemonSet manifest**
```bash
vim daemonset.yaml
```

**2. Apply it**
```bash
kubectl apply -f daemonset.yaml
```

**3. Check pods**
```bash
kubectl get pods -o wide
```

> **Note:** If you have 1 control plane + 2 worker nodes, you'll see **2 pods**, not 3. The control plane node has a taint that prevents custom workloads from being scheduled on it — only Kubernetes system components run there. See [Taints and Tolerations](https://github.com/abh14am/CKA-Modules-Hands-on/tree/main/07-Taint-Tolerations) for details.

**4. View the DaemonSet**
```bash
kubectl get ds
kubectl describe ds/nginx-daemonset
```

---

### Task 2 — CronJob

**1. Create the CronJob manifest**
```bash
vim example-cron.yaml
```

**2. Apply it**
```bash
kubectl apply -f example-cron.yaml
```

**3. List CronJobs**
```bash
kubectl get cronjob
```

**4. Watch jobs being created**
```bash
kubectl get jobs -w
```

**5. Check the output logs**
```bash
kubectl logs <pod-name>
```

The job runs every 2 minutes (`*/2 * * * *`), spins up a busybox pod, prints the date and a hello message, then exits.

---

## Key Behaviours to Remember

- A DaemonSet pod is created on **every node automatically** — no manual scheduling needed.
- Control plane nodes are **tainted by default** — custom DaemonSets won't schedule there unless you add a matching toleration.
- Adding a new node to the cluster automatically triggers a new DaemonSet pod on it.
- CronJob schedule follows standard **cron syntax**: `minute hour day month weekday`.
- `*/2 * * * *` means every 2 minutes.
- Each CronJob run creates a new **Job**, which creates a new **Pod**. Old jobs are cleaned up based on `successfulJobsHistoryLimit` (default: 3).
- `restartPolicy: OnFailure` — pod restarts if the container exits with an error.

---

## References

- [DaemonSet — Kubernetes Docs](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- [CronJob — Kubernetes Docs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
- [Taints and Tolerations - Git repo](https://github.com/abh14am/CKA-Modules-Hands-on/tree/main/09-Taint-Tolerations)