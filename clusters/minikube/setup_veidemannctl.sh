#!/usr/bin/env bash

SCRIPT_DIR=$(dirname $0)

# Install veidemannctl
source "${SCRIPT_DIR}"/../../scripts/prerequisites.sh veidemannctl

veidemannctl config create-context minikube
veidemannctl config use-context minikube
veidemannctl config set-address veidemann.test:443

# With auth component enabled
kubectl --context=minikube get secrets -n veidemann veidemann-tls -o jsonpath="{.data.tls\.crt}" | base64 -d > ca.crt

# Without auth component enabled
# kubectl --context=minikube get secrets -n ingress-traefik default-tls -o jsonpath="{.data.ca\.crt}" | base64 -d > ca.crt

veidemannctl config import-ca ca.crt
rm ca.crt
