# Kubernetes Namespaces

Namespaces provide an **additional layer of isolation** within a Kubernetes cluster. 
They allow you to separate objects and resources logically — within the same physical cluster.

---

## Table of Contents

- [What is a Namespace?](#what-is-a-namespace)
- [Default Namespaces in Kubernetes](#default-namespaces-in-kubernetes)
- [Namespace Commands](#namespace-commands)
- [Task — Working with Namespaces](#task--working-with-namespaces)
  - [1. Create Namespace and Deploy](#1-create-namespace-and-deploy)
  - [2. Get Inside a Pod in a Namespace](#2-get-inside-a-pod-in-a-namespace)
  - [3. Scale a Deployment in a Namespace](#3-scale-a-deployment-in-a-namespace)
  - [4. Expose a Deployment in a Namespace](#4-expose-a-deployment-in-a-namespace)
- [Quick Reference](#quick-reference)
- [References](#references)

---

## What is a Namespace?

A **Namespace** is a virtual cluster within a Kubernetes cluster. It lets you divide cluster resources between multiple teams, projects, or environments.

![Namespace Diagram](images/namespace.png)

#### Key Characteristics are :

- **Isolation** 
- **Same name, different namespace** 
- **Permissions** — you can set different RBAC permissions per namespace, controlling who can access what
- **Cross-namespace communication** — pods in different namespaces can still talk to each other using a **Fully Qualified Domain Name (FQDN)**:

```
[service-name].[namespace].svc.cluster.local
```

**Example:**

```
# A pod in namespace 'frontend' reaching a service in namespace 'backend':
http://api-service.backend.svc.cluster.local
```

### When to Use Namespaces

| Use Case | Example |
|---|---|
| Environment separation | `dev`, `staging`, `production` |
| Team separation | `team-frontend`, `team-backend` |
| Project isolation | `project-alpha`, `project-beta` |
| Resource quota management | Limit CPU/memory per namespace |
| Access control | Different RBAC rules per namespace |

---

## Default Namespaces in Kubernetes

When you create a cluster, Kubernetes sets up these namespaces automatically:

| Namespace | Description |
|---|---|
| `default` | Where your resources go if no namespace is specified |
| `kube-system` | Internal Kubernetes components (API server, scheduler, etc.) |
| `kube-public` | Publicly readable data, used for cluster info |
| `kube-node-lease` | Node heartbeat data used to detect node failures |

> **Tip:** Never deploy your application workloads into `kube-system`. Keep that namespace for Kubernetes internals only.

---

## Namespace Commands

### List All Namespaces

```bash
kubectl get namespaces
```

### List All Resources in a Namespace

```bash
kubectl get all -n <namespace-name>
```

### Create a Namespace

```bash
kubectl create namespace <namespace-name>
```

### Delete a Namespace

```bash
kubectl delete namespace/<ns-name>
```

> **Warning:** Deleting a namespace deletes **all resources inside it** — pods, deployments, services, configmaps, etc. Be careful in production!

---

## Task — Working with Namespaces

### 1. Create Namespace and Deploy

Create a namespace called `demo` and spin up a deployment inside it:

```bash
# Create the namespace
kubectl create namespace demo

# Create a deployment inside the demo namespace
kubectl create deployment nginx-demo --image=nginx -n demo

# List deployments inside the demo namespace
kubectl get deployment -n demo

# List all objects inside the demo namespace
kubectl get all -n demo
```


### 2. Get Inside a Pod in a Namespace

Open a shell session inside a pod running in the `demo` namespace:

```bash
kubectl exec -it nginx-demo -n demo -- sh

### 3. Scale the Deployment in a Namespace

Scale the `nginx-demo` deployment to 3 replicas inside the `demo` namespace:

```bash
kubectl scale --replicas=3 deployment/nginx-demo -n demo
```

Verify the scaling:

```bash
kubectl get pods -n demo
```


### 4. Expose the Deployment in a Namespace

Create a service to expose port 80 of the `nginx-demo` deployment inside the `demo` namespace:

```bash
kubectl expose deployment/nginx-demo --port=80 --name=service-demo -n demo
```

View the created service:

```bash
kubectl get svc -n demo
```

---

## Quick Reference

| Action | Command |
|---|---|
| List all namespaces | `kubectl get namespaces` |
| List all resources in a namespace | `kubectl get all -n <namespace>` |
| Create a namespace | `kubectl create namespace <name>` |
| Delete a namespace | `kubectl delete namespace/<name>` |
| Create deployment in namespace | `kubectl create deployment nginx-demo --image=nginx -n demo` |
| List deployments in namespace | `kubectl get deployment -n demo` |
| Exec into pod in namespace | `kubectl exec -it <pod-name> -n demo -- sh` |
| Scale deployment in namespace | `kubectl scale --replicas=3 deployment/nginx-demo -n demo` |
| Expose deployment in namespace | `kubectl expose deployment/nginx-demo --port=80 --name=service-demo -n demo` |
| List services in namespace | `kubectl get svc -n demo` |

---

## References

- [Kubernetes Docs — Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
)