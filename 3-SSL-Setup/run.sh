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

if ! [ -x "$(command -v helm)" ]; then
  # echo 'Error: helm is not installed. It is required to deploy the Consul cluster.' >&2
  # exit 1
  sudo curl https://raw.githubusercontent.com/helm/helm/master/scripts/get > get_helm.sh
  chmod 700 get_helm.sh
  ./get_helm.sh
  sleep 5s
fi

kubectl create -f rbac-config.yaml
helm init --service-account tiller --tiller-image jessestuart/tiller
# Patch Helm to land on an ARM node because of the used image
kubectl patch deployment tiller-deploy -n kube-system --patch '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/arch": "arm64"}}}}}'

helm install --name consul-traefik stable/consul --set ImageTag=1.4.3

sleep 20s
# Deploy Traefik RBAC
kctl apply -f traefik-rbac.yaml

# Deploy external Traefik config and store it into Consul
kctl apply -f external-traefik-configmap.yaml
kctl apply -f job-storeConfigMap-to-KV.yaml

# Deploy external Traefik and it's service
kctl apply -f external-traefik-service.yaml
kctl apply -f external-traefik-statefulset.yaml
