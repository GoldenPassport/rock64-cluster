#!/usr/bin/env bash
# 3-run.sh
#
# Installs Storage Class and Traefik
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

# Remove previous setup
#kubectl delete -f .

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

kubectl delete secret traefik-external-provider -n kube-system
kubectl create secret generic traefik-external-provider -n kube-system --from-literal=key=dKD9mjoUALrT_7sHz1qAfFZe83Q5f2MbGsm --from-literal=secret=7sK1dHWLhoLexnfmzXJWcb

# Tiller role
kctl apply -f tiller.yaml
sleep 15s

sudo helm init --service-account tiller --tiller-image jessestuart/tiller
sleep 60s
# Patch Helm to land on an ARM node because of the used image
kubectl patch deployment tiller-deploy -n kube-system --patch '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/arch": "arm64"}}}}}'
sleep 5s

# Consul
sudo helm del --purge consul-traefik
sleep 15s
sudo helm install --name consul-traefik stable/consul --set ImageTag=1.4.4 --namespace kube-system
sleep 30s

# Traefik - Internal
#kctl apply -f traefik-internal.yaml
# kubectl apply -f traefik-internal.yaml --namespace="kube-system"

# Traefik - External
kctl delete configmap traefik-conf-external
sleep 15s

cat <<EOF | kubectl create -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: traefik-conf-external
  namespace: kube-system
data:
  traefik.toml: |
    defaultEntryPoints = ["http", "https"]
    sendAnonymousUsage = false
    debug = true
    logLevel = "ERROR"

    [entryPoints]
      [entryPoints.http]
      address = ":80"
        [entryPoints.http.redirect]
        entryPoint = "https"
      [entryPoints.https]
      address = ":443"
        [entryPoints.https.tls]
      compress = true

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
      storage = "traefik/acme/account"
      acmeLogging = true
      entryPoint = "https"
      onHostRule = true
      #caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"
      #[acme.httpChallenge]
        #entryPoint="http"
      [acme.dnsChallenge]
        delayBeforeCheck = 0
        resolvers = ["220.233.0.3", "220.233.0.4"]
        provider = "namecheap"
        [namecheap]
          NAMECHEAP_API_USER = "lukepa"
          NAMECHEAP_API_KEY = "87cf40f983264ae698c0499023d354c1"
      [[acme.domains]]
        main = "*.goldenpassport.net"
EOF
sleep 30s

kctl delete job traefik-kv-store
sleep 15s

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
        image: traefik:v1.7.9
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

kctl apply -f traefik-external.yaml
#kubectl apply -f traefik-external.yaml --namespace="kube-system"
