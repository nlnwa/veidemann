# Authentication and authorization

Configure `veidemannctl` with dev environment:
```bash
kubectl config create-context minikube
kubectl config set-address veidemann.test:443
kubectl get secrets -n veidemann veidemann-tls -o jsonpath="{.data.ca\.crt}" | base64 -d > ca.cr
veidemannctl config import-ca ca.crt
# cleanup
rm ca.crt
```
