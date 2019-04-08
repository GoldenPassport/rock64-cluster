#!/usr/bin/env bash

#
# Configuration
#
if [ -z "${KUBECONFIG}" ]; then
    export KUBECONFIG=~/.kube/config
fi

# CAUTION - setting NAMESPACE will deploy most components to the given namespace
# however some are hardcoded to 'monitoring'. Only use if you have reviewed all manifests.

if [ -z "${NAMESPACE}" ]; then
    NAMESPACE=kube-system
fi

kctl() {
    kubectl --namespace "$NAMESPACE" "$@"
}

# Prep steps
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl taint nodes --all node-role.kubernetes.io/master-

# Install Flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml

#
# Background Complete
#

#
# Setup
#

# Core Configmaps
kctl apply -f a-core-configmaps.yaml

# MetalLB
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
kubectl apply -f a-metallb-configmap.yaml

# Traefik (Internal)
kctl apply -f c-traefik-rbac.yaml
kctl apply -f c-traefik-internal-service.yaml
kctl apply -f c-traefik-internal-deployment.yaml

# Dashboard

kctl apply -f d-dashboard-admin-account.yaml
kctl apply -f d-dashboard.yaml
kctl apply -f d-dashboard-ingress.yaml
kctl apply -f d-external-ingress.yaml



