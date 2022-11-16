# Ubuntu Hypervisor Build Standard
I am strongly considering moving to Harvester as my hypervisor distro of choice
but, if I want to run VMs on Ubuntu laptop or use the hypervisor hardware for
additional tasks, a hypervisor-only disrto is not quite the right fit.

**This document is not complete.**  I'm still working on pasting my various
snippets into a single document.

## Host configuration
### Storage
#### ZFS
If you haven't already, create an encrypted ZFS dataset to house your VM images

Assuming you created a Zpool called SSD1 by following [these steps](Zpool_Setup.md):
```
sudo mkdir -p /etc/zfs/keys/
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

