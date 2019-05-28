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

set -o xtrace

#
# Step 1 - Prepares system and installs: Docker, Kubernetes & Helm
#

sudo helm del --purge consul-traefik

kubectl drain rock1 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock1
kubectl drain rock2 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock2
kubectl drain rock2 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock2
kubectl drain rock3 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock3
kubectl drain rock4 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock4

sudo kubeadm reset -f

sleep 15s

#
# Step 2 - Prepare system and install: Docker, Kubernetes & Helm
#

# Update system
sudo apt update
sudo apt -y upgrade

# Reset ip tables
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X

# Disable swap
sudo swapoff -a 
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo systemctl disable armbian-zram-config.service

### Install packages to allow apt to use a repository over HTTPS
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

#
# Install Docker
#
sudo apt install -y docker.io
sudo apt-get install -y docker-compose 

## Set up the repository:

### Add Docker’s official GPG key
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

### Add Docker apt repository.
#sudo add-apt-repository \
   #"deb [arch=arm64] https://download.docker.com/linux/ubuntu \
   #$(lsb_release -cs) \
   #stable"

#apt-get update -y

## Install Docker CE
#sudo apt-get install -y docker-ce docker-compose 

# Setup daemon.
#cat > /etc/docker/daemon.json <<EOF
##{
  #"exec-opts": ["native.cgroupdriver=systemd"],
  #"log-driver": "json-file",
  #"log-opts": {
    #"max-size": "100m"
  #},
  #"storage-driver": "overlay2"
##}
#EOF

#mkdir -p /etc/systemd/system/docker.service.d

# Restart docker
sudo systemctl daemon-reload
sudo systemctl start docker
sudo systemctl enable docker
sudo systemctl restart docker

# Add user to docker group
sudo usermod -aG docker $USER
sudo usermod -aG docker rock

#
# Install Kubernetes
#

# Uninstall current packages
{ 
    sudo apt-get purge -y kubelet
    echo "Successfully removed kubelet"
} || { 
    echo "kubelet not installed."
}

{ 
    sudo apt-get purge -y kubeadm
    echo "Successfully removed kubeadm"
} || { 
    echo "kubeadm not installed."
}

{ 
    sudo apt-get purge -y kubectl
    echo "Successfully removed kubectl"
} || { 
    echo "kubectl not installed."
}

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

sudo cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

sudo apt-get install -y kubelet kubeadm kubectl
# apt-mark hold kubelet kubeadm kubectl

# Init Kubernetes
kubeadm config images pull
kubeadm init --pod-network-cidr=10.244.0.0/16

sleep 10s

#
# Post Install Setup
#

sudo sysctl net.bridge.bridge-nf-call-iptables=1

# Install helm
if ! [ -x "$(command -v helm)" ]; then
  # echo 'Error: helm is not installed. It is required to deploy the Consul cluster.' >&2
  # exit 1
  curl https://raw.githubusercontent.com/helm/helm/master/scripts/get > get_helm.sh
  chmod 700 get_helm.sh
  ./get_helm.sh
fi

sudo apt -y autoremove
sleep 5s

mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl taint nodes --all node-role.kubernetes.io/master-
sleep 5s

set +o xtrace
printf "\n\n#####################################"
printf "\n### Enter user (rock) secret      ###"
printf "\n#####################################\n\n"

printf "rock:`openssl passwd -apr1`\n" > ingress_auth.tmp
kubectl create secret generic ingress-auth --from-file=ingress_auth.tmp -n kube-system 
rm ingress_auth.tmp
set -o xtrace

#
# Step 3 - Install Flannel, MetalLB and (Kube) Dashboards
#

# Flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml
sleep 10s

# MetalLB
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
kubectl apply -f metallb.yaml

# Dashboard
kctl apply -f dashboard.yaml
# kubectl apply -f dashboard.yaml --namespace="kube-system"


#
# Step 4 - Install storageClass and Traefik
#

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
kubectl create secret generic traefik-external-provider -n kube-system --from-literal=key=dKD9mjoUALrT_7sHz1qAfFZe83Q5f2MbGsm --from-literal=secret=7sK1dHWLhoLexnfmzXJWcb

# Tiller role
kctl apply -f tiller.yaml
sleep 15s

sudo helm init --service-account tiller --tiller-image jessestuart/tiller
sleep 30s
# Patch Helm to land on an ARM node because of the used image
kubectl patch deployment tiller-deploy -n kube-system --patch '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/arch": "arm64"}}}}}'
sleep 15s

# Consul
{ 
    sudo helm del --purge consul-traefik
    echo "helm - consul-traefik deleted"
} || { 
    echo "helm - consul-traefik not found"
}
sleep 15s

sudo helm install --name consul-traefik stable/consul --set ImageTag=1.4.4 --namespace kube-system
sleep 30s

# Traefik - Internal
#kctl apply -f traefik-internal.yaml
# kubectl apply -f traefik-internal.yaml --namespace="kube-system"

# Traefik - External
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
sleep 5s

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

#
# Step 4 - Deploy NodeJs example app
#

#kubectl create namespace production
#kubectl create namespace staging
kubectl apply -f hello-world.yaml

#
# Step 5 - Final instructions
#

set +o xtrace
printf "\n\n#####################################"
printf "\n### Enter below as a regular user ###"
printf "\n#####################################\n"
printf '\nmkdir -p $HOME/.kube'
printf '\nsudo cp /etc/kubernetes/admin.conf $HOME/.kube/config'
printf '\nsudo chown $(id -u):$(id -g) $HOME/.kube/config\n\n'