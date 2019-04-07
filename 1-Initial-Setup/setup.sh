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

# A. Core Configmaps
kctl apply -f a-core-configmaps.yaml

# B. MetalLB
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml

# C. Traefik (Internal)
kctl apply -f c-traefik-rbac.yaml

kctl apply -f c-traefik-internal-service.yaml
kctl apply -f c-traefik-internal-deployment.yaml




