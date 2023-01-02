SHELL := /bin/bash

run: 
	go run main.go

# =============================================================================================
# Building containers

VERSION := 1.0

all: build

build: 
	docker build \
		-f zarf/docker/dockerfile \
		-t service-amd64:$(VERSION) \
		--build-arg BUILD_REF=$(VERSION) \
		--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		.

# =============================================================================================
# Running from within k8s/kind

KIND_CLUSTER := starter-cluster

#upgrade to latest Kind
#Kind release used in our project: https://github.com/kubernetes-sigs/kind/releases/tag/
#image used below was copied by the above link and supports both amd64 and arm64

kind-up: 
	kind create cluster \
		--image kindest/node:v1.26.0@sha256:45aa9ecb5f3800932e9e35e9a45c61324d656cf5bc5dd0d6adfc1b0f8168ec5f \
		--name $(KIND_CLUSTER) \
		--config zarf/k8s/kind/kind-config.yaml 
	
	kubectl config set-context --current --namespace=service-system

kind-down:
	kind delete cluster --name $(KIND_CLUSTER)

kind-status:
	kubectl get nodes -o wide 
	kubectl get svc -o wide
	kubectl get pods -o wide --watch --all-namespaces

kind-load: 
	kind load docker-image service-amd64:$(VERSION) --name $(KIND_CLUSTER)

kind-apply: 
	cat zarf/k8s/base/service-pod/base-service.yaml | kubectl apply -f -

kind-logs: 
	kubectl logs -l app=service --all-containers=true -f --tail=100

kind-restart: 
	kubectl rollout restart deployment service-pod

kind-update: all kind-load kind-restart

kind-describe: kubectl describe pod -l app=service