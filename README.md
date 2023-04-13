# Veidemann
Veidemann is an open-source, distributed web harvesting platform running on [kubernetes](https://kubernetes.io/).

## Quick start

The easiest way to try out Veidemann is using [minikube](https://minikube.sigs.k8s.io/docs/) or [kind](https://kind.sigs.k8s.io/). minikube and kind are local
kubernetes providers.

#### Using Minikube

```sh
# Install minikube
./scripts/prerequisites.sh minikube

# Configure minikube

# Resources
minikube config set memory 10Gi
minikube config set cpus 4

# Option 1. Configure the docker driver
minikube config set driver docker
minikube config set container-runtime containerd

# Option 2. Configure the podman driver
minikube config set driver podman
minikube config set container-runtime crio
# On Linux, Podman requires passwordless running of sudo. See https://minikube.sigs.k8s.io/docs/drivers/podman/.
sudo visudo
# Add the following at the very bottom of the file:
# my-user-name ALL=(ALL) NOPASSWD: /usr/bin/podman

./clusters/minikube/bootstrap.sh
```

#### Using Kind

```sh
./clusters/kind/bootstrap.sh
```

## License

Veidemann is distributed under the Apache 2.0 license. See the [LICENSE](./LICENSE) file for details.
