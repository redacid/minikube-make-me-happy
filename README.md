# Minikube

### Requrements
    Before run need install minikube and kubectl

```sh
make install-kubectl
make install-minikube
```
### Start/Stop Minikube cluster

#### First start(deploy cluster)
```sh
make minikube-deploy
```
#### Start stopped cluster 
```sh
make minikube-start
```
#### Stop cluster
```sh
make minikube-stop
```
#### Destroy cluster
```sh
make minikube-destroy
```

### Patched version of ingress-dns
    Original version always return ip of ingress-dns pod, this is no problem if used one minikube-node.  
    Patched version return ip of ingress-controller and normal worked with multiple minikube-nodes.  
    Image location https://hub.docker.com/repository/docker/gitlabprozorro/minikube-ingress-dns/tags  
    Sources in build-ingress-dns directory.  

* for StatefulSet and ReplicaSet use "csi-hostpath-sc" storage class

### TODO
    Support processing DNS requests for test domains with systemd-resolved
    https://minikube.sigs.k8s.io/docs/handbook/addons/ingress-dns/#Linux




