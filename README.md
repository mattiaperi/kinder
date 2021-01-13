# kinder
KinD made simple

## How to

```bash
$ make help
=====================
PREREQUISITES:
- docker
- kind
- helm (v3)
- istioctl
=====================

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
  install-istio                 Install istio
  install-kiali                 Install kiali
  install-prometheus-operator   Install prometheus-operator
  certs                         Show cluster certificates
  delete-all                    Delete kinder
```

### Example
To install a multi node cluster based on EKS-D distribution, with some tooling around it:
```
$ make install-eks-d
```

## WARNING
> :warning: The repository scripts are just for personal use and they work for me. You are more then welcome to use it, I'll be honored, but this comes with no warranty. Use it at your own risk. Please feel free to contribute!