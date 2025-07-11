# C# GameSever

### 구성

- Charts
    - Helm 차트
- Kind
    - 로컬 k8s 클러스터
- GrpcServer
- OpenMatch
- GameServer

### prerequisite

```shell
brew install kind
brew install dotnet-sdk
brew install go

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add open-match https://open-match.dev/chart/stable
helm repo add agones https://agones.dev/chart/stable
helm repo update
```

### Kind 클러스터

```shell
make kind-create
make kind-delete

make kind-restart
```

### 빌드

```shell
make pub-grpc-server STAGE=local

make pub-director STAGE=local
make pub-mmf STAGE=local
```

### 배포

```shell
make deploy-grpc-server STAGE=local

make deploy-open-match STAGE=local

make deploy-agones STAGE=local
```

### Port-fowarding

```shell
kubectl port-forward service/open-match-frontend -n open-match 50504:50504
```
