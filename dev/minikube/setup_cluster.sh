#!/usr/bin/env bash

SCRIPT_DIR=$(dirname $0)
PREREQUISITES=${SCRIPT_DIR}/../../scripts/prerequisites.sh
UPDATE_HOSTS=${SCRIPT_DIR}/../../scripts/update_hosts.sh

source $PREREQUISITES kubectl minikube linkerd kustomize veidemannctl

set -e

minikube start # --cpus 4 --memory 12000 --driver docker

# Create patch and update /etc/hosts for local cluster ip
LOCAL_IP=$(minikube ip)

cat <<EOF >minikube_ip_patch.yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: veidemann-controller
    spec:
      template:
        spec:
          hostAliases:
            - ip: $(minikube ip)
              hostnames:
                - veidemann.local
EOF

$UPDATE_HOSTS $LOCAL_IP veidemann.local linkerd.veidemann.local

echo "Waiting for nodes to be ready"
kubectl wait --for=condition=Ready nodes --all --timeout=5m
echo

kubectl config set contexts.minikube.namespace veidemann

# Install Service mesh
LINKERD_SERVER_VERSION=$(linkerd version | tail -1 | awk '{print $3}')
if [ "$LINKERD_SERVER_VERSION" = "unavailable" ]; then
  linkerd check --pre
  linkerd install | kubectl apply -f -
fi
linkerd check

# Install Ingress controller
kustomize build ${SCRIPT_DIR}/../bases/traefik | kubectl apply -f -

# Install Redis operator
kustomize build ${SCRIPT_DIR}/../../bases/redis-operator | kubectl apply -f -

# Install jaeger operator
kustomize build ${SCRIPT_DIR}/../../bases/jaeger-operator | kubectl apply -f -

# Give kubernetes time to initilaze jaeger operator CRDs before installing jaeger
sleep 1

# Install jaeger
kustomize build ${SCRIPT_DIR}/../bases/jaeger | kubectl apply -f -
