# Source: https://gist.github.com/32a7096b96ff9a96d067753ddaa2409c

###########################################################################
# Kubernetes Networking, Security, And Observability With eBPF And Cilium #
# https://youtu.be/sfhRFtYbuyo                                            #
###########################################################################

# Additional Info:
# - Cilium: https://cilium.io
# - Is eBPF The End Of Kubernetes Sidecar Containers?: https://youtu.be/7ZVQSg9HX68
# - Kubernetes ChatGPT Bot: https://github.com/robusta-dev/kubernetes-chatgpt-bot

#######################
# Setup Cilium In GKE #
#######################

# This demo is using Google Cloud GKE.
# Cilium supports other Kubernetes distributions, but, if you
#   do choose to use something else, please follow the
#   instructions from https://docs.cilium.io/en/stable/gettingstarted/#installation
#   instead of those in this section of the Gist.
# If you're setting it up yourself, make sure to install both
#   Cilium and Hubble.

export USE_GKE_GCLOUD_AUTH_PLUGIN=True

export PROJECT_ID=dot-$(date +%Y%m%d%H%M%S)

gcloud projects create $PROJECT_ID

echo https://console.cloud.google.com/marketplace/product/google/container.googleapis.com?project=$PROJECT_ID

# Open the URL from the output and enable the Kubernetes API

gcloud container get-server-config --region us-east1

# Replace `[...]` with a valid master version from the previous output.
export K8S_VERSION=[...]

gcloud container clusters create dot --project $PROJECT_ID \
    --region us-east1 --machine-type n1-standard-4 \
    --num-nodes 1 --cluster-version $K8S_VERSION \
    --node-version $K8S_VERSION \
    --node-taints "node.cilium.io/agent-not-ready=true:NoExecute"

export KUBECONFIG=$PWD/kubeconfig.yaml

gcloud container clusters get-credentials dot \
    --project $PROJECT_ID --region us-east1

export NATIVE_CIDR=$(gcloud container clusters describe dot \
    --project $PROJECT_ID --region us-east1 \
    --format 'value(clusterIpv4Cidr)')

echo $NATIVE_CIDR

helm repo add cilium https://helm.cilium.io

helm repo update

helm upgrade --install cilium cilium/cilium --version 1.12.5 \
    --namespace kube-system --set nodeinit.enabled=true \
    --set nodeinit.reconfigureKubelet=true \
    --set nodeinit.removeCbrBridge=true \
    --set cni.binPath=/home/kubernetes/bin \
    --set gke.enabled=true --set ipam.mode=kubernetes \
    --set ipv4NativeRoutingCIDR=$NATIVE_CIDR \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true --wait

#########
# Setup #
#########

git clone https://github.com/vfarcic/cilium-demo

cd cilium-demo

# Install `cilium` CLI from https://github.com/cilium/cilium-cli

# Install `hubble` CLI from https://github.com/cilium/hubble

cilium status --wait

cilium connectivity test

cilium hubble port-forward&

kubectl create namespace production

helm repo add traefik https://helm.traefik.io/traefik

helm repo update

helm upgrade --install traefik traefik/traefik \
    --namespace traefik --create-namespace --wait

# If NOT EKS
export INGRESS_HOST=$(kubectl --namespace traefik \
    get svc traefik \
    --output jsonpath="{.status.loadBalancer.ingress[0].ip}")

# If EKS
export INGRESS_HOSTNAME=$(kubectl --namespace traefik \
    get svc traefik \
    --output jsonpath="{.status.loadBalancer.ingress[0].hostname}")

# If EKS
export INGRESS_HOST=$(dig +short $INGRESS_HOSTNAME)

echo $INGRESS_HOST

# Repeat the `export` command(s) if the output is empty.

# If the output contains more than one IP, wait for a while longer, and repeat the `export` commands.

# If the output continues having more than one IP, choose one of them and execute `export INGRESS_HOST=[...]` with `[...]` being the selected IP.

# Install `yq` from https://github.com/mikefarah/yq if you do not have it already
yq --inplace \
    ".spec.rules[0].host = \"silly-demo.$INGRESS_HOST.nip.io\"" \
    kustomize/base/ingress.yaml

######################################
# Observe Traffic With Cilium Hubble #
######################################

kubectl kustomize --enable-helm kustomize/base \
    | kubectl --namespace production apply --filename -

curl -X POST "silly-demo.$INGRESS_HOST.nip.io/video?id=wNBG1-PSYmE&title=Kubernetes%20Policies%20And%20Governance%20-%20Ask%20Me%20Anything%20With%20Jim%20Bugwadia"

curl -X POST "silly-demo.$INGRESS_HOST.nip.io/video?id=VlBiLFaSi7Y&title=Scaleway%20-%20Everything%20We%20Expect%20From%20A%20Cloud%20Computing%20Service%3F"

curl "silly-demo.$INGRESS_HOST.nip.io/videos" | jq .

hubble observe --namespace production

cilium hubble ui

# Press `ctrl+c`

################################################
# Enforce Network Ingress Policies With Cilium #
################################################

kubectl --namespace production get services,ingresses

kubectl --namespace production run not-silly-demo \
    --rm -ti --restart='Never' \
    --image docker.io/bitnami/postgresql \
    --env PGPASSWORD=postgres \
    --command -- sh

psql --host postgresql -U postgres -d postgres -p 5432

\l

CREATE DATABASE "not-silly-demo";

\l

exit

exit

cat kustomize/overlays/cilium-ingress/cnp-ingress.yaml

kubectl kustomize --enable-helm \
    kustomize/overlays/cilium-ingress \
    | kubectl --namespace production apply --filename -

kubectl --namespace production run not-silly-demo \
    --rm -ti --restart='Never' \
    --image docker.io/bitnami/postgresql \
    --env PGPASSWORD=postgres \
    --command -- sh

psql --host postgresql -U postgres -d postgres -p 5432

# Press `ctrl+c`

exit

curl "silly-demo.$INGRESS_HOST.nip.io/videos" | jq .

###############################################
# Enforce Network Egrees Policies With Cilium #
###############################################

curl "silly-demo.$INGRESS_HOST.nip.io/ping?url=http://devopstoolkitseries.com"

curl "silly-demo.$INGRESS_HOST.nip.io/ping?url=http://google.com"

cat kustomize/overlays/cilium-egrees/cnp-egrees.yaml

kubectl kustomize --enable-helm \
    kustomize/overlays/cilium-egrees \
    | kubectl --namespace production apply --filename -

curl "silly-demo.$INGRESS_HOST.nip.io/ping?url=http://devopstoolkitseries.com"

curl "silly-demo.$INGRESS_HOST.nip.io/ping?url=http://google.com"

# Press `ctrl+c`

curl "silly-demo.$INGRESS_HOST.nip.io/videos" | jq .

###########
# Destroy #
###########

gcloud projects delete $PROJECT_ID --quiet