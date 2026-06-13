#!/bin/bash

IMAGE="kindest/node:v1.33.1@sha256:050072256b9a903bd914c0b2866828150cb229cea0efe5892e2b644d5dd3b34f"
CONFIG_FILE="kind-config.yaml"

#Check if kind and kubectl is installed
if ! command -v kind &> /dev/null; then
  echo "❌ kind is not installed."
  echo "👉 Install it from: https://kind.sigs.k8s.io/docs/user/quick-start/"
  exit 1
fi

if ! command -v kubectl &> /dev/null; then
  echo "❌ kubectl is not installed."
  echo "👉 Install it from: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
  exit 1
fi


read -p "Enter Kind cluster name: " CLUSTER_NAME

if [ -z "$CLUSTER_NAME" ]; 
then
  echo "❌ Cluster name cannot be empty."
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; 
then
  echo "❌ Config file '$CONFIG_FILE' not found in current directory."
  exit 1
fi

if kind get clusters | grep -q "^${CLUSTER_NAME}$"; 
then
  echo "⚠️ Cluster '$CLUSTER_NAME' already exists. Skipping creation."
else
  echo "🚀 Creating cluster '$CLUSTER_NAME'..."

  kind create cluster \
    --name "$CLUSTER_NAME" \
    --image "$IMAGE" \
    --config "$CONFIG_FILE"

  if [ $? -eq 0 ]; 
  then
    echo "✅ Cluster '$CLUSTER_NAME' created successfully."
  else
    echo "❌ Failed to create cluster '$CLUSTER_NAME'."
  fi
fi
