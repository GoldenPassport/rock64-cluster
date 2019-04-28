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

# Remove previous setup
kubectl delete -f .

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
#sudo helm repo update
#sudo helm reset

# Tiller role
kctl apply -f tiller.yaml
sleep 60s

kubectl create secret generic traefik-external-provider -n kube-system --from-literal=key=dKD9mjoUALrT_7sHz1qAfFZe83Q5f2MbGsm --from-literal=secret=7sK1dHWLhoLexnfmzXJWcb

helm init --service-account tiller --tiller-image jessestuart/tiller
sleep 60s
# Patch Helm to land on an ARM node because of the used image
kubectl patch deployment tiller-deploy -n kube-system --patch '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/arch": "arm64"}}}}}'
sleep 5s

# Consul
sudo helm del --purge consul-traefik
sleep 15s
sudo helm install --name consul-traefik stable/consul --set ImageTag=1.4.4 --namespace kube-system
sleep 30s

#
# Traefik
#

kubectl delete configmap traefik-conf-external
sleep 5s
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: traefik-conf-external
  namespace: kube-system
data:
  traefik.toml: |
    debug = true
    logLevel = "ERROR"

    defaultEntryPoints = ["http", "https"]

    #Config to redirect http to https
    [entryPoints]
      [entryPoints.http]
      address = ":80"
        [entryPoints.http.redirect]
        entryPoint = "https"
      [entryPoints.https]
      address = ":443"
        [entryPoints.https.tls]

    [api]
      [api.statistics]
        recentErrors = 10

    [kubernetes]
      # Only create ingresses where the object has traffic-type: external label
      labelselector = "traffic-type=external"

    [metrics]
      [metrics.prometheus]
      buckets=[0.1,0.3,1.2,5.0]
      entryPoint = "traefik"

    [ping]
      entryPoint = "http"

    [accessLog]

    [consul]
      endpoint = "consul-traefik.kube-system.svc:8500"
      watch = true
      prefix = "traefik-external"

    [acme]
    email = "luke.audie@gmail.com"
    storage = "traefik-external-certificates/acme/account"
    #storage = "acme.json"
    acmeLogging = true
    entryPoint = "https"
    onHostRule = true
    caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"
    
    [acme.httpChallenge]
      entryPoint="http"

    [[acme.domains]]
      main = "bpmcrowd.com"

    [acme.dnsChallenge]
      delayBeforeCheck = 0
      provider = "godaddy"
      [godaddy]
        GODADDY_API_KEY = "dKD9mjoUALrT_7sHz1qAfFZe83Q5f2MbGsm"
        GODADDY_API_SECRET = "7sK1dHWLhoLexnfmzXJWcb"
EOF
sleep 30s

kubectl delete job traefik-kv-store
sleep 30s
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
        image: traefik:v1.7.11
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
sleep 30s

kctl apply -f traefik.yaml
