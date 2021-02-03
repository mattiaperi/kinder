# kinder
KinD made simple

## WARNING
> :warning: The repository scripts are just for personal use and they work for me. You are more then welcome to use it, I'll be honored, but this comes with no warranty. Use it at your own risk. Please feel free to contribute!

## How to

```bash
$ make help
The current script is tested for the following tools:

| tool        | version tested                                          |
| ----------- | ------------------------------------------------------- |
| - docker    | tested: 20.10.2 (Docker Engine - Community)             |
| - kind      | tested: kind v0.9.0 go1.15.2 darwin/amd64               |
| - helm (v3) | tested: v3.4.2                                          |
| - istioctl  | tested: v1.8.1                                          |

The current script installs the following components.
Components installed with "latest" can be potentially broken :)

| component               | app version                 | chart version |
| ----------------------- | --------------------------- | ------------- |
| - EKS-D distribution    | kind-eks-d:v1.18.9-kbst.1   | -             |
| - calico                | latest                      | -             |
| - fleet                 | 0.3.3                       | 0.3.3         |
| - grafana               | (via prometheus-operator)   | -             |
| - kiali                 | 1.28.1                      | 1.28.1        |
| - kyverno               | v1.3.1                      | 1.3.1         |
| - kubernetes-dashboards | 2.1.0                       | 4.0.0         |
| - istio                 | latest                      | -             |
| - metrics-server        | 0.4.1                       | 5.3.4         |
| - prometheus-operator   | 0.16.1                      | 0.16.1        |
| - weave-scope           | latest                      | -             |


Usage:
  make <target>
  help                          Display this help
  create-cluster-single-node    Create single node cluster
  create-cluster-multi-nodes    Create multi nodes cluster
  create-cluster-eks-d          Create multi nodes cluster based on AWS EKS-D distribution
  install-calico                Install CNI calico
  install-metrics-server        Install metrics-server
  install-dashboards-all        Install kubernetes-dashboard and weave-scope
  install-kubernetes-dashboard  Install kubernetes-dashboard
  install-weave-scope           Install weave-scope
  install-istio-all             Install istio with kiali, prometheus-operator, grafana
  map-ingressgateway-nodeports  Map ingressgateway nodeports to the localhost ports to fake a loadbalancer
  install-istio                 Install istio and default gateway
  install-prometheus            Install prometheus [WIP]
  install-kiali                 Install kiali
  configure-istio-urls          Configure Istio URLs
  install-kyverno               Install kyverno (Policy as Code)
  install-fleet                 Install fleet
  configure-fleet-kyverno       Configure kyverno best practices policies via fleet
  certs                         CERTIFICATES - Show cluster certificates
  certs-creation-browser        CERTIFICATES - Create certification to be imported into browser (kubernetes-dashboard)
  validate-metrics-server       VALIDATE - metrics-server
  validate-istio-urls           VALIDATE - istio virtualservices URLs
  delete                        Delete cluster
```

### Example
To install a multi-node cluster based on EKS-D distribution, with some tooling around it:
```
$ make kinder-eks-d
```
