#!/usr/bin/env bash

OPSYS=$(uname)
KUSTOMIZE_VERSION=v4.3.0
KIND_VERSION=0.10.0
LINKERD_VERSION=stable-2.10.2
KUBECTL_VERSION=v1.22.2
MINIKUBE_VERSION=v1.23.2
VEIDEMANNCTL_VERSION=0.4.0
HELM_VERSION=v3.7.0

function check_cmd() {
  local CMD=$1
  local VER=$2
  W=$(which ${CMD} 2>/dev/null)
  if [ $? -ne 0 ]; then
    ask "${CMD} not found. Would you like to install ${CMD} ${VER}? (y/n)"
    return $?
  fi

  CURRENT_VER=$(eval $(printf "%s %s" "$W" "$3"))

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
  case $CMD in
  kubectl)
    check_cmd kubectl $KUBECTL_VERSION 'version --client --short | sed -e "s/Client Version: \(.*\)/\1/"'
    INSTALL=$?
    if [ $INSTALL -ne 0 ]; then
      echo "Installing Kubectl"
      curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
      sudo install kubectl /usr/local/bin
      sudo sh -c "/usr/local/bin/kubectl completion bash > /etc/bash_completion.d/kubectl"
      rm kubectl
    fi
    ;;
  kind)
    check_cmd kind $KIND_VERSION '-q version'
    INSTALL=$?
    if [ $INSTALL -ne 0 ]; then
      echo "Installing Kind"
      curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-${OPSYS}-amd64
      sudo install kind /usr/local/bin/kind
      sudo sh -c "/usr/local/bin/kind completion bash > /etc/bash_completion.d/kind"
      rm kind
    fi
    ;;
  kustomize)
    check_cmd kustomize $KUSTOMIZE_VERSION 'version --short | sed -e "s/{kustomize\/\(\S\+\).*/\1/"'
    INSTALL=$?
    if [ $INSTALL -ne 0 ]; then
      echo "Installing Kustomize"
      curl -L https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_${OPSYS}_amd64.tar.gz |
        tar xz
      sudo install kustomize /usr/local/bin/kustomize
      sudo sh -c "/usr/local/bin/kustomize completion bash > /etc/bash_completion.d/kustomize"
      rm kustomize
    fi
    ;;
  helm)
    check_cmd helm $HELM_VERSION 'version --short | sed "s/\([0-9]\.[0-9]\.[0-9]\).*/\1/"'
    INSTALL=$?
    if [ $INSTALL -ne 0 ]; then
      echo "Installing Helm"
      curl -L https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar xz
      sudo install linux-amd64/helm /usr/local/bin/helm
      sudo sh -c "/usr/local/bin/helm completion bash > /etc/bash_completion.d/helm"
      rm -r linux-amd64/
    fi
    ;;
  linkerd)
    check_cmd linkerd $LINKERD_VERSION 'version --client --short'
    INSTALL=$?
    if [ $INSTALL -ne 0 ]; then
      echo "Installing Linkerd"
      curl -Lo ./linkerd https://github.com/linkerd/linkerd2/releases/download/${LINKERD_VERSION}/linkerd2-cli-${LINKERD_VERSION}-linux-amd64 &&
        sudo install linkerd /usr/local/bin/linkerd
      sudo sh -c "/usr/local/bin/linkerd completion bash  > /etc/bash_completion.d/linkerd"
      rm linkerd
    fi
    ;;
  minikube)
    check_cmd minikube $MINIKUBE_VERSION 'version | grep version | sed -e "s/.*version: \(.*\)/\1/"'
    INSTALL=$?
    if [ $INSTALL -ne 0 ]; then
      echo "Installing Minikube"
      curl -Lo ./minikube https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-amd64 &&
        sudo install minikube /usr/local/bin/minikube
      sudo sh -c "/usr/local/bin/minikube completion bash > /etc/bash_completion.d/minikube"
      rm minikube
    fi
    ;;
  veidemannctl)
    check_cmd veidemannctl $VEIDEMANNCTL_VERSION '--version | sed -e "s/.*version: \(.*\), Go version.*/\1/"'
    INSTALL=$?
    if [ $INSTALL -ne 0 ]; then
      echo "Installing Veidemannctl"
      curl -Lo veidemannctl https://github.com/nlnwa/veidemannctl/releases/download/${VEIDEMANNCTL_VERSION}/veidemannctl_${VEIDEMANNCTL_VERSION}_linux_amd64 &&
        sudo install veidemannctl /usr/local/bin/veidemannctl &&
        sudo sh -c "/usr/local/bin/veidemannctl completion > /etc/bash_completion.d/veidemannctl"
        rm veidemannctl
    fi
    ;;
  esac
done
echo
