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
export VMSHORTNAME="rke1"
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
**TODO**


## Bootstrap the RKE2 cluster
**TODO**

## Install Rancher
**TODO**

## Next Steps
**TODO**

* Install Longhorn for HA persistant storage
* Install the "monitoring" package
