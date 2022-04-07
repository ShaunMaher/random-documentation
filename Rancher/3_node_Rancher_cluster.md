# 3 node Rancher cluster
## Build VMs
Use the guide [here](../Ubuntu/Ubuntu_VM_from_CloudImage.md) to provision 3 VMs.

Ideally:
* The VMs should be on seperate physical hypervisors (for HA)
* The VMs should have either static IPs or reservations in DHCP

**When you get to the "*Optional:* Cloud-Init" section, return to this page for example cloud-init configuration files.

### Cloud-Init
* For Node 1:
  * [user-data](node1/user-data)
  * [meta-data](node1/user-data)
* For Node 2:
  * [user-data](node2/user-data)
  * [meta-data](node2/user-data)
* For Node 3:
  * [user-data](node3/user-data)
  * [meta-data](node3/user-data)
  
