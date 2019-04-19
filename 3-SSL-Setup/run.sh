#!/usr/bin/env bash

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

sudo helm repo update

kubectl create -f rbac-config.yaml
helm init --service-account tiller --tiller-image jessestuart/tiller --client-only --upgrade
# Patch Helm to land on an ARM node because of the used image
kubectl patch deployment tiller-deploy -n kube-system --patch '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/arch": "arm64"}}}}}'

sleep 20s
sudo helm del --purge consul-traefik
sleep 5s

sudo helm install --name consul-traefik stable/consul --set ImageTag=1.4.4 --namespace kube-system

# Deploy Traefik INGRESS
kctl apply -f external-traefik-ingress.yaml
sleep 10s

# Deploy Traefik RBAC
kctl apply -f traefik-rbac.yaml

# Deploy external Traefik config and store it into Consul
kctl apply -f external-traefik-configmap.yaml
sleep 5s
kctl apply -f job-storeConfigMap-to-KV.yaml

# Deploy external Traefik and it's service
kctl apply -f external-traefik-service.yaml
kctl apply -f external-traefik-statefulset.yaml
