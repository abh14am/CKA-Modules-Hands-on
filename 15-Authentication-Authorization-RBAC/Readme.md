# Kubernetes — Authentication, Authorization & RBAC

This guide covers how Kubernetes verifies **who you are** (Authentication) and controls **what you can do** (Authorization) using Role-Based Access Control (RBAC).

---

## Table of Contents

- [Authentication vs Authorization](#authentication-vs-authorization)
- [Authentication — Who You Are](#authentication--who-you-are)
- [Authorization — What You Can Do](#authorization--what-you-can-do)
  - [Authorization Modes](#authorization-modes)
- [What is RBAC?](#what-is-rbac)
  - [RBAC Components](#rbac-components)
- [Directory Structure](#directory-structure)
- [Full Hands-on Walkthrough](#full-hands-on-walkthrough)
  - [Part 1 — Authentication: Create User Credentials](#part-1--authentication-create-user-credentials)
  - [Part 2 — Authorization: Create Role and Binding](#part-2--authorization-create-role-and-binding)
  - [Part 3 — Register User in Kubeconfig](#part-3--register-user-in-kubeconfig)
  - [Part 4 — Switch Context and Verify](#part-4--switch-context-and-verify)
- [YAML Files](#yaml-files)
- [Kubernetes REST API with curl](#kubernetes-rest-api-with-curl)
- [Full Flow Summary](#full-flow-summary)
- [Quick Reference](#quick-reference)
- [References](#references)

---

## Authentication vs Authorization

| | Authentication | Authorization |
|---|---|---|
| **Question** | Who are you? | What can you do? |
| **Analogy** | Checking your ID at the fortress gate | Granting access levels inside the fortress |
| **Mechanism** | Certificates, tokens, kubeconfig | RBAC, ABAC, Node, Webhook |
| **Fails when** | Invalid certificate or unknown user | User has no permission for the requested action |

```
kubectl get pods
      │
      ▼
┌─────────────────────────────────────────────┐
│              Kubernetes API Server          │
│                                             │
│  ┌──────────────┐     ┌──────────────────┐  │
│  │ AUTHN        │────►│ AUTHZ            │  │
│  │ Who are you? │     │ What can you do? │  │
│  │              │     │                  │  │
│  │ Reads your   │     │ Checks your      │  │
│  │ certificate  │     │ Role/Binding     │  │
│  └──────────────┘     └──────────────────┘  │
│         │                      │            │
│    ✅ krish                ✅ has role      │
│                                             │
└─────────────────────────────────────────────┘
```

---

## Authentication — Who You Are

Imagine your cluster is a **fortress**. Authentication is like checking IDs at the gate. Your **kubeconfig** is the keycard — it contains certificates that identify you to the Kubernetes API server.

Kubernetes does **not** manage users directly. Instead, it trusts any user who presents a **valid certificate signed by the cluster's Certificate Authority (CA)**. This is why you go through the CSR process to create a user.

### How Kubernetes Identifies a User from a Certificate

When you generate a certificate with:

```bash
openssl req -new -key krish.key -out krish.csr -subj "/CN=krish"
```

The `/CN=krish` (Common Name) becomes the **Kubernetes username**. Optionally, `/O=groupname` sets the **group** the user belongs to, which is useful for group-level RBAC bindings.

### Kubeconfig

The `kubeconfig` file (default: `~/.kube/config`) stores:

- **Clusters** — API server URL and CA certificate
- **Users** — client certificate and private key for authentication
- **Contexts** — links a user to a cluster

```yaml
# simplified kubeconfig structure
clusters:
  - name: kind-cka-cluster-01
    cluster:
      server: https://127.0.0.1:45231
      certificate-authority-data: <base64-ca-cert>

users:
  - name: krish
    user:
      client-certificate-data: <base64-krish.crt>
      client-key-data: <base64-krish.key>

contexts:
  - name: krish
    context:
      cluster: kind-cka-cluster-01
      user: krish
```

---

## Authorization — What You Can Do

Once Kubernetes knows who you are, it checks **what you are allowed to do**. Kubernetes supports multiple authorization methods:

| Method | Description | Status |
|---|---|---|
| **Node Authorizer** | Ensures kubelets on nodes are authorized to communicate with the API server | Built-in |
| **ABAC** | Attribute-Based Access Control — associates users with permissions via policy files. Complex to manage | Legacy |
| **RBAC** | Role-Based Access Control — assign roles to users or groups. Clean and auditable | ✅ Recommended |
| **Webhook** | Delegates authorization to an external service (e.g. OPA — Open Policy Agent) | Optional |

### Authorization Modes

The API server processes authorization modes in a **priority sequence**. Each mode is tried in order until one approves or denies the request:

```
Request arrives
      │
      ▼
[ Node Authorizer ]  ── handles node/kubelet requests
      │ not applicable
      ▼
[ RBAC ]  ── checks if user has a Role/ClusterRole with permission
      │ denied or not matched
      ▼
[ Webhook ] (if enabled)  ── asks external system
      │
      ▼
  Allow or Deny
```

> **Note:** Modes like `AlwaysAllow` and `AlwaysDeny` exist but are for **testing only** — never use them in production.

---

## What is RBAC?

**Role-Based Access Control (RBAC)** is the recommended authorization method in Kubernetes. Instead of assigning permissions directly to individual users, you:

1. Create a **Role** — defines what actions are allowed on which resources
2. Create a **RoleBinding** — binds the Role to a user, group, or service account

```
Role (pod-reader)
  └── rules: get, watch, list pods
        │
        ▼
RoleBinding (read-pod)
  ├── subject: krish (User)
  └── roleRef: pod-reader
```

This means `krish` can `get`, `watch`, and `list` pods — nothing else.

### RBAC Components

| Resource | Scope | Description |
|---|---|---|
| **Role** | Namespace | Defines permissions within a specific namespace |
| **ClusterRole** | Cluster-wide | Defines permissions across all namespaces or for cluster-level resources (nodes, PVs) |
| **RoleBinding** | Namespace | Binds a Role (or ClusterRole) to a user/group within a namespace |
| **ClusterRoleBinding** | Cluster-wide | Binds a ClusterRole to a user/group across the entire cluster |

### RBAC Verbs (Actions)

| Verb | HTTP Method | Description |
|---|---|---|
| `get` | GET | Read a single resource |
| `list` | GET | List all resources of a type |
| `watch` | GET | Stream changes to resources |
| `create` | POST | Create a new resource |
| `update` | PUT | Replace an existing resource |
| `patch` | PATCH | Partially update a resource |
| `delete` | DELETE | Delete a resource |

---

## Directory Structure

```
.
├── binding.yaml          # RoleBinding — binds pod-reader role to krish
├── k8s-rest-api.md       # curl commands to hit the Kubernetes API directly
├── krish/
│   ├── csr.yaml          # CertificateSigningRequest submitted to Kubernetes
│   ├── krish.crt         # Signed certificate (issued by cluster CA)
│   ├── krish.csr         # Certificate Signing Request (generated by openssl)
│   └── krish.key         # Private key (never share this)
├── Readme.md             # This file
└── role.yaml             # Role — pod-reader with get/watch/list on pods
```

---

## Full Hands-on Walkthrough

This walkthrough creates a new Kubernetes user `krish`, issues a certificate, creates RBAC permissions, and verifies access.

---

### Part 1 — Authentication: Create User Credentials

#### Step 1 — Generate a Private Key

```bash
openssl genrsa -out krish/krish.key 2048
```

This creates `krish/krish.key` — the private key for user krish.

---

#### Step 2 — Generate a CSR File

```bash
openssl req -new -key krish/krish.key -out krish/krish.csr -subj "/CN=krish"
```

The `/CN=krish` sets the Kubernetes username. This creates `krish/krish.csr`.

---

#### Step 3 — Base64 Encode the CSR

```bash
cat krish/krish.csr | base64 | tr -d "\n"
```

Copy the output — this single-line base64 string goes into `csr.yaml`.

---

#### Step 4 — Create and Apply the CSR YAML

The `krish/csr.yaml` contains the base64-encoded CSR submitted to Kubernetes for signing:

```yaml
# krish/csr.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: krish
spec:
  request: LS0tLS1WnQydWlzT2daUDhqSllMbUcyTmZ1NDVlSE12dzhYWno5bW4vNE5xTUpoCnBFSlJpOGFRdDZyTnFFc...  # base64 encoded single line — krish's CSR
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 864000000
  usages:
  - client auth
```

Apply it:

```bash
kubectl apply -f krish/csr.yaml
```

---

#### Step 5 — List and Approve the CSR

```bash
# List all CSRs — krish should appear in Pending state
kubectl get csr

# Approve the CSR — cluster CA signs and issues the certificate
kubectl certificate approve krish
```

---

#### Step 6 — Verify Access Before RBAC (Should Be Denied)

Test that krish exists as a user but has no permissions yet:

```bash
kubectl auth can-i get node --as krish
```

Expected output: `no` — krish is authenticated but not yet authorized.

---

### Part 2 — Authorization: Create Role and Binding

#### Step 7 — Create the Role

The `role.yaml` defines what `krish` is allowed to do — read pods in the `default` namespace:

```yaml
# role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
  - apiGroups: [""]    # "" indicates the core API group
    resources: ["pods"]
    verbs: ["get", "watch", "list"]
```

Apply it:

```bash
kubectl apply -f role.yaml

# Verify
kubectl get roles
```

---

#### Step 8 — Create the RoleBinding

The `binding.yaml` binds the `pod-reader` role to user `krish`:

```yaml
# binding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pod
  namespace: default
subjects:
- kind: User
  name: krish
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Apply it:

```bash
kubectl apply -f binding.yaml

# Verify
kubectl get rolebindings
```

---

#### Step 9 — Verify Permission is Granted

```bash
# Check if krish can now list pods
kubectl auth can-i get node --as krish

# Check the current logged-in user
kubectl auth whoami
```

Expected output: `yes` — krish now has pod read access in the default namespace.

---

### Part 3 — Register User in Kubeconfig

#### Step 1 — Extract the Signed Certificate

Decode and save the signed certificate issued by the cluster CA:

```bash
kubectl get csr krish -o jsonpath='{.status.certificate}' | base64 -d > krish/krish.crt
```

The resulting `krish/krish.crt` is the signed PEM certificate:

```
-----BEGIN CERTIFICATE-----
MIIC9jCCAd6gAwIBAgIRAI3P5W9rJUcGpTyTezffeNAwDQYJKoZIhvcNAQELBQAw
...
-----END CERTIFICATE-----
```

---

#### Step 2 — Register Credentials and Set Context

Register krish's key and certificate into kubeconfig and link to the cluster:

```bash
# Register krish's credentials
kubectl config set-credentials krish \
  --client-key=krish/krish.key \
  --client-certificate=krish/krish.crt \
  --embed-certs=true

# Create a context linking krish to the cluster
kubectl config set-context krish \
  --cluster=kind-cka-cluster-01 \
  --user=krish

# List all contexts to verify
kubectl config get-contexts
```

---

### Part 4 — Switch Context and Verify

#### Step 3 — Switch to krish's Context

```bash
kubectl config use-context krish

# Confirm the active context
kubectl config get-contexts
```

#### Step 4 — Verify by Running Commands as krish

```bash
# Should work — krish has get/list/watch on pods
kubectl get pods

# Should fail — krish has no permission for deployments
kubectl get deployments
```

#### Step 5 — View the Kubeconfig File

```bash
kubectl config view
```

#### Count All Roles in the Cluster

```bash
kubectl get roles -A --no-header | wc -l
```

---

## YAML Files

### `role.yaml` — pod-reader Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
  - apiGroups: [""]        # "" indicates the core API group
    resources: ["pods"]    # resource this role grants permission on
    verbs: ["get", "watch", "list"]   # allowed actions
```

### `binding.yaml` — RoleBinding for krish

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pod
  namespace: default
subjects:
- kind: User
  name: krish                          # the Kubernetes user to bind
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader                     # the Role to bind to
  apiGroup: rbac.authorization.k8s.io
```

---

## Kubernetes REST API with curl

Once krish has a signed certificate and key, you can use them to make direct HTTP requests to the Kubernetes API — without `kubectl`.

For full curl command details, see [k8s-rest-api.md](k8s-rest-api.md).

### Setup

```bash
# Step 1 — Get the API server URL
kubectl config view --minify | grep server
# Output: server: https://127.0.0.1:45231

# Step 2 — Extract the CA cert
kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="kind-cka-cluster-01")].cluster.certificate-authority-data}' | base64 -d > ca.crt

# Step 3 — Make the API call as krish
curl --cacert ca.crt \
     --cert krish/krish.crt \
     --key krish/krish.key \
     https://127.0.0.1:45231/api/v1/namespaces/default/pods
```

### Useful API Endpoints

| Resource | Endpoint |
|---|---|
| List pods (default namespace) | `/api/v1/namespaces/default/pods` |
| List pods (all namespaces) | `/api/v1/pods` |
| List nodes | `/api/v1/nodes` |
| List namespaces | `/api/v1/namespaces` |
| List services | `/api/v1/namespaces/default/services` |
| List deployments | `/apis/apps/v1/namespaces/default/deployments` |
| API groups | `/apis` |

> **Note:** Core resources (pods, nodes, services) use `/api/v1`. Extended resources (deployments, replicasets) use `/apis/apps/v1`. This reflects the Kubernetes API group structure.

---

## Full Flow Summary

```
openssl genrsa        →  krish.key        (private key — never share)
openssl req           →  krish.csr        (certificate signing request)
kubectl apply csr     →  Kubernetes CA receives the request
kubectl approve       →  Kubernetes CA signs it
kubectl get csr       →  krish.crt        (signed certificate)
                               │
                               ▼
kubectl set-credentials  →  registers key + cert in kubeconfig
kubectl set-context      →  links krish to the cluster
kubectl use-context      →  activates krish's context
                               │
                               ▼
kubectl apply role.yaml     →  creates pod-reader Role
kubectl apply binding.yaml  →  binds pod-reader to krish
                               │
                               ▼
kubectl get pods         →  authenticates as krish ✅
                           authorizes via pod-reader role ✅
```

---

## Quick Reference

**Certificate & CSR**

| Action | Command |
|---|---|
| Generate private key | `openssl genrsa -out krish/krish.key 2048` |
| Generate CSR | `openssl req -new -key krish/krish.key -out krish/krish.csr -subj "/CN=krish"` |
| Base64 encode CSR | `cat krish/krish.csr \| base64 \| tr -d "\n"` |
| Apply CSR | `kubectl apply -f krish/csr.yaml` |
| List CSRs | `kubectl get csr` |
| Approve CSR | `kubectl certificate approve krish` |
| Extract signed cert | `kubectl get csr krish -o jsonpath='{.status.certificate}' \| base64 -d > krish/krish.crt` |

**RBAC**

| Action | Command |
|---|---|
| Apply role | `kubectl apply -f role.yaml` |
| Apply binding | `kubectl apply -f binding.yaml` |
| List roles | `kubectl get roles` |
| List role bindings | `kubectl get rolebindings` |
| Count all roles cluster-wide | `kubectl get roles -A --no-header \| wc -l` |
| Check permission | `kubectl auth can-i get pods --as krish` |
| Check current user | `kubectl auth whoami` |

**Kubeconfig & Context**

| Action | Command |
|---|---|
| Set credentials | `kubectl config set-credentials krish --client-key=krish/krish.key --client-certificate=krish/krish.crt --embed-certs=true` |
| Set context | `kubectl config set-context krish --cluster=kind-cka-cluster-01 --user=krish` |
| List contexts | `kubectl config get-contexts` |
| Switch context | `kubectl config use-context krish` |
| View kubeconfig | `kubectl config view` |

---

## References

- [Kubernetes Docs — Organizing Cluster Access with Kubeconfig](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- [Kubernetes Docs — Certificate Signing Requests](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/)
- [Kubernetes Docs — RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Kubernetes Docs — Authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)