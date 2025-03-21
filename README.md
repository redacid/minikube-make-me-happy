# Minikube
[Project URL](https://gitlab.prozorro.sale/serhii.rudenko/minikube)

### Requrements
    Before run need install minikebe and kubectl

```sh
make install-kubectl
make install-minikube
```

### Patched version on ingress-dns
    Original version always return ip of ingress-dns pod, this is no problem if used one minikube-node.  
    Patched version return ip of ingress-controller and normal worked with multiple minikube-nodes.  
    Image location https://hub.docker.com/repository/docker/gitlabprozorro/minikube-ingress-dns/tags  
    Sources comming son.  

* for StatefulSet and ReplicaSet use "csi-hostpath-sc" storage class




