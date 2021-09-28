#!/usr/bin/env bash

helm repo add scylla-operator https://storage.googleapis.com/scylla-operator-charts/stable
helm repo update

helm upgrade scylla-operator scylla-operator/scylla-operator \
--install \
--create-namespace \
-f values.yaml \
--namespace scylla-operator

kubectl wait --for condition=established crd/scyllaclusters.scylla.scylladb.com
kubectl -n scylla-operator rollout status deployment.apps/scylla-operator -w
