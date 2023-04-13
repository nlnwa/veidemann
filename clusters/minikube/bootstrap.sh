#!/usr/bin/env bash

SCRIPT_DIR=$(dirname $0)

# Install kubectl minikube and flux
source "${SCRIPT_DIR}"/../../scripts/prerequisites.sh kubectl minikube flux

set -e

# Start minikube
echo "Waiting for nodes to be ready"
while ! kubectl --context=minikube wait --for=condition=Ready nodes --all; do
  minikube start --kubernetes-version=1.25.8 # --cpus 4 --memory 10000 --driver podman --container-runtime cri-o
done

HOSTNAME=veidemann.test
LOCAL_IP=$(minikube ip)

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
if ! flux --context=minikube check; then
  flux --context=minikube install --components=helm-controller,source-controller
fi

# Deploy cert-manager, linkerd, traefik, scylla-operator
kubectl --context=minikube apply -k ../../infrastructure/dev/controllers

# Wait for traefik tlsstores CRD to be established
while ! kubectl --context=minikube wait --for condition=established crd/tlsstores.traefik.containo.us --timeout=5m; do sleep 5; done
while ! kubectl --context=minikube rollout status deployment cert-manager-webhook -n cert-manager --timeout=5m; do sleep 5; done
while ! kubectl --context=minikube -n scylla-operator rollout status deployment scylla-operator --timeout=5m; do sleep 5; done
while ! kubectl --context=minikube -n scylla-operator rollout status deployment webhook-server --timeout=5m; do sleep 5; done

# Install default TLS certificate
kubectl --context=minikube apply -k ../../infrastructure/dev/config

# Install rethinkdb, redis and scylla
kubectl --context=minikube apply -k ../../core/dev

# Wait for rethinkdb, redis and scylla to be rolled out
while ! kubectl --context=minikube rollout status deployment rethinkdb -n veidemann --timeout=5m; do sleep 5; done
while ! kubectl --context=minikube rollout status statefulset redis-veidemann-frontier-master -n veidemann --timeout=5m; do sleep 5; done
while ! kubectl --context=minikube rollout status statefulset scylla-dc1-rac1 -n veidemann --timeout=5m; do sleep 5; done

# Deploy veidemann
kubectl --context=minikube apply -k "${SCRIPT_DIR}"

echo
echo "🏁 Bootstrap complete!"
echo

# Update /etc/hosts such that the test hostnames resolves to minikube's ip address
"${SCRIPT_DIR}/../../scripts/update_hosts.sh" "${LOCAL_IP}" veidemann.test browser.veidemann.test linkerd.veidemann.test cd.veidemann.test traefik.veidemann.test telemetry.veidemann.test rethinkdb.veidemann.test
