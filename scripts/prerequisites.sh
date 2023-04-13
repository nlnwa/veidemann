#!/usr/bin/env bash

OPSYS=$(uname | tr '[:upper:]' '[:lower:]')
KIND_VERSION=0.18.0
LINKERD_VERSION=stable-2.13.0
KUBECTL_VERSION=v1.25.8
MINIKUBE_VERSION=v1.30.1
VEIDEMANNCTL_VERSION=0.4.1
HELM_VERSION=v3.11.3
FLUX_VERSION=0.41.2
SKAFFOLD_VERSION=v2.3.0

function check_cmd() {
  local CMD=$1
  local VER=$2
  local ARG=$3
  W=$(command -v "${CMD}")
  if [ -z "$W" ]; then
    ask "${CMD} not found. Would you like to install ${CMD} ${VER}? (y/n)"
    return $?
  fi

  CURRENT_VER=$(eval "$(printf "%s %s" "$CMD" "$ARG")")

  if ! [ "$CURRENT_VER" = "${VER}" ]; then
    ask "${CMD} version is ${CURRENT_VER}, but we would like to have ${VER}. Would you like to install ${CMD} ${VER}? (y/n)"
    return $?
  fi

  return 0
}

function ask() {
  read -p "${1}" -n 1 -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo
    return 0
  fi
  echo
  return 1
}

for CMD in "$@"; do
  case "$CMD" in
  kubectl)
    if ! check_cmd "$CMD" $KUBECTL_VERSION 'version --client --short 2>/dev/null | grep Client | sed -e "s/Client Version: \(.*\)/\1/"'
    then
      echo "Installing $CMD"
      curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/"${OPSYS}"/amd64/kubectl
      sudo install kubectl /usr/local/bin
      sudo sh -c "/usr/local/bin/kubectl completion bash > /etc/bash_completion.d/kubectl"
      rm kubectl
    fi
    ;;
  kind)
    if ! check_cmd "$CMD" $KIND_VERSION '-q version'
    then
      echo "Installing $CMD"
      curl -Lo kind https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-"${OPSYS}"-amd64
      sudo install kind /usr/local/bin/kind
      sudo sh -c "/usr/local/bin/kind completion bash > /etc/bash_completion.d/kind"
      rm kind
    fi
    ;;
  helm)
    if ! check_cmd "$CMD" $HELM_VERSION 'version --short | sed "s/\([0-9]\.[0-9]\.[0-9]\).*/\1/"'
    then
      echo "Installing $CMD"
      curl -L https://get.helm.sh/helm-${HELM_VERSION}-"${OPSYS}"-amd64.tar.gz | tar xz
      sudo install "${OPSYS}"-amd64/helm /usr/local/bin/helm
      sudo sh -c "/usr/local/bin/helm completion bash > /etc/bash_completion.d/helm"
      rm -r "${OPSYS}"-amd64/
    fi
    ;;
  linkerd)
    if ! check_cmd "$CMD" $LINKERD_VERSION 'version --client --short'
    then
      echo "Installing $CMD"
      curl -Lo ./linkerd https://github.com/linkerd/linkerd2/releases/download/${LINKERD_VERSION}/linkerd2-cli-${LINKERD_VERSION}-"${OPSYS}"-amd64
      sudo install linkerd /usr/local/bin/linkerd
      sudo sh -c "/usr/local/bin/linkerd completion bash  > /etc/bash_completion.d/linkerd"
      rm linkerd
    fi
    ;;
  minikube)
    if ! check_cmd minikube $MINIKUBE_VERSION 'version | grep version | sed -e "s/.*version: \(.*\)/\1/"'
    then
      echo "Installing $CMD"
      curl -Lo ./minikube https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-"${OPSYS}"-amd64
      sudo install minikube /usr/local/bin/minikube
      sudo sh -c "/usr/local/bin/minikube completion bash > /etc/bash_completion.d/minikube"
      rm minikube
    fi
    ;;
  veidemannctl)
    if ! check_cmd veidemannctl $VEIDEMANNCTL_VERSION '--version | sed -e "s/.*version: \(.*\), Go version.*/\1/"'
    then
      echo "Installing $CMD"
      curl -Lo veidemannctl https://github.com/nlnwa/veidemannctl/releases/download/v${VEIDEMANNCTL_VERSION}/veidemannctl_${VEIDEMANNCTL_VERSION}_"${OPSYS}"_amd64
      sudo install veidemannctl /usr/local/bin/veidemannctl
      sudo sh -c "/usr/local/bin/veidemannctl completion > /etc/bash_completion.d/veidemannctl"
      rm veidemannctl
    fi
    ;;
  flux)
    if ! check_cmd flux $FLUX_VERSION '--version | sed -e "s/flux version \(.*\)/\1/"'
    then
      echo "Installing $CMD"
      curl -L https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_"${OPSYS}"_amd64.tar.gz | tar xz
      sudo install flux /usr/local/bin/flux
      sudo sh -c "/usr/local/bin/flux completion bash > /etc/bash_completion.d/flux"
      rm flux
    fi
    ;;
  skaffold)
    if ! check_cmd skaffold ${SKAFFOLD_VERSION} version
    then
      echo "Installing $CMD"
      curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/${SKAFFOLD_VERSION}/skaffold-"${OPSYS}"-amd64
      sudo install skaffold /usr/local/bin/skaffold
      sudo sh -c "/usr/local/bin/skaffold completion bash > /etc/bash_completion.d/skaffold"
      rm skaffold
    fi
    ;;
  envsubst)
    # envsubst is not part of prerequisites but is not installed by default in many systems
    #
    # fedora: dnf install gettext
    # ubuntu: apt-get install gettext-base
    # alpine: apk add gettext
    # golang: go install github.com/drone/envsubst/cmd/envsubst
    if ! command -v envsubst &>/dev/null; then
      # sourced from https://github.com/kubernetes-sigs/cluster-api/issues/1827#issuecomment-561809846
      envsubst() {
        python -c 'import os,sys;[sys.stdout.write(os.path.expandvars(l)) for l in sys.stdin]'
      }
    fi
    ;;
  esac
done
