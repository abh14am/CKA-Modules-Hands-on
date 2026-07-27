# Kubernetes — Health Probes

Health probes are **automated health checks performed by the kubelet** on containers to ensure application uptime, stability, and availability. 
Instead of manually monitoring pods, Kubernetes continuously checks if your containers are healthy and takes corrective action when they are not.

---

## Table of Contents

- [Types of Health Probes](#types-of-health-probes)
- [Types of Health Checks](#types-of-health-checks)
- [Probe Configuration Fields](#probe-configuration-fields)
- [Hands-on](#hands-on)
  - [1. Liveness Probe — Command](#1-liveness-probe--command)
  - [2. Liveness + Readiness Probe — HTTP](#2-liveness--readiness-probe--http)
  - [3. Liveness Probe — TCP](#3-liveness-probe--tcp)
- [Applying and Verifying Probes](#applying-and-verifying-probes)
- [References](#references)

---

## Types of Health Probes

Kubernetes has three types of probes, each serving a different purpose:

| Probe | Purpose | Action on Failure |
|---|---|---|
| **Startup Probe** | Checks if the application has started successfully | Container is killed and restarted. Other probes are disabled until startup probe passes |
| **Readiness Probe** | Checks if a container is ready to serve traffic | Pod is removed from the Service's endpoint — traffic stops being routed to it |
| **Liveness Probe** | Detects if a container is still running correctly | Container is killed and restarted by kubelet |

### How They Work Together

```
Pod starts
    │
    ▼
[ Startup Probe ]  ── fails ──► restart container
    │ passes
    ▼
[ Readiness Probe ]  ── fails ──► remove from Service endpoints (no traffic)
    │ passes
    ▼
[ Liveness Probe ]  ── fails ──► restart container
    │ passes
    ▼
  Healthy — serving traffic
```

> **Key Difference — Readiness vs Liveness:**
> - **Readiness** failure → pod stays running but gets no traffic (e.g. app is still warming up or temporarily busy)
> - **Liveness** failure → pod is killed and restarted (e.g. app is deadlocked or completely broken)

---

## Types of Health Checks

Each probe can perform one of three types of checks:

### 1. HTTP Check

Sends an HTTP GET request to a specified path and port on the container. The probe **passes** if the response status code is between `200–399`.

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
```

### 2. TCP Check

Tries to open a TCP connection to the specified port. The probe **passes** if the connection is established successfully.

```yaml
livenessProbe:
  tcpSocket:
    port: 8080
```

### 3. Command (Exec) Check

Executes a command inside the container. The probe **passes** if the command exits with status code `0`.

```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
```

---

## Probe Configuration Fields

These fields apply to all probe types (liveness, readiness, startup):

| Field | Description | Default |
|---|---|---|
| `initialDelaySeconds` | How many seconds to wait after the container starts before running the first probe | `0` |
| `periodSeconds` | How often (in seconds) to run the probe | `10` |
| `failureThreshold` | Number of consecutive failures before the probe is considered failed and action is taken | `3` |
| `successThreshold` | Number of consecutive successes required after a failure to mark the probe as passing again | `1` |
| `timeoutSeconds` | Number of seconds after which the probe times out | `1` |

```
Container starts
    │
    ├── wait initialDelaySeconds (e.g. 5s)
    │
    ├── run probe every periodSeconds (e.g. every 5s)
    │
    ├── if probe fails failureThreshold times (e.g. 3) in a row → take action
    │
    └── if probe passes successThreshold times (e.g. 1) → mark as healthy
```

---

## Hands-on

### 1. Liveness Probe — Command

This pod creates a `/tmp/healthy` file on startup, waits 30 seconds, then deletes it. The liveness probe checks if the file exists — once deleted, the probe fails and Kubernetes restarts the container.

```yaml
# liveness-command.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-exec
spec:
  containers:
  - name: liveness
    image: busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy        # probe passes if this file exists (exit 0)
      initialDelaySeconds: 5  # wait 5s after container starts before first check
      periodSeconds: 5        # check every 5s
```

**What to expect:**
- First 30 seconds → `/tmp/healthy` exists → probe passes ✅
- After 30 seconds → file deleted → probe fails ❌
- After 3 failures (default `failureThreshold`) → container is restarted 🔄

---

### 2. Liveness + Readiness Probe — HTTP

This pod runs a test server that starts returning errors after a set time. Both liveness and readiness probes hit the `/healthz` endpoint.

```yaml
# liveness-http.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-http
spec:
  containers:
  - name: liveness
    image: registry.k8s.io/e2e-test-images/agnhost:2.40
    args:
    - liveness
    livenessProbe:
      httpGet:
        path: /healthz        # HTTP GET to this path
        port: 8080
      initialDelaySeconds: 3  # start checking 3s after container starts
      periodSeconds: 3        # check every 3s
    readinessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 15  # wait longer before first readiness check
      periodSeconds: 10        # check every 10s
```

**Probe behaviour:**
- `livenessProbe` — checks every 3s; if the app stops responding with 2xx, container is restarted
- `readinessProbe` — checks every 10s; if the app is not ready, it is removed from the service endpoint so no traffic is sent

> **Note:** The readiness probe has a longer `initialDelaySeconds` (15s) than liveness (3s) — this gives the app time to warm up before it's considered ready to receive traffic.

---

### 3. Liveness Probe — TCP

This pod runs a proxy server on port 8080. The liveness probe checks TCP connectivity on port 3000. Since nothing is listening on port 3000, the probe will fail — demonstrating how a TCP probe detects unhealthy containers.

```yaml
# liveness-tcp.yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-tcp
  labels:
    test: liveness
spec:
  containers:
  - name: goproxy
    image: registry.k8s.io/goproxy:0.1
    ports:
    - containerPort: 8080
    livenessProbe:
      tcpSocket:
        port: 3000             # try to open a TCP connection on this port
      initialDelaySeconds: 10  # wait 10s before first check
      periodSeconds: 5         # check every 5s
```

**What to expect:**
- Probe tries to open a TCP socket on port 3000
- If the connection succeeds → probe passes ✅
- If the connection is refused → probe fails ❌ → container is restarted

---

## Applying and Verifying Probes

Apply any of the probe YAML files:

```bash
kubectl apply -f liveness-command.yaml
kubectl apply -f liveness-http.yaml
kubectl apply -f liveness-tcp.yaml
```

Watch the pod status in real time — look for restarts:

```bash
kubectl get pods -w
```

Inspect the pod events to see probe failures and restarts:

```bash
kubectl describe pod liveness-exec
kubectl describe pod liveness-http
kubectl describe pod liveness-tcp
```

> **What to look for in `kubectl describe`:**
> - `Liveness probe failed` in the Events section
> - `Restart Count` incrementing in the container status
> - `Back-off restarting failed container` if it restarts too many times

---

## References

- [Kubernetes Docs — Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Kubernetes Docs — Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)