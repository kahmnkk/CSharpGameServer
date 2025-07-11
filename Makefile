STAGE ?= local

DOCKER_BUILD_FLAG ?= build
REGISTRY ?= localhost:5001

CLUSTER_NAME ?= my-cluster
CONTEXT = kind-$(CLUSTER_NAME)

TAG = $(SHORT_SHA)
SHORT_SHA = $(shell git rev-parse --short=7 HEAD | tr -d [:punct:])

###############################
### Docker Build
###############################

.PHONY: build-grpc-server push-grpc-server pub-grpc-server
build-grpc-server:
	DOCKER_BUILDKIT=1 docker $(DOCKER_BUILD_FLAG) \
		-f ./GrpcServer/Dockerfile \
		-t $(REGISTRY)/grpc-server:latest \
		-t $(REGISTRY)/grpc-server:$(TAG) \
		./GrpcServer
push-grpc-server:
	docker push $(REGISTRY)/grpc-server:latest
	docker push $(REGISTRY)/grpc-server:$(TAG)
pub-grpc-server: build-grpc-server push-grpc-server

.PHONY: build-director push-director
build-director:
	DOCKER_BUILDKIT=1 docker $(DOCKER_BUILD_FLAG) \
		-f ./OpenMatch/director/Dockerfile \
		-t $(REGISTRY)/openmatch-director:latest \
		./OpenMatch/director
push-director:
	docker push $(REGISTRY)/openmatch-director:latest
pub-director: build-director push-director

.PHONY: build-mmf push-mmf
build-mmf:
	DOCKER_BUILDKIT=1 docker $(DOCKER_BUILD_FLAG) \
		-f ./OpenMatch/matchfunction/Dockerfile \
		-t $(REGISTRY)/openmatch-mmf:latest \
		./OpenMatch/matchfunction
push-mmf:
	docker push $(REGISTRY)/openmatch-mmf:latest
pub-mmf: build-mmf push-mmf

###############################
### Helm Deploy
###############################

.PHONY: deploy-grpc-server
echo-deploy-grpc-server:
	@echo "    helm upgrade --install grpc-server Charts/grpc-server \\"
	@echo "        -f Charts/grpc-server/values.$(STAGE).yaml \\"
	@echo "        -n default --create-namespace \\"
	@echo "        --kube-context $(CONTEXT)"
run-deploy-grpc-server:
	helm upgrade --install grpc-server Charts/grpc-server \
		-f Charts/grpc-server/values.$(STAGE).yaml \
		-n default --create-namespace \
		--kube-context $(CONTEXT)
deploy-grpc-server: echo-deploy-grpc-server confirm run-deploy-grpc-server

.PHONY: remove-grpc-server
echo-remove-grpc-server:
	@echo "    helm uninstall grpc-server -n default \\"
	@echo "        --kube-context $(CONTEXT)"
run-remove-grpc-server:
	helm uninstall grpc-server -n default \
		--kube-context $(CONTEXT)
remove-grpc-server: echo-remove-grpc-server confirm run-remove-grpc-server

.PHONY: deploy-agones
echo-deploy-agones:
	@echo "    helm upgrade --install agones agones/agones \\"
	@echo "        -f Charts/agones/values.$(STAGE).yaml \\"
	@echo "        -n agones --create-namespace \\"
	@echo "        --kube-context $(CONTEXT)"
run-deploy-agones:
	helm upgrade --install agones agones/agones \
		-f Charts/agones/values.$(STAGE).yaml \
		-n agones --create-namespace \
		--kube-context $(CONTEXT)
deploy-agones: echo-deploy-agones confirm run-deploy-agones

.PHONY: remove-agones
echo-remove-agones:
	@echo "    helm uninstall agones -n agones \\"
	@echo "        --kube-context $(CONTEXT)"
run-remove-agones:
	helm uninstall agones -n agones \
		--kube-context $(CONTEXT)
remove-agones: echo-remove-agones confirm run-remove-agones

.PHONY: deploy-open-match
echo-deploy-open-match:
	@echo "    helm upgrade --install open-match open-match/open-match \\"
	@echo "        -f Charts/open-match/values.$(STAGE).yaml \\"
	@echo "        -n open-match --create-namespace \\"
	@echo "        --kube-context $(CONTEXT)"
run-deploy-open-match:
	helm upgrade --install open-match open-match/open-match \
		-f Charts/open-match/values.$(STAGE).yaml \
		-n open-match --create-namespace \
		--kube-context $(CONTEXT)
deploy-open-match: echo-deploy-open-match confirm run-deploy-open-match

.PHONY: remove-open-match
echo-remove-open-match:
	@echo "    helm uninstall open-match -n open-match \\"
	@echo "        --kube-context $(CONTEXT)"
run-remove-open-match:
	helm uninstall open-match -n open-match \
		--kube-context $(CONTEXT)
remove-open-match: echo-remove-open-match confirm run-remove-open-match

###############################
### Kind Cluster
###############################

.PHONY: kind-create
echo-kind-create:
	@echo "    if [ ! -x ./Kind/kind.with.registry\.sh ]; then chmod +x ./Kind/kind.with.registry\.sh; fi "
	@echo "        ./Kind/kind.with.registry\.sh $(CLUSTER_NAME)"
	@echo "    "
	@echo "    helm upgrade --install metrics-server metrics-server/metrics-server \\"
	@echo "        -f Charts/metrics-server/values.$(STAGE).yaml \\"
	@echo "        -n kube-system \\"
	@echo "        --kube-context $(CONTEXT)"
run-kind-create:
	if [ ! -x ./Kind/kind.with.registry\.sh ]; then chmod +x ./Kind/kind.with.registry\.sh; fi
		./Kind/kind.with.registry\.sh $(CLUSTER_NAME)

	helm upgrade --install metrics-server metrics-server/metrics-server \
		-f Charts/metrics-server/values.$(STAGE).yaml \
		-n kube-system \
		--kube-context $(CONTEXT)
kind-create: echo-kind-create confirm run-kind-create

.PHONY: kind-delete
echo-kind-delete:
	@echo "    kind delete clusters $(CLUSTER_NAME)"
run-kind-delete:
	kind delete clusters $(CLUSTER_NAME)
kind-delete: echo-kind-delete confirm run-kind-delete

.PHONY: kind-restart
kind-restart: run-kind-delete run-kind-create

###############################
### Utils
###############################
SHELL := /bin/bash
confirm:
	@if [[ -z "$(CI)" ]]; then \
	  read -p "⚠ Are you sure ❓ [Y/n] > " -r && [[ $$REPLY =~ ^[Y]$$ ]] || { echo "Stopping"; exit 1; }; \
	fi
