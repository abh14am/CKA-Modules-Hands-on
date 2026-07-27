# Kubernetes — Managing TLS Certificates

Kubernetes has a built-in **Certificate Signing Request (CSR)** API that lets cluster administrators issue, approve, and manage TLS certificates for users, kubelets, and services. This is the standard way to grant users cryptographic identity within a Kubernetes cluster.

---

## Table of Contents

- [Types of Certificates in Kubernetes](#types-of-certificates-in-kubernetes)
- [How Certificate Issuance Works](#how-certificate-issuance-works)
- [Hands-on — Issue a Certificate for a User](#hands-on--issue-a-certificate-for-a-user)
  - [Step 1 — Generate a Private Key](#step-1--generate-a-private-key)
  - [Step 2 — Generate a CSR File](#step-2--generate-a-csr-file)
  - [Step 3 — Base64 Encode the CSR](#step-3--base64-encode-the-csr)
  - [Step 4 — Create and Apply the CSR YAML](#step-4--create-and-apply-the-csr-yaml)
  - [Step 5 — View and Describe the CSR](#step-5--view-and-describe-the-csr)
  - [Step 6 — Approve or Deny the CSR](#step-6--approve-or-deny-the-csr)
  - [Step 7 — Share the Certificate with the User](#step-7--share-the-certificate-with-the-user)
  - [Step 8 — Decode the Certificate](#step-8--decode-the-certificate)
- [Quick Reference](#quick-reference)
- [References](#references)

---

## Types of Certificates in Kubernetes

Kubernetes uses TLS certificates in three main contexts:

| Type | Purpose | Example |
|---|---|---|
| **Client Certificates** | Authenticate users and components to the API server | `kubectl` users, kubelets authenticating to control plane |
| **Server Certificates** | Authenticate the API server and other components to clients | `kube-apiserver` TLS cert, etcd server cert |
| **CA Certificates** | The root Certificate Authority that signs and trusts all other certs | `ca.crt` — cluster root CA |

```
Cluster CA (ca.crt / ca.key)
    │
    ├── Signs ──► API Server Certificate      (server cert)
    ├── Signs ──► etcd Certificate            (server cert)
    ├── Signs ──► kubelet Client Certificate  (client cert)
    └── Signs ──► User Certificate (tony.crt) (client cert)
```

> All certificates in the cluster are signed by the **Cluster CA**. Any certificate signed by this CA is trusted by the API server.

---

## How Certificate Issuance Works

The flow for issuing a certificate to a user:

```
User                          Admin / Kubernetes
 │                                   │
 │── 1. Generate private key ────────►│
 │── 2. Create CSR ──────────────────►│
 │                                   │── 3. Submit CSR to API server
 │                                   │── 4. Admin reviews CSR
 │                                   │── 5. Admin approves CSR
 │                                   │── 6. Kubernetes signs certificate
 │◄── 7. Share signed certificate ───│
 │
 │── 8. Use cert + key to authenticate to cluster
```

---

## Hands-on — Issue a Certificate for a User

This walkthrough issues a TLS certificate for a user named **tony**.

---

### Step 1 — Generate a Private Key

Generate a 2048-bit RSA private key for the user:

```bash
openssl genrsa -out tony.key 2048
```

| Part | Description |
|---|---|
| `genrsa` | Generate an RSA private key |
| `-out tony.key` | Save the private key to `tony.key` |
| `2048` | Key size in bits (2048 is the minimum recommended) |

This produces `tony.key` — the private key. **This file must be kept secret and never shared.** Only the signed certificate is shared with the user later.

---

### Step 2 — Generate a CSR File

Create a Certificate Signing Request using the private key:

```bash
openssl req -new -key tony.key -out tony.csr -subj "/CN=tony"
```

| Flag | Description |
|---|---|
| `req -new` | Create a new CSR |
| `-key tony.key` | Use tony's private key |
| `-out tony.csr` | Save the CSR to `tony.csr` |
| `-subj "/CN=tony"` | Set the Common Name (CN) — this becomes the **Kubernetes username** |

> **Important:** The `/CN=` value in the subject is used as the **username** in Kubernetes RBAC. Make sure it matches the name you want to grant permissions to.

To include a group (e.g. for RBAC group binding), add `/O=`:

```bash
openssl req -new -key tony.key -out tony.csr -subj "/CN=tony/O=developers"
```

The generated `tony.csr` looks like this:

```
-----BEGIN CERTIFICATE REQUEST-----
MIICVDCCATwCAQAwDzENMAsGA1UEAwwEdG9ueTCCASIwDQYJKoZIhvcNAQEBBQAD
ggEPADCCAQoCggEBALNVDpZbNTUSd5d/+hJZLtrDmij5MqcDsbRO++CMoshEVqJp
wutv+vG2UXtu90W0afaezqoKME32Dv6ewMikIVozZ1hs9ELBFiMtXTqR8DS6XonT
F16noIj4n5Ex/sQdl4YeYoOA1dwr+TPSBZz8ROwDeWYFdQYU/NFFaB14ajYy15z8
...
-----END CERTIFICATE REQUEST-----
```

The generated `tony.key` (private key) looks like this — **never share this file**:

```
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCzVQ6WWzU1EneX
f/oSWS7aw5oo+TKnA7G0TvvgjKLIRFaiacLrb/rxtlF7bvdFtGn2ns6qCjBN9g7+
...
-----END PRIVATE KEY-----
```

---

### Step 3 — Base64 Encode the CSR

The CSR must be base64-encoded (in a single line with no line breaks) before pasting it into the Kubernetes CSR YAML:

```bash
cat tony.csr | base64 | tr -d "\n"
```

| Part | Description |
|---|---|
| `cat tony.csr` | Read the CSR file |
| `base64` | Encode it in base64 |
| `tr -d "\n"` | Remove all newlines — the output must be a single unbroken line |

Copy the output — you will paste it into the CSR YAML in the next step.

---

### Step 4 — Create and Apply the CSR YAML

Create `csr.yaml` and paste the base64-encoded CSR into the `request` field:

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: tony
spec:
  request: LS0t0tCg==......................................  # base64 encoded single line — tony's CSR
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400   # 1 day
  usages:
  - client auth
```

**Field Breakdown:**

| Field | Description |
|---|---|
| `metadata.name` | Name of the CSR object in Kubernetes |
| `spec.request` | Base64-encoded CSR content (single line, no newlines) |
| `signerName` | Which CA signs this cert — `kubernetes.io/kube-apiserver-client` for user client certs |
| `expirationSeconds` | How long the cert is valid — `86400` = 1 day |
| `usages` | `client auth` means this cert is used to authenticate to the API server |

Apply the CSR:

```bash
kubectl apply -f csr.yaml
```

---

### Step 5 — View and Describe the CSR

After applying, the CSR is in **Pending** state waiting for admin approval:

```bash
# List all CSRs — check the CONDITION column
kubectl get csr

# Detailed view — shows requester, usages, and events
kubectl describe csr tony
```

Expected output from `kubectl get csr`:

```
NAME   AGE   SIGNERNAME                            REQUESTOR          REQUESTEDDURATION   CONDITION
tony   10s   kubernetes.io/kube-apiserver-client   kubernetes-admin   24h                 Pending
```

---

### Step 6 — Approve or Deny the CSR

As a cluster admin, review the CSR and approve or deny it:

**Approve:**

```bash
kubectl certificate approve tony
```

**Deny:**

```bash
kubectl certificate deny tony
```

After approval, the CONDITION changes from `Pending` to `Approved,Issued`:

```
NAME   AGE   SIGNERNAME                            REQUESTOR          CONDITION
tony   30s   kubernetes.io/kube-apiserver-client   kubernetes-admin   Approved,Issued
```

> **Note:** Once approved, Kubernetes signs the certificate using the cluster CA and makes it available in the CSR object. Once denied, the CSR cannot be re-approved — the user must submit a new CSR.

---

### Step 7 — Share the Certificate with the User

Export the approved CSR (including the signed certificate) to a YAML file:

```bash
kubectl get csr tony -o yaml > tony-issue-cert.yaml
```

The output file `tony-issue-cert.yaml` contains the full CSR object including the approval status and the signed certificate. Here is what the file looks like after approval:

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: tony
  uid: 3c300e10-f4df-44a4-9f74-e1a544b1cc29
spec:
  expirationSeconds: 86400
  groups:
  - kubeadm:cluster-admins
  - system:authenticated
  request: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0K...  # tony's original CSR
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
  username: kubernetes-admin
status:
  certificate: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUM5VENDQWQyZ0F3SUJBZ0lSQUtEcmtVbGd2...  # signed certificate
  conditions:
  - message: This CSR was approved by kubectl certificate approve.
    reason: KubectlApprove
    status: "True"
    type: Approved
```

**Key fields in the output:**

| Field | Description |
|---|---|
| `spec.username` | The admin who submitted the CSR (`kubernetes-admin`) |
| `spec.groups` | Groups the requester belongs to |
| `status.certificate` | The **signed certificate** in base64 — this is what you share with tony |
| `status.conditions[].type` | `Approved` confirms the CSR was approved |
| `status.conditions[].message` | Shows it was approved via `kubectl certificate approve` |

Copy the value of `status.certificate` — you will decode it in the next step.

---

### Step 8 — Decode the Certificate

The `status.certificate` value in `tony-issue-cert.yaml` is base64-encoded. Copy that value and decode it to get the actual PEM certificate:

```bash
echo "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUM5VENDQWQyZ0F3SUJBZ0lSQUtEcmtVbGd2aGNwL0xDdksvK2VCdFF3RFFZSktvWklodmNOQVFFTEJRQXcKRlRFVE1CRUdBMVVFQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TmpBMk1ERXlNVEEzTURSYUZ3MHlOakEyTURJeQpNVEEzTURSYU1BOHhEVEFMQmdOVkJBTVRCSFJ2Ym5rd2dnRWlNQTBHQ1NxR1NJYjNEUUVCQVFVQUE0SUJEd0F3CmdnRUtBb0lCQVFDelZRNldXelUxRW5lWGYvb1NXUzdhdzVvbytUS25BN0cwVHZ2Z2pLTElSRmFpYWNMcmIvcngKdGxGN2J2ZEZ0R24ybnM2cUNqQk45ZzcrbnNESXBDRmFNMmRZYlBSQ3dSWWpMVjA2a2ZBMHVsNkoweGRlcDZDSQorSitSTWY3RUhaZUdIbUtEZ05YY0sva3owZ1djL0VUc0EzbG1CWFVHRlB6UlJXZ2RlR28yTXRlYy9EOG5GeEsxCkt1UXFXSCs2ZU9hNDMyWCtTS0h2MXJlSUgyTy9YZjRZcjF5aGQyamo1MExtclRpSm4yUFFqWVM1blpEajlZM0QKZ0NnVVVwb0tCMldCbGc2UnpKMXNBUmVCUG1naDlmNkFhdUQ1d1R3OFVydE1aNzZDN2NhQ0JDTGRoMTU2NEF6QwpXM2liYVFYNzgvTDRTazBSOFpPMzZwd0tPUG5ldzd3NUFnTUJBQUdqUmpCRU1CTUdBMVVkSlFRTU1Bb0dDQ3NHCkFRVUZCd01DTUF3R0ExVWRFd0VCL3dRQ01BQXdId1lEVlIwakJCZ3dGb0FVNEVTMHpGT2d2VjhkRC9BaTVGU1YKT0czSlJxMHdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBQXcvYkJoQkttbXpLaWptNDZkMkRrQ0NqTXhWSHZUUwpTbEhTcDd2ajFkeWhQVm5zanRTeGNBSDRWdXZSUkNWM1dOY1NEcFV2Y0pKVkpORkp4VTduUC9MTUdYaUlqclBxCjloTzBmb2IwR1BFWDRha1ZaRk9XTzBXcjVPcm9kSUZEc2tIUUZKUVlCekJHWTlYYy9JMkhVOUhXSzQ5aXBMV1gKUXhYNVg2SG1DQVdXTktnOTVFb1V6NWdsaVA0WVNReVlOb0JDOVhHSE9scFU5dldPdXYzY0h1eGhHVkNFWENWcApDMnBFQzhRNVErcFN2QmlndXhEREt4OTBzZHNFSnBwbHkrTld2bUUzQnZkZGExU0RsQ0dwemR6MDA5akwwZlRyCnJtL2toVVhjRmppbHBOQXhlYkg4WmNqanBqZnExYkt5bmI4cW1QTDFROHM0S2k2RFBlZE1ERW89Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K" | base64 -d
```

The decoded output is tony's signed PEM certificate:

```
-----BEGIN CERTIFICATE-----
MIIC9TCCAd2gAwIBAgIRAKDrkUlgvhcp/LCvK/+eBtQwDQYJKoZIhvcNAQELBQAw
...
-----END CERTIFICATE-----
```

To save it directly to a `.crt` file:

```bash
echo "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t..." | base64 -d > tony.crt
```

The user now has:
- `tony.key` — their private key
- `tony.crt` — the signed certificate from the cluster CA

They can use these to configure `kubectl` access:

```bash
kubectl config set-credentials tony \
  --client-certificate=tony.crt \
  --client-key=tony.key

kubectl config set-context tony-context \
  --cluster=<cluster-name> \
  --user=tony
```

---

## Quick Reference

| Action | Command |
|---|---|
| Generate private key | `openssl genrsa -out tony.key 2048` |
| Generate CSR | `openssl req -new -key tony.key -out tony.csr -subj "/CN=tony"` |
| Base64 encode CSR | `cat tony.csr \| base64 \| tr -d "\n"` |
| Apply CSR to cluster | `kubectl apply -f csr.yaml` |
| List all CSRs | `kubectl get csr` |
| Describe a CSR | `kubectl describe csr tony` |
| Approve a CSR | `kubectl certificate approve tony` |
| Deny a CSR | `kubectl certificate deny tony` |
| Export signed cert | `kubectl get csr tony -o yaml > issue-tony-cert.yaml` |
| Decode certificate | `echo "<base64>" \| base64 -d` |
| Save decoded cert | `echo "<base64>" \| base64 -d > tony.crt` |

---

## References

- [Kubernetes Docs — Certificate Signing Requests](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/)
- [Kubernetes Docs — Manage TLS Certificates in a Cluster](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)
- [Kubernetes Docs — Authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)