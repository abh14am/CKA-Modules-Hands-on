# Kubernetes — ClusterRole & ClusterRoleBinding

This guide covers the difference between namespace-scoped **Roles** and cluster-wide **ClusterRoles**, and how to use **ClusterRoleBindings** to grant users access to cluster-level resources like nodes.

---

## Table of Contents

- [What is a Role and RoleBinding?](#what-is-a-role-and-rolebinding)
- [What is a ClusterRole and ClusterRoleBinding?](#what-is-a-clusterrole-and-clusterrolebinding)
- [Role vs ClusterRole](#role-vs-clusterrole)
- [Namespaced vs Non-Namespaced Resources](#namespaced-vs-non-namespaced-resources)
- [Directory Structure](#directory-structure)
- [Hands-on — Grant Node Access to User krish](#hands-on--grant-node-access-to-user-krish)
  - [Step 1 — Verify No Permission (Before)](#step-1--verify-no-permission-before)
  - [Step 2 — Create the ClusterRole](#step-2--create-the-clusterrole)
  - [Step 3 — Apply the ClusterRole](#step-3--apply-the-clusterrole)
  - [Step 4 — List and Describe the ClusterRole](#step-4--list-and-describe-the-clusterrole)
  - [Step 5 — Create the ClusterRoleBinding](#step-5--create-the-clusterrolebinding)
  - [Step 6 — List and Describe the ClusterRoleBinding](#step-6--list-and-describe-the-clusterrolebinding)
  - [Step 7 — Verify Permission (After)](#step-7--verify-permission-after)
- [YAML Files](#yaml-files)
- [Full Flow Summary](#full-flow-summary)
- [Quick Reference](#quick-reference)
- [References](#references)

---

## What is a Role and RoleBinding?

A **Role** defines a set of permissions (verbs on resources) within a **single namespace**. It answers the question: *what actions are allowed on which resources inside this namespace?*

A **RoleBinding** attaches a Role to a user, group, or service account — granting them those permissions **within that namespace only**.

```
Role (pod-reader)  ←  namespace: default
  └── rules: get, list, watch → pods

RoleBinding (read-pod)  ←  namespace: default
  ├── subject: krish (User)
  └── roleRef: pod-reader

Result: krish can read pods in the default namespace only.
        krish cannot read pods in any other namespace.
        krish cannot read nodes (cluster-scoped resource).
```

---

## What is a ClusterRole and ClusterRoleBinding?

A **ClusterRole** is like a Role but **not bound to any namespace** — it applies across the entire cluster. It is required for:

- Cluster-scoped resources that don't belong to any namespace (e.g. `nodes`, `persistentvolumes`, `namespaces`)
- Granting the same permissions across **all namespaces** at once

A **ClusterRoleBinding** attaches a ClusterRole to a user, group, or service account at the **cluster level** — giving them access everywhere the ClusterRole covers.

```
ClusterRole (node-reader)  ←  no namespace (cluster-wide)
  └── rules: get, list, watch → nodes

ClusterRoleBinding (reader-binding)  ←  no namespace
  ├── subject: krish (User)
  └── roleRef: node-reader

Result: krish can read nodes anywhere in the cluster.
```

---

## Role vs ClusterRole

| | Role | ClusterRole |
|---|---|---|
| **Scope** | Single namespace | Entire cluster |
| **Use case** | Namespace-level access (pods, services, deployments) | Cluster-wide resources (nodes, PVs, namespaces) |
| **Bound by** | RoleBinding | ClusterRoleBinding (or RoleBinding for namespace-scoped use) |
| **Can access nodes?** | ❌ No — nodes are not namespaced | ✅ Yes |
| **Can access all namespaces?** | ❌ No | ✅ Yes (when bound with ClusterRoleBinding) |

### Binding Combinations

| Role Type | Binding Type | Result |
|---|---|---|
| Role | RoleBinding | Access within one namespace |
| ClusterRole | RoleBinding | ClusterRole permissions scoped to one namespace |
| ClusterRole | ClusterRoleBinding | Access across the entire cluster |

> **Tip:** You can bind a ClusterRole with a RoleBinding to limit a ClusterRole's permissions to a single namespace — useful for reusing common role definitions without granting cluster-wide access.

---

## Namespaced vs Non-Namespaced Resources

Nodes are **cluster-scoped** (not namespaced) — this is exactly why a ClusterRole is needed instead of a Role to grant node access.

```bash
# List all namespaced resources — Role can manage these
kubectl api-resources --namespaced=true

# List all non-namespaced resources — ClusterRole is required for these
kubectl api-resources --namespaced=false
```

**Common non-namespaced resources** (require ClusterRole):

| Resource | Kind |
|---|---|
| `nodes` | Node |
| `namespaces` | Namespace |
| `persistentvolumes` | PersistentVolume |
| `clusterroles` | ClusterRole |
| `clusterrolebindings` | ClusterRoleBinding |
| `storageclasses` | StorageClass |

---

## Directory Structure

```
.
├── cluster-role.yaml           # ClusterRole — node-reader (get/list/watch nodes)
├── cluster-role-binding.yaml   # ClusterRoleBinding — binds node-reader to krish
└── Readme.md                   # This file
```

---

## Hands-on — Grant Node Access to User krish

This walkthrough grants user `krish` permission to read nodes cluster-wide using a ClusterRole and ClusterRoleBinding.

> **Prerequisite:** User `krish` already exists with a valid certificate and kubeconfig entry from the RBAC setup. See the [Authentication & RBAC guide](../day22-authn-authz/Readme.md).

---

### Step 1 — Verify No Permission (Before)

Confirm that `krish` cannot list nodes before any ClusterRole is assigned:

```bash
kubectl auth can-i get nodes --as krish
```

Expected output:

```
no
```

Nodes are cluster-scoped resources — the `pod-reader` Role from the previous exercise only covers pods in the default namespace. A ClusterRole is needed for nodes.

---

### Step 2 — Create the ClusterRole

Use `--dry-run=client` to generate the ClusterRole YAML without applying it first:

```bash
kubectl create clusterrole node-reader \
  --verb=get,list,watch \
  --resource=node \
  --dry-run=client -o yaml > cluster-role.yaml
```

| Flag | Description |
|---|---|
| `node-reader` | Name of the ClusterRole |
| `--verb=get,list,watch` | Allowed actions |
| `--resource=node` | Resource this ClusterRole applies to |
| `--dry-run=client -o yaml` | Generate the YAML without creating the resource |

---

### Step 3 — Apply the ClusterRole

```bash
kubectl apply -f cluster-role.yaml
```

---

### Step 4 — List and Describe the ClusterRole

```bash
# List all ClusterRoles (includes built-in system roles)
kubectl get clusterrole

# Describe the node-reader ClusterRole
kubectl describe clusterrole/node-reader
```

The describe output shows the rules — verbs allowed on which resources:

```
Name:         node-reader
Labels:       <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  nodes      []                 []              [get list watch]
```

---

### Step 5 — Create the ClusterRoleBinding

Generate and apply a ClusterRoleBinding that attaches `node-reader` to user `krish`:

```bash
kubectl create clusterrolebinding reader-binding \
  --clusterrole=node-reader \
  --user=krish \
  --dry-run=client -o yaml > cluster-role-binding.yaml

kubectl apply -f cluster-role-binding.yaml
```

| Flag | Description |
|---|---|
| `reader-binding` | Name of the ClusterRoleBinding |
| `--clusterrole=node-reader` | The ClusterRole to bind |
| `--user=krish` | The user to grant the ClusterRole to |

---

### Step 6 — List and Describe the ClusterRoleBinding

```bash
# List and filter for the binding you created
kubectl get clusterrolebinding | grep reader-binding

# Describe to see the full binding details
kubectl describe clusterrolebindings/reader-binding
```

The describe output shows the subject and the role it is bound to:

```
Name:         reader-binding
Subjects:
  Kind  Name   Namespace
  ----  ----   ---------
  User  krish
Role:
  Kind:  ClusterRole
  Name:  node-reader
```

---

### Step 7 — Verify Permission (After)

Confirm that `krish` can now list nodes:

```bash
kubectl auth can-i get nodes --as krish
```

Expected output:

```
yes
```

---

## YAML Files

### `cluster-role.yaml` — node-reader ClusterRole

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups:
  - ""              # "" indicates the core API group
  resources:
  - nodes           # cluster-scoped resource — requires ClusterRole
  verbs:
  - get
  - list
  - watch
```

### `cluster-role-binding.yaml` — reader-binding ClusterRoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: reader-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: node-reader          # ClusterRole to bind
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: krish                # user receiving the ClusterRole
```

---

## Full Flow Summary

```
kubectl auth can-i get nodes --as krish   →  no  (before — no access)
          │
          ▼
kubectl create clusterrole node-reader    →  defines WHAT is allowed (get/list/watch nodes)
          │
          ▼
kubectl create clusterrolebinding         →  binds node-reader TO krish (cluster-wide)
          │
          ▼
kubectl auth can-i get nodes --as krish   →  yes  (after — access granted ✅)
```

---

## References

- [Kubernetes Docs — RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Kubernetes Docs — Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#clusterrole-example)
- [Kubernetes Docs — API Resources](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_api-resources/)