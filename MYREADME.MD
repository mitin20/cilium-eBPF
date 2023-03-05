# eBPF-based Networking, Observability, Security
git clone https://github.com/mitin20/cilium-eBPF.git

# init cluster
minikube start --network-plugin=cni --cni=false

# install cilium cli
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "arm64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-darwin-${CLI_ARCH}.tar.gz{,.sha256sum}
shasum -a 256 -c cilium-darwin-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-darwin-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-darwin-${CLI_ARCH}.tar.gz{,.sha256sum}

# install cilium in cluster
cilium install

or

helm upgrade cilium cilium/cilium --version 1.13.0 \
   --namespace kube-system \
   --reuse-values \
   --set hubble.relay.enabled=true \
   --set hubble.ui.enabled=true

# validate installation
cilium status --wait

# Enable Hubble in Cilium
cilium hubble enable

# Install the Hubble Client
export HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "arm64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-darwin-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
shasum -a 256 -c hubble-darwin-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-darwin-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-darwin-${HUBBLE_ARCH}.tar.gz{,.sha256sum}

# Validate Hubble API Access
cilium hubble port-forward&
hubble status
hubble observe



# demo
git clone https://github.com/vfarcic/cilium-demo

cd cilium-demo
cilium status --wait
cilium connectivity test
cilium hubble port-forward&
kubectl create namespace production
helm repo add traefik https://helm.traefik.io/traefik
helm upgrade --install traefik traefik/traefik \
    --namespace traefik --create-namespace --wait

export INGRESS_HOST=$(kubectl --namespace traefik \
    get svc traefik \
    --output jsonpath="{.status.loadBalancer.ingress[0].ip}")

echo $INGRESS_HOST

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

```kustomize/overlays/cilium-ingress/cnp-ingress.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: silly-demo-ingress
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: postgresql
  ingress:
  - fromEndpoints:
    - matchLabels:
        app.kubernetes.io/name: silly-demo
    toPorts:
    - ports:
      - port: "5432"
        protocol: TCP
```

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

```kustomize/overlays/cilium-egrees/cnp-egrees.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: silly-demo-egrees
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: silly-demo
  egress:
    - toFQDNs:
      - matchName: "devopstoolkitseries.com"
      - matchPattern: "*.devopstoolkitseries.com"
    - toEndpoints:
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": production
    - toEndpoints:
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": kube-system
          "k8s:k8s-app": kube-dns
      toPorts:
      - ports:
        - port: "53"
          protocol: ANY
        rules:
          dns:
            - matchPattern: "*"
```

kubectl kustomize --enable-helm \
    kustomize/overlays/cilium-egrees \
    | kubectl --namespace production apply --filename -

curl "silly-demo.$INGRESS_HOST.nip.io/ping?url=http://devopstoolkitseries.com"

curl "silly-demo.$INGRESS_HOST.nip.io/ping?url=http://google.com"

# Press `ctrl+c`

curl "silly-demo.$INGRESS_HOST.nip.io/videos" | jq .