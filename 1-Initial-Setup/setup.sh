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

#
# Background Complete
#


#
# Setup (A - C)
#

# B. MetalLB (MetalLB needs to be loaded first)
kubectl apply -f --namespace=metallb-system https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml

# A. Core Configmaps
kctl apply -f a-core-configmaps.yaml

# C. Traefik (Internal)
kctl apply -f c-traefik-rbac.yaml

kctl apply -f c-traefik-internal-service.yaml
kctl apply -f c-traefik-internal-deployment.yaml

# D. Dashboard

kctl apply -f d-dashboard-admin-account.yaml
kctl apply -f d-dashboard.yaml
kctl apply -f d-dashboard-ingress.yaml
kctl apply -f d-external-ingress.yaml



