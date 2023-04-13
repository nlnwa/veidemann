#!/usr/bin/env bash

SCRIPT_DIR=$(dirname $0)

# Install kubectl kind and flux
source "${SCRIPT_DIR}/../../scripts/prerequisites.sh" kubectl kind flux

set -e

KIND_CLUSTER=$(kind get clusters)
if [ "$KIND_CLUSTER" != "kind" ]; then
  kind create cluster --config=kind-config.yaml
fi

echo "Waiting for nodes to be ready"
kubectl --context=kind-kind wait --for=condition=Ready nodes --all --timeout=5m
echo

# R=$(firewall-cmd --direct --get-rules ipv4 filter INPUT)
# if [ "$R" != "4 -i docker0 -j ACCEPT" ]; then
#   sudo firewall-cmd --direct --add-rule ipv4 filter INPUT 4 -i docker0 -j ACCEPT
# fi

HOSTNAME=veidemann.test
LOCAL_IP=$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')

# Create hostalias patch for veidemann-controller
cat <<EOF >auth/controller_hostalias_patch.yaml
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
# Install flux
if ! flux --context=kind-kind check; then
  flux --context=kind-kind install --components=helm-controller,source-controller
fi

# Install cert-manager, linkerd, traefik, scylla-operator
kubectl --context=kind-kind apply -k "${SCRIPT_DIR}"/infrastructure

# Wait for traefik tlsstores CRD to be established
while ! kubectl --context=kind-kind wait --for condition=established crd/tlsstores.traefik.containo.us --timeout=5m; do sleep 5; done
while ! kubectl --context=kind-kind rollout status deployment cert-manager-webhook -n cert-manager --timeout=5m; do sleep 5; done
while ! kubectl --context=kind-kind -n scylla-operator rollout status deployment scylla-operator --timeout=5m; do sleep 5; done
while ! kubectl --context=kind-kind -n scylla-operator rollout status deployment webhook-server --timeout=5m; do sleep 5; done

# Install default TLS certificate
kubectl --context=kind-kind apply -k ../../infrastructure/dev/config

kubectl --context=kind-kind apply -k ../../core/dev

# Wait for rethinkdb, redis and scylla to be rolled out
while ! kubectl --context=kind-kind rollout status deployment rethinkdb -n veidemann --timeout=5m; do sleep 5; done
while ! kubectl --context=kind-kind rollout status statefulset redis-veidemann-frontier-master -n veidemann --timeout=5m; do sleep 5; done
while ! kubectl --context=kind-kind rollout status statefulset scylla-dc1-rac1 -n veidemann --timeout=5m; do sleep 5; done


kubectl --context=kind-kind apply -k "${SCRIPT_DIR}"

echo
echo "🏁 Bootstrap complete!"
echo

# Update /etc/hosts such that the test hostnames resolves to minikube's ip address
"${SCRIPT_DIR}/../../scripts/update_hosts.sh" "${LOCAL_IP}" veidemann.test browser.veidemann.test linkerd.veidemann.test cd.veidemann.test traefik.veidemann.test telemetry.veidemann.test
