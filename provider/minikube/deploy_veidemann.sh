#!/usr/bin/env bash

# Basic safeguard to ensure that we're working in a development-context
if ! [[ $(kubectl config current-context) = *minikube* ]]; then echo "WARNING: Not a dev context, use: kubectl config use-context minikube";  exit 1; fi

SCRIPT_DIR=$(dirname $0)

kubectl apply -k ${SCRIPT_DIR}

${SCRIPT_DIR}/../../dev/veidemann/scylla/install_scylla.sh
