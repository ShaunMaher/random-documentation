# 3 node Rancher cluster
## Setup DNS
Your RKE2/Rancher nodes need to be able to find each other by name.  This means
DNS.

I generally like to install and configure the Avahi Daemon so that things can
just find each other automagically but this doesn't work for RKE2.  We need
another solution.

Unless your solution involves dynamic DNS registration (probably not), now is
the time to think about IP allocations.  You can either:
* Use Static IPs
  * Should be in the same subnet as the rest of the LAN you're connecting to,
    unless you are deliberately segregating things (e.g. in a seperate VLAN)
  * Should be excluded from the network's DHCP pool to avoid conflicts
* Use DHCP and/or IPv6 Auto Configuration (my preference)
  * DHCP leases should be made static/persistant in your DHCP server.  Not all
    (read: cheap/simple) DHCP servers (e.g. in home routers) suppport this.
  * **TODO:** IPv6 Auto Configuration IPs are generally not static.  How do we
    deal with this?

### LAN DNS Server: Microsoft Active Directory DNS Server
If your network already has an Active Directory, you might as well use it's DNS
server.
* Create a new "Forward Lookup" zone (unless the zone you want to use already
  exists)
* Create A or AAAA records for each VM's hostname pointing at the VM's IP.

### LAN DNS Server: Zentyal (what I'll be using)
**TODO**

### LAN DNS Server: Samba 4 (internal or bind)
**TODO**

### LAN Router: Mikrotik
**TODO**

### LAN Router: opnSense
**TODO**

### LAN Router: pfSense
**TODO**

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

### Cloud-Init
* For Node 1:
  * [user-data](3_node_Rancher_cluster/node1/user-data)
  * [meta-data](3_node_Rancher_cluster/node1/user-data)
* For Node 2:
  * [user-data](3_node_Rancher_cluster/node2/user-data)
  * [meta-data](3_node_Rancher_cluster/node2/user-data)
* For Node 3:
  * [user-data](3_node_Rancher_cluster/node3/user-data)
  * [meta-data](3_node_Rancher_cluster/node3/user-data)

## Bootstrap the RKE2 cluster
**TODO**

## Install Rancher
**TODO**

## Next Steps
**TODO**

* Install Longhorn for HA persistant storage
* Install the "monitoring" package
