#!/usr/bin/env bash

SCRIPT_DIR=$(dirname $0)
PREREQUISITES=${SCRIPT_DIR}/../../scripts/prerequisites.sh
UPDATE_HOSTS=${SCRIPT_DIR}/../../scripts/update_hosts.sh

source $PREREQUISITES kubectl kind helm linkerd veidemannctl

# Create patch and update /etc/hosts for local cluster ip
HOSTNAME=veidemann.test
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
            - ${HOSTNAME}
EOF

$UPDATE_HOSTS $LOCAL_IP veidemann.test linkerd.veidemann.test

set -e

KIND_CLUSTER=$(kind get clusters)
if [ "$KIND_CLUSTER" != "kind" ]; then
  kind create cluster --config=kind-config.yaml
fi

echo "Waiting for cluster to be ready"
kubectl wait --for=condition=Ready nodes --all --timeout=5m
echo

# R=$(firewall-cmd --direct --get-rules ipv4 filter INPUT)
# if [ "$R" != "4 -i docker0 -j ACCEPT" ]; then
#   sudo firewall-cmd --direct --add-rule ipv4 filter INPUT 4 -i docker0 -j ACCEPT
# fi

kubectl config set contexts.kind-kind.namespace veidemann

# Install linkerd
LINKERD_SERVER_VERSION=$(linkerd version | tail -1 | awk '{print $3}')
if [ "$LINKERD_SERVER_VERSION" = "unavailable" ]; then
  linkerd check --pre
  linkerd install | kubectl apply -f -
  linkerd check
  linkerd viz install | kubectl apply -f -
fi


# Install traefik
kubectl apply -k ${SCRIPT_DIR}/../../dev/ingress-traefik

# Install redis-operator
kubectl apply -k ${SCRIPT_DIR}/../../dev/redis-operator

# Install jaeger-operator
kubectl apply -k ${SCRIPT_DIR}/../../dev/observability

# Install linkerd ingressroute
kubectl apply -k ${SCRIPT_DIR/../../dev/linkerd-viz

# Give kubernetes time to install jaeger-operator CRD
sleep 1

# Install jaeger
kubectl apply -k ${SCRIPT_DIR}/../../dev/observability/jaeger

# Install cert manager
${SCRIPT_DIR}/../../dev/cert-manager/install_cert_manager.sh

# Install scylla-operator
${SCRIPT_DIR}/../../dev/scylla-operator/install_scylla_operator.sh
