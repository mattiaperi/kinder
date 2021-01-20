# kinder
KinD made simple

## How to

```bash
$ make
The current script is tested for the following tools:

| tool        | version tested                                      |
| ----------- | --------------------------------------------------- |
| - docker    | tested: 20.10.2 (Docker Engine - Community)         |
| - kind      | tested: kind v0.9.0 go1.15.2 darwin/amd64           |
| - helm (v3) | tested: v3.4.2                                      |
| - istioctl  | tested: v1.8.1                                      |

The current script installs the following components.
Components installed with "latest" can be potentially broken :)

| component               | app version                 | chart version | comment   |
| ----------------------- | --------------------------- | ------------- | --------- |
| - EKS-D distribution    | kind-eks-d:v1.18.9-kbst.1   | -             | :ok_hand: |
| - calico                | latest                      | -             | :WARNING: |
| - grafana               | TBD                         | TBD           | TBD       |
| - kiali                 | 1.28.1                      | 1.28.1        | :ok_hand: |
| - kiverno               | v1.3.1                      | 1.3.1         | :ok_hand: |
| - kubernetes-dashboards | 2.1.0                       | 4.0.0         | :ok_hand: |
| - istio                 | latest                      | -             | :WARNING: |
| - metrics-server        | 0.4.1                       | 5.3.4         | :ok_hand: |
| - prometheus-operator   | 0.16.1                      | 0.16.1        | :ok_hand: |
| - weave-scope           | latest                      | -             | :WARNING: |


Usage:
  make <target>
  help                          Display this help
  install-single-node           Install a single-node cluster
  install-multi-nodes           Install a multi-node cluster
  install-eks-d                 Install a multi-node EKS-D cluster
  kinder-create-single-node     Create single node cluster
  kinder-create-multi-nodes     Create multi nodes cluster
  kinder-create-eks-d           Create multi nodes cluster based on AWS EKS-D distribution
  install-calico                Install CNI calico
  install-metrics-server        Install metrics-server
  install-dashboards-all        Install kubernetes-dashboard and weave-scope
  install-kubernetes-dashboard  Install kubernetes-dashboard
  install-weave-scope           Install weave-scope
  install-istio-all             Install istio with kiali, prometheus-operator, grafana
  map-ingressgateway-nodeports  Map ingressgateway nodeports to the localhost ports to fake a loadbalancer
  install-istio                 Install istio
  install-kiali                 Install kiali
  install-prometheus-operator   Install prometheus-operator
  install-kyverno               Install kyverno (Policy as Code)
  certs                         Show cluster certificates
  certs-creation-browser        Create certification to be imported into browser to access i.e. kubernetes-dashboard
  delete-all                    Delete kinder
```

### Example
To install a multi node cluster based on EKS-D distribution, with some tooling around it:
```
$ make install-eks-d
```

## WARNING
> :warning: The repository scripts are just for personal use and they work for me. You are more then welcome to use it, I'll be honored, but this comes with no warranty. Use it at your own risk. Please feel free to contribute!