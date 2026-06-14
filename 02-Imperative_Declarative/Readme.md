# Kubernetes Pod Management — Imperative vs Declarative

This guide covers the two ways to create and manage Kubernetes resources: **Imperative** (commands) and **Declarative** (YAML files). Understanding both approaches is essential for the CKA exam.

---

## Table of Contents

- [Imperative vs Declarative](#imperative-vs-declarative)
- [Imperative Method](#imperative-method)
  - [Create a Pod](#1-create-a-pod)
  - [List Pods](#2-list-pods)
  - [Describe a Pod](#3-describe-a-pod)
  - [Get Inside a Pod](#4-get-inside-a-pod)
  - [Delete a Pod](#5-delete-a-pod)
- [Declarative Method](#declarative-method)
  - [Write the YAML](#1-write-the-yaml-file)
  - [Apply the YAML](#2-apply-the-yaml-file)
  - [Generate YAML from Command](#3-generate-yaml-using-dry-run)
- [Quick Reference](#quick-reference)

---

## Imperative vs Declarative

| | Imperative | Declarative |
|---|---|---|
| **How** | Run `kubectl` commands directly | Write a YAML file and apply it |
| **Flexible** | Limited options via flags | Full control over all resource fields |

---

## Imperative Method

Run `kubectl` commands directly to create and manage resources — no YAML file needed.

### 1. Create a Pod

```bash
kubectl run nginx-pod --image=nginx:latest
```

| Flag | Description |
|---|---|
| `nginx-pod` | Name of the pod |
| `--image=nginx:latest` | Container image to use |

---

### 2. List Pods
```bash
kubectl get pods
```

To watch pods in real time:
```bash
kubectl get pods -w
```

To see more details like node assignment and IP:
```bash
kubectl get pods -o wide
```
---

### 3. Describe a Pod

Get detailed information about a pod — events, conditions, container state, image, volumes:

```bash
kubectl describe pod/nginx-pod
```

> **Tip:** `kubectl describe` is your best friend for **troubleshooting** — always check the **Events** section at the bottom for errors.

---

### 4. Get Inside a Pod

Open an interactive shell session inside a running pod:

```bash
kubectl exec -it nginx-pod -- bash
```

> **Note:** Some minimal images (like `alpine`) don't have `bash`. Use `sh` instead:
> ```bash
> kubectl exec -it nginx-pod -- sh
> ```

---

### 5. Delete a Pod

```bash
kubectl delete pod nginx-pod
```

---

## Declarative Method

Define the desired state of a resource in a **YAML file** and let Kubernetes apply it. This is the recommended approach for production and version-controlled environments.

### 1. Write the YAML File

Create a file named `nginx-pod.yaml`:

```bash
vim nginx-pod.yaml
```

**YAML Fields Explained:**

| Field | Description |
|---|---|
| `apiVersion` | Kubernetes API version for this resource |
| `kind` | Type of resource (Pod, Deployment, Service, etc.) |
| `metadata.name` | Name of the pod |
| `metadata.labels` | Key-value tags for organizing and selecting resources |
| `spec.containers` | List of containers to run in the pod |
| `image` | Container image to use |
| `containerPort` | Port the container listens on |

---

### 2. Apply the YAML File

```bash
kubectl apply -f nginx-pod.yaml
```

---

### 3. Generate YAML Using Dry Run

Instead of writing YAML from scratch, generate it from an imperative command using `--dry-run=client`:

```bash
kubectl run nginx-pod --image=nginx:latest --dry-run=client -o yaml > nginx-pod.yaml
```

| Flag | Description |
|---|---|
| `--dry-run=client` | Simulates the command without actually creating the resource |
| `-o yaml` | Outputs the result in YAML format |
| `> nginx-pod.yaml` | Saves the output to a file |

> **CKA Exam Tip:** This is the fastest way to generate a valid YAML template during the exam. Generate the base YAML, edit what you need, then apply it.

---

## Quick Reference

| Action | Command |
|---|---|
| Create pod (imperative) | `kubectl run nginx-pod --image=nginx:latest` |
| List pods | `kubectl get pods` |
| List pods with details | `kubectl get pods -o wide` |
| Describe a pod | `kubectl describe pod/nginx-pod` |
| Get shell inside pod | `kubectl exec -it nginx-pod -- bash` |
| Delete a pod | `kubectl delete pod nginx-pod` |
| Force delete a pod | `kubectl delete pod nginx-pod --grace-period=0 --force` |
| Create pod (declarative) | `kubectl apply -f nginx-pod.yaml` |
| Generate YAML template | `kubectl run nginx-pod --image=nginx:latest --dry-run=client -o yaml > nginx-pod.yaml` |