# Portainer Docker host VM (Ubuntu)

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

## Cloud-Init
Download the following template files:
* [user-data.template](portainer_docker_host_vm/node1/user-data.template)
* [meta-data.template](portainer_docker_host_vm/node1/meta-data.template)
