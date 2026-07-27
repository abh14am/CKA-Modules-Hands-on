# Kubernetes — ConfigMap and Secret

This guide covers how to manage application configuration and sensitive data in Kubernetes using **ConfigMaps** and **Secrets** — keeping your configuration separate from your container images.

---

## Table of Contents

- [What is a ConfigMap?](#what-is-a-configmap)
- [What is a Secret?](#what-is-a-secret)
- [ConfigMap vs Secret](#configmap-vs-secret)
- [Creating a ConfigMap](#creating-a-configmap)
  - [Method 1 — Imperative (Literal Values)](#method-1--imperative-literal-values)
  - [Method 2 — Imperative (From File)](#method-2--imperative-from-file)
  - [Method 3 — Declarative (YAML)](#method-3--declarative-yaml)
- [Using a ConfigMap in a Pod](#using-a-configmap-in-a-pod)
  - [Way 1 — envFrom (Recommended)](#way-1--envfrom-recommended)
  - [Way 2 — env with specific key](#way-2--env-with-specific-key)
- [Verify ConfigMap inside Pod](#verify-configmap-inside-pod)
- [Creating a Secret](#creating-a-secret)
  - [Imperative Way](#imperative-way)
  - [Declarative Way](#declarative-way)
- [Using a Secret in a Pod](#using-a-secret-in-a-pod)
- [Quick Reference](#quick-reference)
- [References](#references)

---

## What is a ConfigMap?

A **ConfigMap** stores non-sensitive configuration data as key-value pairs and injects them into pods as environment variables or mounted files. This lets you separate configuration from your container image — so you can change config without rebuilding the image.

**Examples of what goes in a ConfigMap:**
- App settings (`APP_ENV=production`, `LOG_LEVEL=debug`)
- Feature flags
- Database hostnames
- Configuration files

---

## What is a Secret?

A **Secret** is similar to a ConfigMap but is designed to hold **sensitive data** such as passwords, API keys, and tokens. Secrets are base64-encoded and can be encrypted at rest in the cluster.

**Examples of what goes in a Secret:**
- Database passwords
- API tokens
- TLS certificates
- SSH keys

---

## ConfigMap vs Secret

| | ConfigMap | Secret |
|---|---|---|
| **Data type** | Non-sensitive config | Sensitive credentials |
| **Encoding** | Plain text | Base64 encoded |
| **Encrypted at rest** | ❌ No | ✅ Optional (with encryption provider) |
| **Use case** | App settings, env config | Passwords, tokens, keys |
| **Kind** | `ConfigMap` | `Secret` |

---

## Creating a ConfigMap

### Method 1 — Imperative (Literal Values)

Create a ConfigMap directly from the command line using `--from-literal`:

```bash
kubectl create configmap app-cm --from-literal=firstname=steve
```

Create with multiple key-value pairs:

```bash
kubectl create configmap app-cm \
  --from-literal=firstname=steve \
  --from-literal=lastname=Rogers
```

View the created ConfigMap:

```bash
# List all ConfigMaps
kubectl get cm

# View details of a specific ConfigMap
kubectl get cm/app-cm

# View the full content of a ConfigMap
kubectl describe cm/app-cm
```

---

### Method 2 — Imperative (From File)

Create a ConfigMap from an existing YAML or config file:

```bash
kubectl create cm app-cm --from-file=app_configmap.yaml
```

> **Note:** When using `--from-file`, the entire file content becomes the value under a key named after the filename. Use `--from-env-file` instead if your file contains `KEY=VALUE` pairs.

---

### Method 3 — Declarative (YAML)

Create `app_configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-cm
data:
  firstname: steve
  lastname: Rogers
```

Apply it:

```bash
kubectl apply -f app_configmap.yaml
```

---

## Using a ConfigMap in a Pod

Once a ConfigMap is created, inject it into a pod as environment variables. There are two ways to do this.

Create `test_pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  labels:
    name: myapp-pod
spec:
  containers:
  - name: myapp-containers
    image: busybox:1.28
    command: ['sh', '-c', 'echo the app is running!! && sleep 3600']

    # Way 1 — inject ALL keys from ConfigMap as env vars (recommended)
    envFrom:
    - configMapRef:
        name: app-cm

    # Way 2 — inject a SPECIFIC key from ConfigMap as an env var
    # env:
    # - name: FIRSTNAME
    #   valueFrom:
    #     configMapKeyRef:
    #       name: app-cm
    #       key: firstname
```

### Way 1 — `envFrom` (Recommended)

```yaml
envFrom:
- configMapRef:
    name: app-cm
```

- Injects **all key-value pairs** from the ConfigMap as environment variables
- The key names in the ConfigMap become the environment variable names
- Most efficient — no need to list each key individually
- Best when you want all config values available in the container

### Way 2 — `env` with Specific Key

```yaml
env:
- name: FIRSTNAME
  valueFrom:
    configMapKeyRef:
      name: app-cm
      key: firstname
```

- Injects a **single specific key** from the ConfigMap
- You control the environment variable name (`FIRSTNAME`)
- Best when you only need select values or want to rename the variable

| | `envFrom` | `env` with `configMapKeyRef` |
|---|---|---|
| **Injects** | All keys | One specific key |
| **Variable name** | Same as key in ConfigMap | You define it |
| **Best for** | Full config injection | Selective or renamed vars |

Apply the pod:

```bash
kubectl apply -f test_pod.yaml
```

---

## Verify ConfigMap inside Pod

Get a shell inside the pod and check the injected environment variables:

```bash
kubectl exec -it myapp -- sh
```

Inside the pod:

```sh
# Check the injected value
echo $FIRSTNAME

# List all environment variables to see everything injected
env | grep -i firstname
```


---

## Creating a Secret

### Imperative Way

```bash
kubectl create secret generic app-secret \
  --from-literal=db-password=mysecretpassword \
  --from-literal=api-key=abc123xyz
```

View the secret (values will be base64-encoded):

```bash
kubectl get secret
kubectl describe secret/app-secret
```

> **Note:** `kubectl describe` shows the key names and sizes but **not the values** — this is intentional to prevent accidental exposure.

To view the actual base64-encoded values:

```bash
kubectl get secret/app-secret -o yaml
```

To decode a value:

```bash
echo "bXlzZWNyZXRwYXNzd29yZA==" | base64 --decode
```

---

### Declarative Way

Values in the YAML must be **base64-encoded**:

```bash
# Encode your values first
echo -n "mysecretpassword" | base64
# Output: bXlzZWNyZXRwYXNzd29yZA==
```

Create `app_secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  db-password: bXlzZWNyZXRwYXNzd29yZA==   # base64 encoded value
  api-key: YWJjMTIzeHl6             # base64 encoded value
```

Apply it:

```bash
kubectl apply -f app_secret.yaml
```

> **Security Note:** Never commit `Secret` YAML files with real values to version control. Use tools like [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) or [External Secrets Operator](https://external-secrets.io/) in production.

---

## Using a Secret in a Pod

Inject a Secret into a pod the same way as a ConfigMap:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-secret
spec:
  containers:
  - name: myapp-containers
    image: busybox:1.28
    command: ['sh', '-c', 'echo running && sleep 3600']

    # Way 1 — inject all secret keys as env vars
    envFrom:
    - secretRef:
        name: app-secret

    # Way 2 — inject a specific secret key
    # env:
    # - name: DB_PASSWORD
    #   valueFrom:
    #     secretKeyRef:
    #       name: app-secret
    #       key: db-password
```

> **Note:** Kubernetes automatically **base64-decodes** the Secret values when injecting them into the container — your app receives the plain text value, not the encoded version.

---

## Quick Reference

**ConfigMap**

| Action | Command |
|---|---|
| Create from literal | `kubectl create configmap app-cm --from-literal=firstname=steve` |
| Create from file | `kubectl create cm app-cm --from-file=app_configmap.yaml` |
| Apply declarative | `kubectl apply -f app_configmap.yaml` |
| List ConfigMaps | `kubectl get cm` |
| View ConfigMap | `kubectl get cm/app-cm` |
| Describe ConfigMap | `kubectl describe cm/app-cm` |

**Secret**

| Action | Command |
|---|---|
| Create from literal | `kubectl create secret generic app-secret --from-literal=db-password=pass` |
| Apply declarative | `kubectl apply -f app_secret.yaml` |
| List Secrets | `kubectl get secret` |
| Describe Secret | `kubectl describe secret/app-secret` |
| View encoded values | `kubectl get secret/app-secret -o yaml` |
| Decode a value | `echo "<base64-value>" \| base64 --decode` |


---

## References

- [Kubernetes Docs — ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Kubernetes Docs — Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Kubernetes Docs — Configure a Pod to Use a ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- [Kubernetes Docs — Distribute Credentials Using Secrets](https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/)