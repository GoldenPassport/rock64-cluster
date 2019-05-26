#!/usr/bin/env bash
# 2-run.sh
#
# Installs Flannel, MetalLB and (Kube) Dashboards
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

# Prep
kubectl taint nodes --all node-role.kubernetes.io/master-
sleep 10s

# Flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml
sleep 10s

# MetalLB
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
kubectl apply -f metallb.yaml

# Dashboard
kctl apply -f dashboard.yaml
# kubectl apply -f dashboard.yaml --namespace="kube-system"
