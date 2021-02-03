.DEFAULT_GOAL := help
SHELL:=/bin/bash
.PHONY: help

# import config
# configfile=.env
# include $(configfile)
# export $(shell sed 's/=.*//' $(configfile))


#--- commands and variables ---

# Generate other variables. Keep in mind that here are variables, inside the targets the variable names become commands
#HOST_JENKINS_UID ?= $(shell id -u jenkins)
#HOST_JENKINS_GID ?= $(shell id -g jenkins)

# Used in order to have Makefile working locally, emulating Jenkins behavior
#REPO_NAME ?= $(shell basename `pwd`)
#BRANCH_NAME ?= $(shell git branch 2>/dev/null | grep '^*' | colrm 1 2)
#env.REPO_REV_HASH ?= $(shell git rev-parse --short HEAD)
#env.DOCKER_TAG = BUILD_TAG.toLowerCase().replaceAll(/-|_|%/, "")

CLUSTER_NAME ?= kinder
CONTEXT      = kind-${CLUSTER_NAME}
CERTIFICATE  = $(shell kubectl config view --raw -o json | jq -r '.users[] | select(.name == "'${CONTEXT}'") | .user."client-certificate-data"') 
# alternative:         kubectl config view --minify --raw --output 'jsonpath={..cluster.certificate-authority-data}'
KEY          = $(shell kubectl config view --raw -o json | jq -r '.users[] | select(.name == "'${CONTEXT}'") | .user."client-key-data"') 
CLUSTER_CA   = $(shell kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'${CONTEXT}'") | .cluster."certificate-authority-data"') 

#TOKEN=$(shell kubectl get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='default')].data.token}" | base64 --decode)

INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
SECURE_INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
TCP_INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="tcp")].nodePort}')
INGRESS_HOST=$(shell kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')


#--- versions variables ---
#RELEASES: https://github.com/rancher/fleet/releases/
FLEET_VERSION = 0.3.3

#RELEASE: https://github.com/kyverno/kyverno/releases


#--- functions ---


#--- targets ---

all: help

help:  ## Display this help
	@echo 'The current script is tested for the following tools:                '
	@echo ''
	@echo '| tool        | version tested                                          |'
	@echo '| ----------- | ------------------------------------------------------- |'
	@echo '| - docker    | tested: 20.10.2 (Docker Engine - Community)             |'
	@echo '| - kind      | tested: kind v0.9.0 go1.15.2 darwin/amd64               |'
	@echo '| - helm (v3) | tested: v3.4.2                                          |'
	@echo '| - istioctl  | tested: v1.8.1                                          |'
	@echo ''
	@echo 'The current script installs the following components.                '
	@echo 'Components installed with "latest" can be potentially broken :)      '
	@echo ''
	@echo '| component               | app version                 | chart version |'
	@echo '| ----------------------- | --------------------------- | ------------- |'
	@echo '| - EKS-D distribution    | kind-eks-d:v1.18.9-kbst.1   | -             |'
	@echo '| - calico                | latest                      | -             |'
	@echo '| - fleet                 | 0.3.3                       | 0.3.3         |'
	@echo '| - grafana               | (via prometheus-operator)   | -             |'
	@echo '| - kiali                 | 1.28.1                      | 1.28.1        |'
	@echo '| - kyverno               | v1.3.1                      | 1.3.1         |'
	@echo '| - kubernetes-dashboards | 2.1.0                       | 4.0.0         |'
	@echo '| - istio                 | latest                      | -             |'
	@echo '| - metrics-server        | 0.4.1                       | 5.3.4         |'
	@echo '| - prometheus-operator   | 0.16.1                      | 0.16.1        |'
	@echo '| - weave-scope           | latest                      | -             |'
	@echo ''
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

install-single-node: create-cluster-single-node                install-metrics-server install-istio map-ingressgateway-nodeports install-dashboards-all install-nginx-1 ## Install a single-node cluster

install-multi-nodes: create-cluster-multi-nodes install-calico install-metrics-server install-istio map-ingressgateway-nodeports install-dashboards-all install-nginx-1 ## Install a multi-node cluster

install-eks-d:       create-cluster-eks-d       install-calico install-metrics-server install-istio map-ingressgateway-nodeports install-dashboards-all install-nginx-1 ## Install a multi-node EKS-D cluster

create-cluster-single-node: ## Create single node cluster
	kind create cluster --config=cluster-single-node.yaml --name ${CLUSTER_NAME}
	# Set CoreDNS to just 1 replicas
	kubectl scale deployment --replicas 1 coredns --namespace kube-system

create-cluster-multi-nodes: ## Create multi nodes cluster
	kind create cluster --config=cluster-multi-nodes.yaml --name ${CLUSTER_NAME}

create-cluster-eks-d: ## Create multi nodes cluster based on AWS EKS-D distribution
	kind create cluster --config=cluster-eks-d.yaml --name ${CLUSTER_NAME}

install-calico: ## Install CNI calico
#ref: https://docs.projectcalico.org/getting-started/kubernetes/self-managed-onprem/onpremises
	curl -sSLk https://docs.projectcalico.org/manifests/calico.yaml | kubectl apply -f -

install-metrics-server: ## Install metrics-server
	# Deploy a Helm Release named "metrics-server" using the bitnami/metrics-server chart
	helm upgrade \
    metrics-server \
    --namespace kube-system \
    --install \
    --set "extraArgs.kubelet-preferred-address-types=InternalIP" \
    --set "extraArgs.kubelet-insecure-tls=true" \
    --set "apiService.create=true" \
    --version 5.3.4 \
    --repo https://charts.bitnami.com/bitnami \
    metrics-server

install-dashboards-all: install-kubernetes-dashboard install-weave-scope ## Install kubernetes-dashboard and weave-scope

install-kubernetes-dashboard: ## Install kubernetes-dashboard
#ref: https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/README.md#login-view
#ref: https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/README.md#basic
#ref: https://stackoverflow.com/questions/48316330/how-to-set-multiple-values-with-helm
#--auto-generate-certificates="true"\,--authentication-mode=basic\,
	# Deploy a Helm Release named "kubernetes-dashboard" using the kubernetes-dashboard chart
	helm upgrade \
    kubernetes-dashboard \
    --namespace kube-system \
    --install \
    --set extraArgs={--enable-skip-login\,--enable-insecure-login\,--system-banner="WARNING: the dashboard is open to anonymous users and with cluster-admin permissions"} \
    --version 4.0.0 \
    --repo https://kubernetes.github.io/dashboard \
    kubernetes-dashboard
	# Bind namespace:serviceaccount "kube-system:kubernetes-dashboard" to clusterrole "cluster-admin" to enable dashboard collect info cluster wide 
	# create allow "system:anonymous" access to dashboard
	kubectl apply -f kubernetes-dashboard.yaml
	@echo 'Click on the following link:'
	kubectl cluster-info | grep kubernetes-dashboard
	# To enable users, create certificate to be imported in your browser to access kubernetes-dashboard
	# $ make certs-creation-browser"
	# Another option is to proxy all of the kubernetes APIs via HTTP (not HTTPS!):
	# $ kubectl proxy
	# i.e.: http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy

install-weave-scope: ## Install weave-scope
	kubectl apply -f "https://cloud.weave.works/k8s/scope.yaml?k8s-version=$(shell kubectl version | base64 | tr -d '\n')"
#kubectl rollout status deployment weave-scope-app --namespace weave -w
# To proxy the weave-scope dashboard: $ kubectl port-forward service/weave-scope-app -n weave 9999:\$(kubectl get services weave-scope-app --namespace weave -o jsonpath="{.spec.ports[0].port}")
# Then, click on: http://localhost:9999

install-istio-all: install-istio map-ingressgateway-nodeports install-prometheus install-kiali install-grafana configure-istio-urls ## Install istio with kiali, prometheus-operator, grafana

map-ingressgateway-nodeports: ## Map ingressgateway nodeports to the localhost ports to fake a loadbalancer
#Since the Kubernetes cluster runs in containers, we map istio-ingressgateway ports with localhost ports to make them reachable
	kubectl patch svc istio-ingressgateway -n istio-system --patch '$(shell cat istio-svc-patch-file.json)'

install-istio: ## Install istio and default gateway
#By default, there is no way Kubernetes can assign external IP to LoadBalancer service.
#This service type needs infrastructure support which works in cloud offerings like GKE, AKS, EKS etc.
	istioctl install --set profile=demo --skip-confirmation
	istioctl version
	kubectl apply -f istio-gateway.yaml

# install-prometheus-operator: ## Install prometheus-operator [WIP]
# 	@echo 'ref: https://operatorhub.io/operator/prometheus'
# 	# Install Operator Lifecycle Manager (OLM), a tool to help manage the Operators running on your cluster.
# 	curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.17.0/install.sh | bash -s v0.17.0
# 	# Install the operator by running the following command:
# 	kubectl create -f https://operatorhub.io/install/prometheus.yaml || true

install-prometheus: ## Install prometheus [WIP]
#ref: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
	helm upgrade \
    --namespace istio-system \
    --install \
    --repo https://prometheus-community.github.io/helm-charts \
    kube-prometheus-stack \
    kube-prometheus-stack

# install-kiali-operator: ## Install kiali-operator [WIP]
# #ref: https://github.com/kiali/kiali-operator/blob/master/deploy/kiali/kiali_cr.yaml
# #ref: https://kiali.org/helm-charts/index.yaml
# 	# To install the latest Kiali Operator along with a Kiali CR 
# 	# (which triggers a Kiali Server to be installed in istio-system namespace) using the Helm Chart,
# 	# you can run this:
# 	helm upgrade \
#     --namespace kiali-operator \
#     --create-namespace \
#     --install \
#     --set cr.create=true \
#     --set cr.namespace=istio-system \
#     --repo https://kiali.org/helm-charts \
#     kiali-operator \
#     kiali-operator
# 	kubectl apply -f kiali.yaml
# 	kubectl get kialis.kiali.io kiali -o jsonpath='{.status}' | jq -r

install-kiali: ## Install kiali
#ref: https://github.com/kiali/helm-charts/blob/master/kiali-operator/values.yaml
#ref: https://raw.githubusercontent.com/istio/istio/release-1.7/samples/addons/kiali.yaml
	helm upgrade \
    --namespace istio-system \
    --install \
    --set auth.strategy="anonymous" \
    --set istio_component_namespaces.prometheus="istio-system" \
    --set istio_namespace="istio-system" \
    --set deployment.accessible_namespaces[0]=** \
    --set external_services.prometheus.url="http://kube-prometheus-stack-prometheus.istio-system.svc.cluster.local:9090" \
    --set external_services.grafana.enabled=true \
    --set external_services.grafana.url="http://kube-prometheus-stack-grafana.istio-system.svc.cluster.local:80" \
    --set external_services.grafana.in_cluster_url="http://kube-prometheus-stack-grafana.istio-system.svc.cluster.local:80" \
    --set external_services.tracing.enabled=false \
    --set external_services.istio.istio_identity_domain=svc.cluster.local \
    --set external_services.istio.istio_sidecar_annotation=sidecar.istio.io/status \
    --set external_services.istio.istio_status_enabled=true \
    --set external_services.istio.url_service_version=http://istiod:15014/version \
    --version 1.28.1 \
    --repo https://kiali.org/helm-charts \
    kiali-server \
    kiali-server
	helm get values kiali-server -n istio-system
	@echo '"istioctl dashboard kiali" to connect to kiali dashboard'

install-grafana:
	@echo 'Grafana is installed via prometheus-operator'

configure-istio-urls: ## Configure Istio URLs
	kubectl apply -f istio-kiali-virtualservice.yaml
	@echo 'Click on http://kiali.127.0.0.1.nip.io to connect to kiali dashboard'
	kubectl apply -f istio-prometheus-virtualservice.yaml
	@echo 'Click on http://prometheus.127.0.0.1.nip.io to connect to prometheus dashboard'
	kubectl apply -f istio-grafana-virtualservice.yaml
	@echo 'Click on http://grafana.127.0.0.1.nip.io to connect to grafana dashboard'
	kubectl apply -f istio-alertmanager-virtualservice.yaml
	@echo 'Click on http://alertmanager.127.0.0.1.nip.io to connect to alertmanager dashboard'
	kubectl apply -f istio-kubernetes-dashboard-virtualservice.yaml
	@echo 'Click on http://kubernetes-dashboard.127.0.0.1.nip.io to connect to alertmanager dashboard'
	kubectl apply -f istio-nginx-1-virtualservice.yaml
	@echo 'Click on http://nginx-1.127.0.0.1.nip.io to connect to nginx-1 workload'

check-urls: ## Check URLs
#@$(eval URL="http://kiali.127.0.0.1.nip.io")
#@$(eval HTTP_CODE = $(shell curl -o /dev/null -w "%{http_code}\n" -sSLIk --max-time 2 "${URL}" 2>/dev/null))
#@[ "${HTTP_CODE}" == "200" ]  && (echo -n 'Click on http://kiali.127.0.0.1.nip.io to connect to kiali dashboard' && echo ' --> OK')
	@for i in "kiali" "prometheus" "grafana" "alertmanager" "kubernetes-dashboard" "nginx-1"; do \
    URL="http://$${i}.127.0.0.1.nip.io"; echo -n "Click on: $${URL} --> HTTP_CODE="; \
    curl -XGET -o /dev/null -w "%{http_code}\n" -sSLIk --max-time 2 "$${URL}" 2>/dev/null; \
  done

install-kyverno: ## Install kyverno (Policy as Code)
	# Install the Kyverno Helm chart into a new namespace called "kyverno"
	helm upgrade \
    --namespace kyverno \
    --create-namespace \
    --install \
    --version 1.3.1 \
    --repo https://kyverno.github.io/kyverno/ \
    kyverno \
    kyverno --devel
	@echo 'CR installed:'
	kubectl api-resources | egrep 'kyverno|wgpolicyk8s'

install-fleet: ## Install fleet
#ref: https://fleet.rancher.io/quickstart/
	helm -n fleet-system upgrade --install --create-namespace --wait \
    fleet-crd https://github.com/rancher/fleet/releases/download/v${FLEET_VERSION}/fleet-crd-${FLEET_VERSION}.tgz
	helm -n fleet-system upgrade --install --create-namespace --wait \
    fleet https://github.com/rancher/fleet/releases/download/v${FLEET_VERSION}/fleet-${FLEET_VERSION}.tgz
	# kubectl -n fleet-system logs -l app=fleet-controller
	# kubectl -n fleet-system get pods -l app=fleet-controller

configure-fleet-kyverno: install-fleet ## Configure kyverno best practices policies via fleet
	kubectl apply -f fleet-kyverno.yaml
	kubectl get gitrepo kyverno-repository -n fleet-local
	# kubectl get cpol
	# kubectl get policyreport -A
	# kubectl describe polr polr-ns-nginx-test -n nginx-test | grep "Status: \+fail" -B10

install-nginx-1: ## Install demo application nginx-1
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

certs: ## CERTIFICATES - Show cluster certificates
	@echo 'Cluster: ${CLUSTER_NAME}'
	@echo 'Context: ${CONTEXT}'
	@echo ''
	@echo 'Certificate:'
	@echo ${CERTIFICATE} | base64 --decode
	@echo ''
	@echo 'Private Key:'
	@echo ${KEY} | base64 --decode
	@echo ''
	@echo 'Cluster Certificate Authority:'
	@echo ${CLUSTER_CA} | base64 --decode

certs-creation-browser: ## CERTIFICATES - Create certification to be imported into browser to access i.e. kubernetes-dashboard
	echo ${CERTIFICATE} | base64 --decode > client-certificate-data-${CONTEXT}.crt
	echo ${KEY} | base64 --decode > client-key-data-${CONTEXT}.key
	# Following command would ask for encryption password, required when you need to import it to MacOs Keychain
	openssl pkcs12 -export -clcerts -inkey client-key-data-${CONTEXT}.key -in client-certificate-data-${CONTEXT}.crt -out client-data-${CONTEXT}.key.p12 -name "kubernetes-client"
	rm client-certificate-data-${CONTEXT}.crt client-key-data-${CONTEXT}.key
#@echo ${CLUSTER_CA} | base64 -d > ${CONTEXT}-cluster-ca.crt 

delete: ## Delete cluster
	kind delete cluster --name ${CLUSTER_NAME}

validation: create-cluster-eks-d install-calico install-metrics-server install-dashboards-all install-nginx-1 install-istio-all install-kyverno configure-fleet-kyverno certs
	# Just a validation target
	@echo 'Validation nginx-1 deployment'
	sleep 60 && curl -H'Host:nginx-1.127.0.0.1.nip.io' localhost
	@echo 'Validation istio'
	istioctl proxy-status
	istioctl analyze -A || true
	istioctl validate -f nginx-test/nginx-1.yaml
	kubectl get pods -l=app=nginx-1 -n nginx-test --no-headers=true -o=custom-columns='NAME:.metadata.name' | head -n1
	make check-urls
