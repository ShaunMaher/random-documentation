# Ubuntu VM from CloudImage
## Host configuration
### Storage
#### ZFS
If you haven't already, create an encrypted ZFS dataset to house your VM images
```
sudo dd if=/dev/urandom bs=4k count=1 | sha512sum | sudo dd bs=64 count=1 of=/etc/zfs/keys/SSD1_VMs
sudo zfs create -o encryption=aes-256-gcm -o keyformat=hex -o keylocation=file:///etc/zfs/keys/SSD1_VMs SSD1/VMs
sudo mkdir /etc/systemd/system/zfs-mount.service.d
sudo vim /etc/systemd/system/zfs-mount.service.d/load-key.conf
```

```
[Service] 
ExecStartPre=/usr/bin/zfs load-key SSD1/VMs
```

### Networking
#### Add an additional VLAN
A name for the bridge.  Maximum 13 characters.  VLAN interface name will be prefixed with "vl".  Bridge name will be prefixed with "br".
```
BRNAME="WORK"
```

The name of the physical interface (or bond) that will be connected to the bridge
```
PHYINT="enp0s25"
```

The VLAN IP of the 
```
VLAN=6
```

```
sudo nmcli con add type bridge ifname br${BRNAME} con-name br${BRNAME}
sudo nmcli con add type vlan ifname ${PHYINT}.vl${BRNAME} con-name ${PHYINT}.vl${BRNAME} dev ${PHYINT} id $VLAN master br${BRNAME} slave-type bridge
sudo nmcli connection modify br${BRNAME} ipv4.method disabled
sudo nmcli connection modify br${BRNAME} ipv6.method ignore
sudo nmcli connection modify br${BRNAME} bridge.stp no
sudo nmcli connection modify br${BRNAME} connection.autoconnect-slaves 1
sudo nmcli connection modify br${BRNAME} connection.autoconnect-retries 0
```

## Build the initial VM image
Create a temporary location or create a temporary ZFS dataset
```
sudo zfs create SSD1/VMs/temp
cd /mnt/zfs/SSD1/VMs/temp
sudo chown -R $(id -u):$(id -g) .
```

Download the upstream image
```
wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
```

Resize the image to 100GiB and convert it to "preallocation=metadata" (for performance)
```
qemu-img resize focal-server-cloudimg-amd64.img 100G
qemu-img convert -p -f qcow2 -O qcow2 -o preallocation=metadata -o cluster_size=1M focal-server-cloudimg-amd64.img focal-server-preallocated-amd64.qcow2
```

Optional: Tar up the new image, maintaining sparseness
```
tar -czSf focal-server-preallocated-amd64.tar.gz focal-server-preallocated-amd64.qcow2
```

To extract this image from the tar at a later date, again maintaining sparseness:
```
sudo tar -xzSf focal-server-preallocated-amd64.tar.gz
```

## Customise the image
Setup some environment variables that will be used in later commands
```
export VMNAME=$(basename "${PWD}")
export VMDIR="${PWD}"
export VMMEM="1048576"
export LANIF="brLAN"
if [[ $(lsb_release -a) =~ Ubuntu ]]; then export EMULATOR="/usr/bin/kvm-spice"; else export EMULATOR="/usr/libexec/qemu-kvm"; fi
if [[ $(lsb_release -a) =~ Ubuntu ]]; then export OMVF="/usr/share/OVMF/OVMF_CODE.fd"; else export OMVF="/usr/share/OVMF/OVMF_CODE.secboot.fd"; fi
```

### Download and customise a suitable network configuration
#### For DHCP
* Hypervisor creates enp1s0 **(probably this one)**: [01-manual-configuration.yaml](Ubuntu_VM_from_CloudImage/netplan_template_dhcp_enp1s0/01-manual-configuration.yaml)
* Hypervisor creates enp2s1 (ubuntu 16.04 does this): [01-manual-configuration.yaml](Ubuntu_VM_from_CloudImage/netplan_template_dhcp_enp2s1/01-manual-configuration.yaml)

#### For Static IPs
* Hypervisor creates enp1s0 **(probably this one)**: [01-manual-configuration.yaml](Ubuntu_VM_from_CloudImage/netplan_template_static_enp1s0/01-manual-configuration.yaml)
* Hypervisor creates enp2s1 (ubuntu 16.04 does this): [01-manual-configuration.yaml](Ubuntu_VM_from_CloudImage/netplan_template_static_enp2s1/01-manual-configuration.yaml)

### Set Hostname, Create a sudo enabled "ubuntu" user, set the password for the "ubuntu" user, inject the network configuration
```
sudo virt-customize \
  -a focal-server-preallocated-amd64.qcow2 \
  --copy-in "01-manual-configuration.yaml:/etc/netplan/" \
  --run-command "useradd -m -G sudo -s /usr/bin/bash ubuntu" \
  --run-command "dpkg-reconfigure openssh-server" \
  --run-command "sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config" \
  --password ubuntu:password:SpankW00 \
  --hostname ${VMNAME}
```

### Download and customise a VM definition
TODO: I think I could make it so that both templates put the network interface at the same PCIe address but that's a future problem.

Download one of the following and save it as "`template.xml`"
* Redhat/CentOS 7 / Ubuntu 18.04+: [template.xml](Ubuntu_VM_from_CloudImage/libvirt_template_ubuntu_redhat/template.xml)
* Ubuntu 16.04: [template.xml](Ubuntu_VM_from_CloudImage/libvirt_template_ubuntu_ubuntu/template.xml)

```
envsubst <template.xml | sudo tee ${VMNAME}.xml
dd if=/dev/zero of=VARS.fd bs=1 count=131072
```

### *Optional:* Cloud-Init
**Reference:** https://sumit-ghosh.com/articles/create-vm-using-libvirt-cloud-images-cloud-init/

```
touch meta-data
touch user-data
```
Make customisations. Then:
```
genisoimage -output cidata.iso -V cidata -r -J user-data meta-data
```

## Define the VM in LibVirt
```
virsh define ${VMNAME}.xml
```

## Start the VM
```
virsh start ${VMNAME}
```
### Connect to the VM's console (virtual serial interface) from the host
```
virsh console ${VMNAME}
```
