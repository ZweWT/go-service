SHELL := /bin/bash

run: 
	go run main.go

tidy: 
	go mod tidy
	go mod vendor
	
# =============================================================================================
# Building containers

VERSION := 1.0

all: service

service: 
	docker build \
		-f zarf/docker/dockerfile \
		-t service-amd64:$(VERSION) \
		--build-arg BUILD_REF=$(VERSION) \
		--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		.

# =============================================================================================
# Running from within k8s/kind

KIND_CLUSTER := starter-cluster

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
	kustomize build zarf/k8s/kind/service-pod | kubectl apply -f -

kind-logs: 
	kubectl logs -l app=service --all-containers=true -f --tail=100

kind-restart: 
	kubectl rollout restart deployment service-pod

kind-update-apply: all kind-load kind-apply

kind-update: all kind-load kind-restart

kind-describe: 
	kubectl describe pod -l app=service