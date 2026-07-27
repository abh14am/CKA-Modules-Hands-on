# Kubernetes REST API - curl Commands

## Setup (kind cluster)

### Step 1 — Get the API server URL
```bash
kubectl config view --minify | grep server
# Output example: server: https://127.0.0.1:45231
```

### Step 2 — Extract the CA cert
```bash
kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="kind-cka-cluster-01")].cluster.certificate-authority-data}' | base64 -d > ca.crt
```

### Step 3 — Run the curl command
```bash
curl --cacert ca.crt \
     --cert krish/krish.crt \
     --key krish/krish.key \
     https://127.0.0.1:45231/api/v1/namespaces/default/pods
```

---

## Useful API Endpoints

| What | Endpoint |
|------|----------|
| List pods (default namespace) | `/api/v1/namespaces/default/pods` |
| List pods (all namespaces) | `/api/v1/pods` |
| List nodes | `/api/v1/nodes` |
| List namespaces | `/api/v1/namespaces` |
| List services | `/api/v1/namespaces/default/services` |
| List deployments | `/apis/apps/v1/namespaces/default/deployments` |
| API groups | `/apis` |

> Notice deployments use `/apis/apps/v1` not `/api/v1` — core resources use `/api`, everything else uses `/apis`
