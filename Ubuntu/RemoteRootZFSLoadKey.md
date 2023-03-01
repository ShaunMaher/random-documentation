# Remote Unlock of Encrypted ZFS Root
## Install prerequisites
```
sudo apt install dropbear-initramfs initramfs-tools dropbear
```

## Configure network and Dropbear in initramfs
```
sudo vim /etc/initramfs-tools/initramfs.conf
```
Append the following
```
#format [host ip]::[gateway ip]:[netmask]:[hostname]:[device]:[autoconf]
#([hostname] can be omitted)
IP=172.30.0.203::172.30.0.1:255.255.0.0::enp0s25:off
```

To avoid issues with mis-matching host keys with the post startup SSH server
causing your SSH client to complain, we will setup the  initram dropbear
instance to use a different port.
```
sudo vim /etc/dropbear/initramfs/dropbear.conf
```
```
DROPBEAR_OPTIONS="-s -I 30 -p 4748"
```

### Dropbear authorized keys
```bash
sudo vim /etc/dropbear/initramfs/authorized_keys
```
```
no-port-forwarding,no-agent-forwarding,no-x11-forwarding,command="/scripts/unlock-zfs-root" ssh-rsa AA...ub initramfs
```

### Initramfs Unlock script
This script is executed instead of a shell when a user logs in to the dedicated
dropbear (SSH) service.  It simply prompts the user for the password, kills the
existing "zfs load-key" instance that initramfs started (that is waiting for a
password to be entered on the console), then exits, disconnecting the user.
```
sudo vim /usr/share/initramfs-tools/scripts/unlock-zfs-root
```
```bash
# Source the ZFS functions
. /scripts/zfs

root=$(ps | grep -v grep | grep 'zfs load-key' | awk '{print $NF}')
load_key_pid=$(ps | grep -v grep | grep 'zfs load-key' | awk '{print $1}')

if [ ! "x${root}" = "x" ] && [ ! "x${load_key_pid}" = "x" ]; then
  decrypt_fs $root
  kill $load_key_pid
  exit 1
else
  echo "Unable to find the \"zfs load-key\" process."
  exit 1
fi
```
```
sudo chmod +x /usr/share/initramfs-tools/scripts/unlock-zfs-root
```

### Initramfs Hook
```
sudo vim /etc/initramfs-tools/hooks/unlock-zfs-root.sh
```
```bash
#!/bin/sh

PREREQ="dropbear"

prereqs() {
  echo "$PREREQ"
}

case "$1" in
  prereqs)
    prereqs
    exit 0
  ;;
esac
```
```
sudo chmod +x /etc/initramfs-tools/hooks/unlock-zfs-root.sh
```