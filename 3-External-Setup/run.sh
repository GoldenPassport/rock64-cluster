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

#kubectl apply -f network-storage.yaml
kubectl apply -f nfs-storage.yaml
##kubectl patch storageclass nfs-network -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl patch deployment nfs-client-provisioner -n nfs-storage --patch '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/arch": "arm64"}}}}}'
sleep 5s

#
# Tiller / Consul
#
sudo helm repo update
sudo helm reset

# Tiller role
kctl apply -f tiller.yaml
sleep 60s

kubectl create secret generic traefik-external-provider -n kube-system --from-literal=key=dKD9mjoUALrT_7sHz1qAfFZe83Q5f2MbGsm --from-literal=secret=7sK1dHWLhoLexnfmzXJWcb

sudo helm init --service-account tiller --tiller-image jessestuart/tiller
sleep 60s
# Patch Helm to land on an ARM node because of the used image
kubectl patch deployment tiller-deploy -n kube-system --patch '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/arch": "arm64"}}}}}'
sleep 30s

# Consul
sudo helm del --purge consul-traefik
sudo helm install --name consul-traefik stable/consul --set ImageTag=1.4.4 --namespace kube-system
sleep 30s

#
# Traefik
#

#kubectl delete job traefik-kv-store

#cat <<EOF | kubectl create -f -
#EOF

#sleep 60s
kctl apply -f traefik.yaml
