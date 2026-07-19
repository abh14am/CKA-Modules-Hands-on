# Kubernetes — Resource Management & Autoscaling

This guide covers how Kubernetes manages container resources using **requests and limits**, how to monitor resource usage with the **Metrics Server**, and how to automatically scale workloads using **Horizontal Pod Autoscaler (HPA)**.

---

## Table of Contents

- [1. Resource Requests and Limits](#1-resource-requests-and-limits)
  - [What are Requests and Limits?](#what-are-requests-and-limits)
  - [CPU Units](#cpu-units)
  - [Memory Units](#memory-units)
   - [What Happens When Limits are Exceeded?](#what-happens-when-limits-are-exceeded)
- [2. Metrics Server](#2-metrics-server)
  - [What is Metrics Server?](#what-is-metrics-server)
  - [Install Metrics Server](#install-metrics-server)
  - [Metrics Commands](#metrics-commands)
- [3. Autoscaling](#3-autoscaling)
  - [What is Autoscaling?](#what-is-autoscaling)
  - [HPA vs VPA](#hpa-vs-vpa)
- [4. Hands-on — HPA Demo](#4-hands-on--hpa-demo)
  - [Step 1 — Install Metrics Server](#step-1--install-metrics-server)
  - [Step 2 — Deploy the Application](#step-2--deploy-the-application)
  - [Step 3 — Apply HPA](#step-3--apply-hpa)
  - [Step 4 — Simulate Load](#step-4--simulate-load)
  - [Step 5 — Monitor Autoscaling](#step-5--monitor-autoscaling)
- [References](#references)

---

## 1. Resource Requests and Limits

### What are Requests and Limits?

When a container runs in Kubernetes, it competes with other containers on the same node for CPU and memory. Without constraints, one greedy container can starve others. **Requests** and **Limits** let you define exactly how much resource each container needs and is allowed to use.

| | Description | Used For |
|---|---|---|
| **Request** | The minimum amount of resource the container is **guaranteed** | Scheduling — Kubernetes uses this to decide which node to place the pod on |
| **Limit** | The maximum amount of resource the container is **allowed to use** | Enforcement — prevents a container from consuming more than its fair share |

```
Node Resources (e.g. 4 CPU, 8Gi Memory)
│
├── Pod A  request: 250m CPU, 64Mi RAM   ← scheduler reserves this
│          limit:   500m CPU, 128Mi RAM  ← hard cap enforced at runtime
│
├── Pod B  request: 500m CPU, 128Mi RAM
│          limit:   1000m CPU, 256Mi RAM
│
└── Pod C  request: 250m CPU, 64Mi RAM
           limit:   500m CPU, 128Mi RAM
```



### CPU Units

CPU is measured in **millicores (m)**:

| Value | Meaning |
|---|---|
| `1000m` | 1 full CPU core |
| `500m` | Half a CPU core |
| `250m` | Quarter of a CPU core |
| `100m` | 0.1 of a CPU core |


### Memory Units

Memory is measured in binary units:

| Unit | Value |
|---|---|
| `Ki` | Kibibyte (1024 bytes) |
| `Mi` | Mebibyte (1024 Ki) |
| `Gi` | Gibibyte (1024 Mi) |



### What Happens When Limits are Exceeded?

| Resource | Exceeds Limit | Result |
|---|---|---|
| **CPU** | Yes | Container is **throttled** — slowed down, not killed |
| **Memory** | Yes | Container is **OOMKilled** — killed and restarted by Kubernetes |

> **Best Practice:** Always set both requests and limits. Without requests, the scheduler can't make good placement decisions. Without limits, a single container can take down an entire node.

---

## 2. Metrics Server

### What is Metrics Server?

**Metrics Server** is a cluster-wide aggregator of resource usage data. It collects CPU and memory usage from the `kubelet` on each node and exposes it through the Kubernetes API. It is **required** for:

- `kubectl top` commands (to view live CPU/memory usage)
- **Horizontal Pod Autoscaler (HPA)** — HPA reads metrics from Metrics Server to make scaling decisions

The uploaded `metrics-server.yaml` file deploys the full Metrics Server stack into the `kube-system` namespace, including:

> **KIND Cluster Note:** The `--kubelet-insecure-tls` flag is included in the deployment args — this is required for KIND clusters since kubelet TLS certificates are self-signed and not trusted by default.


### Install Metrics Server

```bash
kubectl apply -f metrics-server.yaml
```

Verify it is running:

```bash
kubectl get pods -n kube-system | grep metrics-server
```

### Metrics Commands

```bash
# View CPU and memory usage of all nodes
kubectl top nodes

# View CPU and memory usage of all pods
kubectl top pods

# View pod metrics in a specific namespace
kubectl top pods -n <namespace>
```

---

## 3. Autoscaling

### What is Autoscaling?

**Autoscaling** automatically adjusts the number of running pods or the resources allocated to them based on current demand. Instead of manually scaling up during traffic spikes and scaling down during quiet periods, Kubernetes handles it automatically.

```
Low Traffic          →  1 Pod running
Traffic increases    →  HPA detects high CPU → scales to 5 pods
Traffic decreases    →  HPA detects low CPU  → scales back to 1 pod
```

---

### HPA vs VPA

| | HPA (Horizontal Pod Autoscaler) | VPA (Vertical Pod Autoscaler) |
|---|---|---|
| **What it scales** | Number of pod replicas | CPU/Memory requests of existing pods |
| **Direction** | Horizontal — adds/removes pods | Vertical — resizes pod resources |
| **Metrics used** | CPU, memory, custom metrics | Historical CPU/memory usage |
| **Use case** | Stateless apps with variable traffic | Apps that need right-sized resources |
| **Pod restart** | No — new pods are added | Yes — pods are restarted to apply new requests |
| **Requires Metrics Server** | ✅ Yes | ✅ Yes |

> **CKA Focus:** HPA is covered in the CKA exam. Know how to create one with `kubectl autoscale` and how to read `kubectl get hpa` output.

---

## 4. Hands-on — HPA Demo

This demo deploys a PHP Apache app, creates an HPA, simulates CPU load, and watches the autoscaler in action.

### Step 1 — Install Metrics Server

HPA requires Metrics Server to read CPU usage. Apply the metrics server manifest:

```bash
kubectl apply -f metrics-server.yaml
```

Verify it is running before proceeding:

```bash
kubectl get pods -n kube-system | grep metrics-server
```

### Step 2 — Deploy the Application

Create `deploy-service.yaml` with both the Deployment and Service:
Apply it:

```bash
kubectl apply -f deploy-service.yaml

# Verify deployment is running
kubectl get deployment

# Verify service is created
kubectl get service
```


### Step 3 — Apply HPA

#### Option A — Imperative (fastest for CKA exam)

```bash
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
```

#### Option B — Declarative (YAML)

Create `hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache
  labels:
    env: demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache       # deployment to scale
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50   # scale when CPU exceeds 50% of request
```

```bash
kubectl apply -f hpa.yaml
```

Check HPA status:

```bash
kubectl get hpa
```

### Step 4 — Simulate Load

Open a **separate terminal** and run a load generator pod that continuously hits the php-apache service:

```bash
kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
```

| Part | Description |
|---|---|
| `--rm` | Deletes the pod automatically when you exit |
| `--image=busybox:1.28` | Lightweight image for running shell commands |
| `wget -q -O- http://php-apache` | Sends HTTP requests to the php-apache service in a loop |

> **Note:** The load generator connects to `php-apache` using the service name — this works because both pods are in the same namespace and Kubernetes DNS resolves service names automatically.


### Step 5 — Monitor Autoscaling

In your **original terminal**, watch the HPA react to the load in real time:

```bash
kubectl get hpa php-apache --watch
```

You will see the CPU target climb above 50% and the replica count increase automatically:

Stop the load generator by pressing `Ctrl+C` in the load generator terminal. The HPA will scale back down after a cooldown period (default: ~5 minutes).

---

## References

- [Kubernetes Docs — Resource Requests and Limits](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Kubernetes Docs — Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Kubernetes Docs — Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Kubernetes Docs — HPA Walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
- [Kubernetes Docs — Vertical Pod Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)