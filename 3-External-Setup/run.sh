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
sudo helm reset

cat <<EOF | kubectl create --namespace="kube-system" -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
EOF

sudo helm init --service-account tiller --tiller-image jessestuart/tiller
# Patch Helm to land on an ARM node because of the used image
kubectl patch deployment tiller-deploy -n kube-system --patch '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/arch": "arm64"}}}}}'
sleep 30s

sudo helm install --name consul-traefik stable/consul --set ImageTag=1.4.4 --namespace kube-system
sleep 30s

#
# Traefik
#

kctl apply -f traefik.yaml
sleep 60s

cat <<EOF | kubectl create -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: traefik-kv-store
  namespace: kube-system
spec:
  backoffLimit: 3
  activeDeadlineSeconds: 100
  ttlSecondsAfterFinished: 5
  template:
    metadata:
      name: traefik-kv-store
    spec:
      containers:
      - name: storeconfig
        image: traefik:v1.7
        imagePullPolicy: IfNotPresent
        args: [ "storeconfig", "-c", "/config/traefik.toml" ]
        volumeMounts:
        - name: config
          mountPath: /etc/traefik
          readOnly: true
      restartPolicy: Never
      volumes:
      - name: config
        configMap:
          name: traefik-conf-external
EOF
