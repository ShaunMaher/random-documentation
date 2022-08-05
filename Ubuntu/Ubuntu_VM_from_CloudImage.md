# Ubuntu VM from CloudImage
## Host configuration
### Storage
#### ZFS
If you haven't already, create an encrypted ZFS dataset to house your VM images

Assuming you created a Zpool called SSD1 by following [these steps](Zpool_Setup.md):
```
mkdir -p /etc/zfs/keys/
sudo dd if=/dev/urandom bs=4k count=1 | sha512sum | sudo dd bs=64 count=1 of=/etc/zfs/keys/SSD1_VMs
sudo zfs create -o encryption=aes-256-gcm -o keyformat=hex -o keylocation=file:///etc/zfs/keys/SSD1_VMs SSD1/VMs
sudo mkdir /etc/systemd/system/zfs-mount.service.d
sudo vim /etc/systemd/system/zfs-mount.service.d/load-key.conf
```

```
[Service] 
ExecStartPre=/usr/bin/zfs load-key SSD1/VMs
```

```
sudo zfs create -o mountpoint=/var/lib/libvirt/machines SSD1/VMs/machines
sudo zfs create -o mountpoint=/etc/libvirt -o overlay=on SSD1/VMs/config
```

### Networking
#### Add a bridge to your LAN (no VLAN tagging)
A name for the bridge.  Maximum 13 characters.  VLAN interface name will be prefixed with "vl".  Bridge name will be prefixed with "br".
```
BRNAME="LAN"
```

The name of the physical interface (or bond) that will be connected to the bridge
```
PHYINT="enp0s25"
```

```
sudo nmcli con down 'Wired connection 1'
sudo nmcli con delete 'Wired connection 1'
sudo nmcli con add type bridge ifname br${BRNAME} con-name br${BRNAME}
sudo nmcli con add type bridge-slave ifname ${PHYINT} con-name ${PHYINT} master br${BRNAME}
sudo nmcli connection modify br${BRNAME} connection.autoconnect-slaves 1
sudo nmcli connection modify br${BRNAME} connection.autoconnect-retries 0
sudo nmcli connection modify br${BRNAME} bridge.stp no
sudo nmcli connection modify br${BRNAME} ipv4.method dhcp
```

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

### Install Libvirt and Qemu
```
sudo apt install libvirt-daemon libvirt-daemon-driver-qemu qemu-kvm libvirt-daemon-system
sudo usermod -a -G libvirt $(id -u -n)
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
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

Resize the image to 100GiB and convert it to "preallocation=metadata" (for performance)
```
qemu-img resize jammy-server-cloudimg-amd64.img 100G
qemu-img convert -p -f qcow2 -O qcow2 -o preallocation=metadata -o cluster_size=1M jammy-server-cloudimg-amd64.img jammy-server-preallocated-amd64.qcow2
```

### *Optional:* Tar up the new image, maintaining sparseness
```
tar -czSf jammy-server-preallocated-amd64.tar.gz jammy-server-preallocated-amd64.qcow2
```

To extract this image from the tar at a later date, again maintaining sparseness:
```
sudo tar -xzSf jammy-server-preallocated-amd64.tar.gz
```

## Create the destination storage location for the VM

```
sudo zfs create -o recordsize=1M SSD1/VMs/machines/<vmname>
cd /var/lib/libvirt/machines/<vmname>
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
  --run-command "echo 'tmpfs /tmp tmpfs rw,nosuid,nodev' | tee -a /etc/fstab" \
  --password ubuntu:password:ubuntu \
  --hostname ${VMNAME}
```

### Download and customise a VM definition
**TODO:** I think I could make it so that both templates put the network interface at the same PCIe address but that's a future problem.

Download one of the following and save it as "`template.xml`"
* Redhat/CentOS 7 / Ubuntu 18.04+: [template.xml](Ubuntu_VM_from_CloudImage/libvirt_template_ubuntu_redhat/template.xml)
* Ubuntu 16.04: [template.xml](Ubuntu_VM_from_CloudImage/libvirt_template_ubuntu_ubuntu/template.xml)

```
envsubst <template.xml | sudo tee ${VMNAME}.xml
dd if=/dev/zero of=VARS.fd bs=1 count=131072
```

### *Optional:* Cloud-Init
#### Inject local files as Cloud-Init configuration files
**Reference:** https://sumit-ghosh.com/articles/create-vm-using-libvirt-cloud-images-cloud-init/

* [meta-data.template](Ubuntu_VM_from_CloudImage/meta-data.template)
* [user-data.template](Ubuntu_VM_from_CloudImage/user-data.template)
* [cdrom-device-template.xml](Ubuntu_VM_from_CloudImage/cdrom-device-template.xml)

Make any desired customisations.

Use `envsubst` to replace any `${ENV_VAR}` place holders with the content of
the relevant environent variable.
```
envsubst <meta-data.template | tee meta-data
envsubst <user-data.template | tee user-data
envsubst <cdrom-device-template.xml | tee cdrom-device.xml
```

Create an ISO image containing the generated files
```
genisoimage -output cidata.iso -V cidata -r -J user-data meta-data
sudo virsh attach-device ${VMNAME} --config cdrom-device.xml
```

#### Use a HTTP(S) URL as a source of Cloud-Init configuration files
**Reference:** https://opensource.com/article/20/5/create-simple-cloud-init-service-your-homelab

**TODO:** Flesh this out

Create `10_datasource.cfg` with the following content:
```
# Add the datasource:
# /etc/cloud/cloud.cfg.d/10_datasource.cfg

# NOTE THE TRAILING SLASH HERE!
datasource:
  NoCloud:
    seedfrom: http://ip_address:port/
```
Inject `10_datasource.cfg` into the image as `/etc/cloud/cloud.cfg.d/10_datasource.cfg`

## Define the VM in LibVirt
```
virsh -c qemu:///system pool-define-as $VMNAME dir - - - - "${VMDIR}"
virsh -c qemu:///system pool-build $VMNAME
virsh -c qemu:///system pool-start $VMNAME
virsh -c qemu:///system pool-autostart $VMNAME
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
