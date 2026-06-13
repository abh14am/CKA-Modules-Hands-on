# CKA (Certified Kubernetes Administrator) Study Guide

## What is KIND?

**KIND (Kubernetes IN Docker)** is a tool for running local Kubernetes clusters using Docker containers as nodes. Instead of setting up real virtual machines, KIND spins up lightweight Docker containers that act as Kubernetes nodes — making it fast and easy to get a cluster running on your local machine.
---

## Cluster Setup with KIND (Kubernetes IN Docker)

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running
- [KIND](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed

---

## 1. Create a KIND Cluster
Create a cluster with **1 control plane** and **2 worker nodes** using a config file:

```bash
kind create cluster --name=cka-cluster-new --config=kind-config.yaml
```

> **Note:** Use the `kind_create_cluster.sh` script to create the cluster with the correct configuration.

---

## 2. Verify the Cluster

Check that the cluster was created successfully:

```bash
# List all KIND clusters
kind get clusters

# Check node status
kubectl get nodes
```

---

## 3. Delete the Cluster

When you're done, clean up the cluster:

```bash
kind delete cluster -n=cka-cluster-new
```

---

## 4. Managing Cluster Contexts

When working with multiple clusters, `kubectl` uses **contexts** to know which cluster to talk to.

### View All Contexts

List all available clusters and see which one is currently active:
```bash
kubectl config get-contexts
```


### Switch to Another Cluster

```bash
kubectl config use-context [new-cluster-name]
```
