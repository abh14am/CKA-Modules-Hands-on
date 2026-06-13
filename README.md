# CKA-Modules-Hands-on

This repository contains the notes and code snippets of the K8s studies. The content is based on the **CKA 2025 curriculum** and includes hands-on demos, assignments, and exam-based scenarios.

---

## Table of Contents

- [What is Kubernetes?](#what-is-kubernetes)
- [Kubernetes Architecture](#kubernetes-architecture)
- [Control Plane Components](#control-plane-components)
- [Worker Node Components](#worker-node-components)
- [Repository Structure](#repository-structure)
- [References](#references)

---

## What is Kubernetes?

**Kubernetes** (also known as **K8s**) is an open-source container orchestration platform originally developed by Google and now maintained by the **Cloud Native Computing Foundation (CNCF)**.

It automates the deployment, scaling, and management of containerized applications across a cluster of machines. Instead of manually managing containers on individual servers, Kubernetes handles it all — ensuring your apps are always running, self-healing when something fails, and scaling up or down based on demand.

### Why Kubernetes?

| Problem | How Kubernetes Solves It |
|---|---|
| Containers crash | Auto-restarts failed containers |
| Traffic spikes | Auto-scales pods up/down |
| Manual deployments | Automates rollouts and rollbacks |
| Service discovery | Built-in DNS and load balancing |
| Config management | ConfigMaps and Secrets |
| Storage management | Persistent Volumes |

---

## Kubernetes Architecture

Kubernetes follows a **Master-Worker** architecture. A Kubernetes cluster consists of two main parts:

- **Control Plane** — the brain of the cluster; makes decisions and manages the overall state
- **Worker Nodes** — the muscle; runs the actual application workloads (containers)

```
                        ┌─────────────────────────────────┐
                        │          CONTROL PLANE           │
                        │                                  │
                        │  ┌──────────┐  ┌─────────────┐  │
                        │  │  API     │  │  Scheduler  │  │
                        │  │  Server  │  └─────────────┘  │
                        │  └──────────┘                   │
                        │  ┌──────────┐  ┌─────────────┐  │
                        │  │   etcd   │  │  Controller │  │
                        │  │          │  │  Manager    │  │
                        │  └──────────┘  └─────────────┘  │
                        └────────────┬────────────────────┘
                                     │
               ┌─────────────────────┼─────────────────────┐
               │                     │                      │
   ┌───────────▼──────┐  ┌───────────▼──────┐  ┌───────────▼──────┐
   │   WORKER NODE 1  │  │   WORKER NODE 2  │  │   WORKER NODE 3  │
   │                  │  │                  │  │                  │
   │  kubelet         │  │  kubelet         │  │  kubelet         │
   │  kube-proxy      │  │  kube-proxy      │  │  kube-proxy      │
   │  container       │  │  container       │  │  container       │
   │  runtime         │  │  runtime         │  │  runtime         │
   │  ┌────┐ ┌────┐   │  │  ┌────┐ ┌────┐  │  │  ┌────┐ ┌────┐  │
   │  │Pod │ │Pod │   │  │  │Pod │ │Pod │  │  │  │Pod │ │Pod │  │
   │  └────┘ └────┘   │  │  └────┘ └────┘  │  │  └────┘ └────┘  │
   └──────────────────┘  └──────────────────┘  └──────────────────┘
```

### Key Terms

| Term | Description |
|---|---|
| **Cluster** | A set of machines (nodes) running Kubernetes |
| **Node** | A single machine (physical or virtual) in the cluster |
| **Pod** | The smallest deployable unit; wraps one or more containers |
| **Deployment** | Manages a set of identical pods and handles rolling updates |
| **Service** | Exposes pods to network traffic with a stable IP/DNS |
| **Namespace** | Virtual cluster within a cluster for resource isolation |
| **ConfigMap** | Stores non-sensitive configuration data as key-value pairs |
| **Secret** | Stores sensitive data like passwords and API keys |
| **Volume** | Provides persistent or shared storage for pods |
| **Ingress** | Manages external HTTP/HTTPS access to services |

---

## Control Plane Components

The Control Plane is responsible for managing the cluster state, scheduling workloads, and responding to cluster events.

### 1. `kube-apiserver`
The **front door** of the Kubernetes control plane. All communication — from `kubectl`, worker nodes, and internal components — goes through the API Server. It exposes the Kubernetes REST API, authenticates requests, and updates the state in etcd.

### 2. `etcd`
A distributed, reliable **key-value store** that holds the entire cluster state and configuration. Always back this up in production!

### 3. `kube-scheduler`
The **scheduler** watches for newly created pods that have no assigned node and selects the best node for them to run on. It considers factors like resource availability (CPU, memory), node affinity rules, taints and tolerations, and more.

### 4. `kube-controller-manager`
Runs a collection of **controllers** that regulate the state of the cluster. Each controller watches the current state and works to bring it to the desired state. Examples include:

- **Node Controller** — monitors node health
- **Replication Controller** — ensures the correct number of pod replicas
- **Endpoints Controller** — populates the Endpoints object (joins Services and Pods)
- **Service Account Controller** — manages default accounts for namespaces

### 5. `cloud-controller-manager` *(optional)*
Integrates Kubernetes with cloud provider APIs (AWS, GCP, Azure). Manages cloud-specific resources like load balancers, storage volumes, and node lifecycle. Not used in bare-metal or local clusters like KIND.

---

## Worker Node Components

Worker Nodes are the machines that run your application containers. Each node contains the following components:

### 1. `kubelet`
The **primary agent** running on every worker node. It communicates with the API Server and ensures that the containers described in PodSpecs are running and healthy. If a container crashes, kubelet restarts it.

### 2. `kube-proxy`
A **network proxy** that runs on each node and maintains network rules. It enables communication to your pods from inside or outside the cluster by managing iptables or IPVS rules. Handles Service-based load balancing across pods.

### 3. Container Runtime
The software responsible for **actually running containers**. Kubernetes supports any runtime that implements the Container Runtime Interface (CRI). Common options:

- **containerd** *(most common)*
- **Docker Engine* (via cri-dockerd)

### 4. Pods
The **smallest and simplest unit** in Kubernetes. A Pod represents a single instance of a running process and can contain one or more tightly coupled containers that share the same network namespace and storage.



---

## References

- [Kubernetes Official Documentation](https://kubernetes.io/docs/home/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
