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
  kinder-create-single-node     Create single node cluster
  kinder-create-multi-nodes     Create multi nodes cluster
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
  delete                        Delete kinder
```

### Example: install a KinD cluster single node 
```bash
$ kinder-create-single-node
```


```bash
$ make insta
```

### Test
```bash
$ curl -XGET -sSLIk localhost:15021/healthz/ready
```
