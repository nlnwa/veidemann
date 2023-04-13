#!/usr/bin/env bash

kubectl --context=kind-kind apply -k "$(dirname $0)"
