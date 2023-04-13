#!/usr/bin/env bash

kubectl --context=minikube apply -k "$(dirname $0)"
