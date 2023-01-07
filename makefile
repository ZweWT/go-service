SHELL := /bin/bash

# =============================================================================================
# cmdline dashboard for analytics and profiling
# go install github.com/divan/expvarmon@latest
# expvarmon -ports=":4000" -vars="build, requests, goroutines, errors, panics, mem:memstats.Alloc"

run: 
	go run app/services/sales-api/main.go | go run app/services/tooling/logfmt/main.go

tidy: 
	go mod tidy
	go mod vendor

# =============================================================================================
# Building containers

VERSION := 1.0

all: sales-api

sales-api: 
	docker build \
		-f zarf/docker/dockerfile.sales-api \
		-t sales-api-amd64:$(VERSION) \
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
	kubectl config set-context --current --namespace=sales-system 

kind-down:
	kind delete cluster --name $(KIND_CLUSTER)

kind-status:
	kubectl get nodes -o wide 
	kubectl get svc -o wide
	kubectl get pods -o wide --watch --all-namespaces

kind-load: 
	cd zarf/k8s/kind/sales-pod; kustomize edit set image sales-api-image=sales-api-amd64:$(VERSION)
	kind load docker-image sales-api-amd64:$(VERSION) --name $(KIND_CLUSTER)

kind-apply: 
	kustomize build zarf/k8s/kind/sales-pod | kubectl apply -f -

kind-logs: 
	kubectl logs -l app=sales --all-containers=true -f --tail=100 | go run app/services/tooling/logfmt/main.go

kind-restart: 
	kubectl rollout restart deployment sales-pod

kind-update-apply: all kind-load kind-apply

kind-update: all kind-load kind-restart

kind-describe: 
	kubectl describe pod -l app=sales