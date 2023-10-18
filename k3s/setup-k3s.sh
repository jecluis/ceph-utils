#!/bin/bash

LH_VERSION=v1.5.1

curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 || exit 1
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config || exit 1
sudo chown joao:users ~/.kube/config || exit 1
chmod 0600 ~/.kube/config || exit 1
export KUBECONFIG=~/.kube/config
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/${LH_VERSION}/deploy/prerequisite/longhorn-iscsi-installation.yaml || exit 1
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/${LH_VERSION}/deploy/longhorn.yaml || exit 1

# install cert-manager
kubectl create namespace cert-manager || exit 1
helm repo add jetstack https://charts.jetstack.io || exit 1
helm repo update || exit 1
helm install cert-manager --namespace cert-manager jetstack/cert-manager \
  --set installCRDs=true \
  --set extraArgs[0]=--enable-certificate-owner-ref=true || exit 1

