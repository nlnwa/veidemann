#!/usr/bin/env bash

SCRIPT_DIR=$(dirname $0)
PREREQUISITES=${SCRIPT_DIR}/../../scripts/prerequisites.sh
UPDATE_HOSTS=${SCRIPT_DIR}/../../scripts/update_hosts.sh

source $PREREQUISITES kubectl kind linkerd kustomize

# Create patch and update /etc/hosts for local cluster ip
LOCAL_IP=$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')

cat <<EOF >kind_ip_patch.yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: veidemann-controller
    spec:
      template:
        spec:
          hostAliases:
            - ip: ${LOCAL_IP}
              hostnames:
                - veidemann.local
EOF

$UPDATE_HOSTS $LOCAL_IP veidemann.local linkerd.veidemann.local

set -e

KIND_CLUSTER=$(kind get clusters)
if [ "$KIND_CLUSTER" != "kind" ]; then
  kind create cluster --config=kind-config.yaml
fi

echo "waiting for cluster to be ready"
kubectl wait --for=condition=Ready nodes --all --timeout=5m
echo

kubectl config set contexts.kind-kind.namespace veidemann

# Install Service mesh
LINKERD_SERVER_VERSION=$(linkerd version | tail -1 | awk '{print $3}')
if [ "$LINKERD_SERVER_VERSION" = "unavailable" ]; then
  linkerd check --pre
  linkerd install | kubectl apply -f -
fi
linkerd check

# Install Ingress controller
kustomize build ${SCRIPT_DIR}/traefik | kubectl apply -f -

# Install Redis operator
kustomize build ${SCRIPT_DIR}/../../bases/redis-operator | kubectl apply -f -

# Install jager operator
kustomize build ${SCRIPT_DIR}/../../bases/jaeger-operator | kubectl apply -f -

# Give kubernetes time to initilaze jaeger operator CRDs before installing jaeger
sleep 1

# Install jaeger
kustomize build ${SCRIPT_DIR}/../bases/jaeger | kubectl apply -f -

R=$(firewall-cmd --direct --get-rules ipv4 filter INPUT)
if [ "$R" != "4 -i docker0 -j ACCEPT" ]; then
  sudo firewall-cmd --direct --add-rule ipv4 filter INPUT 4 -i docker0 -j ACCEPT
fi
