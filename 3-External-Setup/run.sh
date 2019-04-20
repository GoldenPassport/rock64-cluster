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

#
# NFS-Storage
#

kubectl apply -f nfs-storage.yaml
kubectl patch storageclass nfs-ssd1 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl patch deployment nfs-client-provisioner -n nfs-storage --patch '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/arch": "arm64"}}}}}'
sleep 5s

#
# Helm / Consul
#
sudo helm repo update

kubectl create -f rbac-config.yaml
helm init --service-account tiller --tiller-image jessestuart/tiller --upgrade
# Patch Helm to land on an ARM node because of the used image
kubectl patch deployment tiller-deploy -n kube-system --patch '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/arch": "arm64"}}}}}'
sleep 20s

sudo helm del --purge consul-traefik
sleep 5s

sudo helm install --name consul-traefik stable/consul --set ImageTag=1.4.4 --namespace kube-system
sleep 60s

#
# Traefik
#

kctl apply -f traefik.yaml

# Deploy Traefik INGRESS
#kctl apply -f external-traefik-ingress.yaml
#sleep 10s

# Deploy Traefik RBAC
#kctl apply -f traefik-rbac.yaml

# Deploy external Traefik config and store it into Consul
#kctl apply -f external-traefik-configmap.yaml
#sleep 5s

# Deploy external Traefik and it's service
#kctl apply -f external-traefik-service.yaml
#kctl apply -f external-traefik-statefulset.yaml

# Dashboard (External)
#kctl apply -f external-ingress.yaml

# Setup KvStore
#sleep 60s
#kctl apply -f job-storeConfigMap-to-KV.yaml
