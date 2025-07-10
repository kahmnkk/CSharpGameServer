#!/bin/sh
set -o errexit

# https://hub.docker.com/r/kindest/node/tags
KIND_NODE_VERSION=kindest/node:v1.30.13@sha256:397209b3d947d154f6641f2d0ce8d473732bd91c87d9575ade99049aa33cd648

# create registry container unless it already exists
reg_name='kind-registry'
reg_port='5001'
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --name "${reg_name}" \
    registry:2
fi

cluster_name=$1
# create a cluster with the local registry enabled in containerd
cat <<EOF | kind create cluster --name ${cluster_name} --config=-
# cluster-config.win.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5001"]
    endpoint = ["http://kind-registry:5000"]
nodes:
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
    - |
      kind: ClusterConfiguration
      apiServer:
        extraArgs:
          feature-gates: "InPlacePodVerticalScaling=true"
      controllerManager:
        extraArgs:
          feature-gates: "InPlacePodVerticalScaling=true"
      scheduler:
        extraArgs:
          feature-gates: "InPlacePodVerticalScaling=true"
    image: ${KIND_NODE_VERSION}
    extraPortMappings:
      - containerPort: 30081 # GrpcServer
        hostPort: 8081
        listenAddress: "0.0.0.0"
        protocol: tcp
      - containerPort: 30306 # MySQL
        hostPort: 3306
        listenAddress: "0.0.0.0"
        protocol: tcp
      - containerPort: 30379 # Redis
        hostPort: 6379
        listenAddress: "0.0.0.0"
        protocol: tcp
      - containerPort: 30090 # Prometheus
        hostPort: 9090
        listenAddress: "0.0.0.0"
        protocol: tcp
      - containerPort: 30000 # Grafana
        hostPort: 3000
        listenAddress: "0.0.0.0"
        protocol: tcp
      - containerPort: 31901 # ArgoCD
        hostPort: 9001
        listenAddress: "0.0.0.0"
        protocol: tcp
  - role: worker
    image: ${KIND_NODE_VERSION}
  - role: worker
    image: ${KIND_NODE_VERSION}
  - role: worker
    image: ${KIND_NODE_VERSION}
EOF

# connect the registry to the cluster network if not already connected
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi

# Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
