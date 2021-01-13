.DEFAULT_GOAL := help
SHELL:=/bin/bash
.PHONY: help

# import config
# configfile=.env
# include $(configfile)
# export $(shell sed 's/=.*//' $(configfile))


#--- commands and variables ---

# generate other variables. Keep in mind that here are variables, inside the targets the variable names become commands
#HOST_JENKINS_UID ?= $(shell id -u jenkins)
#HOST_JENKINS_GID ?= $(shell id -g jenkins)

# Used in order to have Makefile working locally, emulating Jenkins behavior
# REPO_NAME ?= $(shell basename `pwd`)
# BRANCH_NAME ?= $(shell git branch 2>/dev/null | grep '^*' | colrm 1 2)
#env.REPO_REV_HASH ?= $(shell git rev-parse --short HEAD)
#env.DOCKER_TAG = BUILD_TAG.toLowerCase().replaceAll(/-|_|%/, "")

CLUSTER_NAME ?= kinder
CONTEXT      = kind-${CLUSTER_NAME}
CERTIFICATE  = $(shell kubectl config view --raw -o json | jq -r '.users[] | select(.name == "'${CONTEXT}'") | .user."client-certificate-data"') 
KEY          = $(shell kubectl config view --raw -o json | jq -r '.users[] | select(.name == "'${CONTEXT}'") | .user."client-key-data"') 
CLUSTER_CA   = $(shell kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'${CONTEXT}'") | .cluster."certificate-authority-data"') 

TOKEN=$(shell kubectl get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='default')].data.token}" | base64 --decode)

INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
SECURE_INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
TCP_INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="tcp")].nodePort}')
INGRESS_HOST=$(shell kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')

#--- functions ---


#--- targets ---

all: help

help:  ## Display this help
	@echo '====================='
	@echo 'PREREQUISITES:       '
	@echo '- docker             '
	@echo '- kind               '
	@echo '- helm (v3)          '
	@echo '- istioctl           '
	@echo '====================='
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

install-single-node: kinder-create-single-node                 install-metrics-server install-istio map-ingressgateway-nodeports install-dashboards-all install-nginx-1 ## Install a single-node cluster      [OK]

install-multi-nodes: kinder-create-multi-nodes install-calico install-metrics-server install-istio map-ingressgateway-nodeports install-dashboards-all install-nginx-1 ## Install a multi-node cluster       [?]

install-eks-d:       kinder-create-eks-d       install-calico install-metrics-server install-istio map-ingressgateway-nodeports install-dashboards-all install-nginx-1 ## Install a multi-node EKS-D cluster [OK]

kinder-create-single-node: ## Create single node cluster
	kind create cluster --config=kinder-single-node.yaml --name ${CLUSTER_NAME}
	# Set CoreDNS to just 1 replicas
	kubectl scale deployment --replicas 1 coredns --namespace kube-system

kinder-create-multi-nodes: ## Create multi nodes cluster
	kind create cluster --config=kinder-multi-nodes.yaml --name ${CLUSTER_NAME}

kinder-create-eks-d: ## Create multi nodes cluster based on AWS EKS-D distribution
	kind create cluster --config=kinder-eks-d.yaml --name ${CLUSTER_NAME}

install-calico: ## Install CNI calico
	curl -sSLk https://docs.projectcalico.org/manifests/calico.yaml | kubectl apply -f -

install-metrics-server: ## Install metrics-server
	# Add metrics-server helm repository
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo update
	# Deploy a Helm Release named "metrics-server" using the bitnami/metrics-server chart
	helm upgrade \
    metrics-server \
    --namespace kube-system \
    --install \
		--set "extraArgs.kubelet-preferred-address-types=InternalIP" \
		--set "extraArgs.kubelet-insecure-tls=true" \
		--set "apiService.create=true" \
		bitnami/metrics-server
# --set "args={--kubelet-insecure-tls, --kubelet-preferred-address-types=InternalIP}"

install-dashboards-all: install-kubernetes-dashboard install-weave-scope ## Install kubernetes-dashboard and weave-scope

install-kubernetes-dashboard: ## Install kubernetes-dashboard
	# Add kubernetes-dashboard helm repository
	helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
	helm repo update
	# Deploy a Helm Release named "kubernetes-dashboard" using the kubernetes-dashboard chart
	helm upgrade \
    kubernetes-dashboard \
    --namespace kube-system \
    --install \
		kubernetes-dashboard/kubernetes-dashboard
	@echo '${TOKEN}'
	# To proxy all of the kubernetes APIs: $ kubectl proxy
	# Then, click on: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/login

install-weave-scope: ## Install weave-scope
	kubectl apply -f "https://cloud.weave.works/k8s/scope.yaml?k8s-version=$(shell kubectl version | base64 | tr -d '\n')"
#kubectl rollout status deployment weave-scope-app --namespace weave -w
# To proxy the weave-scope dashboard: $ kubectl port-forward service/weave-scope-app -n weave 9999:\$(kubectl get services weave-scope-app --namespace weave -o jsonpath="{.spec.ports[0].port}")
# Then, click on: http://localhost:9999

map-ingressgateway-nodeports:
	kubectl patch svc istio-ingressgateway -n istio-system --patch '$(shell cat istio-svc-patch-file.json)'
	# kubectl get svc istio-ingressgateway -n istio-system -o json

install-istio-all: install-istio install-kiali install-prometheus-operator install-grafana ## Install istio with kiali, prometheus-operator, grafana

install-istio: ## Install istio
#By default, there is no way Kubernetes can assign external IP to LoadBalancer service.
#This service type needs infrastructure support which works in cloud offerings like GKE, AKS, EKS etc.
	istioctl install --set profile=demo --skip-confirmation

install-kiali: ## Install kiali
	helm install \
    --namespace istio-system \
    --set auth.strategy="anonymous" \
    --repo https://kiali.org/helm-charts \
    kiali-server \
    kiali-server
	@echo '"istioctl dashboard kiali" to connect to kiali dashboard'

install-prometheus-operator: ## Install prometheus-operator
	@echo 'ref: https://operatorhub.io/operator/prometheus'
	# Install Operator Lifecycle Manager (OLM), a tool to help manage the Operators running on your cluster.
	curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/0.16.1/install.sh | bash -s 0.16.1
	# Install the operator by running the following command:
	kubectl create -f https://operatorhub.io/install/prometheus.yaml

install-grafana:
	@echo 'TBD'

install-nginx-1: ## Install nginx-1
	kubectl apply -f ./nginx-test/nginx-1.yaml
	# To test it (mode #1):
	# - $ kubectl port-forward svc/istio-ingressgateway 8080:80 -n istio-system
	# - $ curl -H'Host:nginx-1.127.0.0.1.nip.io' localhost:8080
  #
	# To test it (mode #2):
	# - $ kubectl run -it --rm --restart=Never --image=infoblox/dnstools:latest dnstools -n kube-system
	# - dnstools# curl nginx-1.nginx-test.svc.cluster.local
	# - nginx-1
	# - dnstools# curl istio-ingressgateway.istio-system.svc.cluster.local
	# - nginx-1
	#
	# To test it (mode #3, if you installed istio and map-ingressgateway-nodeports):
	# - $ curl -H'Host:nginx-1.127.0.0.1.nip.io' localhost
	#
	# Other useful info:
	# export INGRESS_PORT=${INGRESS_PORT}
	# export SECURE_INGRESS_PORT=${SECURE_INGRESS_PORT}
	# export TCP_INGRESS_PORT=${TCP_INGRESS_PORT}
	# export INGRESS_HOST=${INGRESS_HOST}

certs: ## Show cluster certificates
	@echo 'Cluster: ${CLUSTER_NAME}'
	@echo 'Context: ${CONTEXT}'
	@echo ''
	@echo 'Certificate:'
	@echo ${CERTIFICATE} | base64 --decode
#@echo ${CERTIFICATE} | base64 -d > client.crt
	@echo ''
	@echo 'Private Key:'
	@echo ${KEY} | base64 --decode
#@echo ${KEY} | base64 --decode > client.key 
#@openssl pkcs12 -export -in client.crt -inkey client.key -out client.pfx -passout pass: rm client.crt rm client.key
	@echo ''
	@echo 'Cluster Certificate Authority:'
	@echo ${CLUSTER_CA} | base64 --decode
#@echo ${CLUSTER_CA} | base64 -d > cluster.crt 

delete-all: ## Delete kinder
	kind delete cluster --name ${CLUSTER_NAME}