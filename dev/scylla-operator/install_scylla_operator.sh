#!/usr/bin/env bash

helm repo add scylla-operator https://storage.googleapis.com/scylla-operator-charts/stable
helm repo update

SCRIPT_DIR=$(dirname $0)

helm upgrade scylla-operator scylla-operator/scylla-operator \
--install \
--create-namespace \
-f ${SCRIPT_DIR}/values.yaml \
--namespace scylla-operator

kubectl wait --for condition=established crd/scyllaclusters.scylla.scylladb.com
kubectl -n scylla-operator rollout status deployment.apps/scylla-operator -w
kubectl -n scylla-operator rollout status deployment.apps/webhook-server -w
