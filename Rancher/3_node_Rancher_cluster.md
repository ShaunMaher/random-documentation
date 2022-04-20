# 3 node Rancher cluster
Using Ubuntu and RKE2

## Setup DNS
Your RKE2/Rancher nodes need to be able to find each other by name.  This means
DNS.

Follow the instructions [here](3_node_Rancher_cluster_DNS.md) to setup a 
suitable DNS configuration.

## Build VMs
Use the guide [here](../Ubuntu/Ubuntu_VM_from_CloudImage.md) to provision 3 VMs.

Ideally:
* The VMs should be on seperate physical hypervisors (for HA)
* The VMs should have either static IPs or reservations in DHCP
* You can probably get started with:
  * 2x vCPUs each
  * 8GiB of RAM each
  * 100GiB Virtual Disk each

**When you get to the "*Optional:* Cloud-Init" section, return to this page for example cloud-init configuration files.**

### With Cloud-Init
These cloud-init files include:
* Install the "helm-stable" package repository
* Run the equivelant of "apt update" on first boot
* Run the equivelant of "apt upgrade" on first boot
* Install the following packages:
  * helm
  * openssh-server
  * avahi-daemon
  * vim-tiny
  * ufw
* Drop in a RKE2 configuration template with some values pre-filled
  * In the configuration file, we insert a list of TLS SAN (Subject Alternative
    Name) values to cover a lot of bases
    * The common name for the cluster.  Mine will be rke.ghanima.net
    * The name of this secific VM (from the VMNAME environment variable
    * A short name for this specific VM (e.g. "rke1")
    * The above short name appended with ".local" for Avahi name resolution
* Add a 10GiB swap file in /

These cloud-init files do __*not*__:
* Actually bootstrap the RKE2 cluster.  We will do that manually, when we're
  ready, maybe after testing things a bit first.

Download the following template files:
* For Node 1:
  * [user-data.template](3_node_Rancher_cluster/node1/user-data.template)
  * [meta-data.template](3_node_Rancher_cluster/node1/user-data.template)
* For Node 2:
  * [user-data.template](3_node_Rancher_cluster/node2/user-data.template)
  * [meta-data.template](3_node_Rancher_cluster/node2/user-data.template)
* For Node 3:
  * [user-data.template](3_node_Rancher_cluster/node3/user-data.template)
  * [meta-data.template](3_node_Rancher_cluster/node3/user-data.template)

Set the following environment variables:
```
export CLUSTERNAME="rke.ghanima.net"
export FIRSTNODE="rke1.ghanima.net"
export VMSHORTNAME=$(echo "${VMNAME}" | awk -F "." '{print $1}')
```

For the first node, generate a new random token
```
export TOKEN=$(dd if=/dev/urandom bs=4k count=1 2>/dev/null | sha512sum | dd bs=64 count=1 2>/dev/null); echo "${TOKEN}"
```

For the remaining nodes, use the token generated for the first node
```
export TOKEN="<the token>"
```

## Without Cloud-Init
If your hypervisor doesn't support Cloud-Init or you just don't want to use it
for some other reason, you can follow [these manual steps instead](3_node_Rancher_cluster_no_cloud-init.md).

## Pre-Bootstrap Testing
### Test DNS name resolution
Make sure each node and resolve and contact (ping) each other node.
```
ping rke1.ghanima.net
ping rke2.ghanima.net
ping rke3.ghanima.net
```

### Copy the configuration template to it's proper location
```
sudo cp /etc/rancher/rke2/config_template.yaml /etc/rancher/rke2/config.yaml
```

## Bootstrap the RKE2 cluster
**Reference:** https://docs.rke2.io/install/ha/

Run the bootstrap on the first node (only):
```
curl -sfL https://get.rke2.io | sudo sh -
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service
```
The `start` command may take a few moments to return a command prompt.  That's
OK.  Once the service is running it's going to bootstrap the etcd cluster and 
start a bunch of system pods.  This will take a few more minutes.

You can watch it's progress by repeatedly running:
```
/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get pods --all-namespaces
```

When all pods are either `Running` or `Completed`, the cluster is ready to have
the additional nodes added.

## Make sure you have a cluster, not standalone nodes
On any node run the following:
```
/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get nodes
```
If you don't see a list with multiple nodes, you may have forgotten the "Copy
the configuration template to it's proper location" step.  Either way,
something has gone wrong.

## "ubuntu" user kubectl configuration
```
mkdir .kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown -R $(id -u):$(id -g) ~
sudo ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
```

## OPTIONAL: Install the default Kubernetes Dashboard
```
GITHUB_URL=https://github.com/kubernetes/dashboard/releases
VERSION_KUBE_DASHBOARD=$(curl -w '%{url_effective}' -I -L -s -S ${GITHUB_URL}/latest -o /dev/null | sed -e 's|.*/||')
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/${VERSION_KUBE_DASHBOARD}/aio/deploy/recommended.yaml
```
`dashboard.admin-user.yml`
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
```

`dashboard.admin-user-role.yml`
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```

```
kubectl create -f dashboard.admin-user.yml -f dashboard.admin-user-role.yml
```

### OPTIONAL: Kubernetes Dashboard access via the Nginx Ingress Controller
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard-nginx-ingress
  namespace: kubernetes-dashboard
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - host: e7470-k3s.local
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: kubernetes-dashboard
              port:
                number: 443
```

## Install Rancher Prerequisites
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
kubectl create namespace cattle-system
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.1/cert-manager.crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.5.1
```

## Install Rancher
```
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rms.orro.cloud \
  --set bootstrapPassword=admin
```

## Next Steps
**TODO**

* Install Longhorn for HA persistant storage
* Install the "monitoring" package
