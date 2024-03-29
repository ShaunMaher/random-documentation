
## LiveCD Environment
* Boot a Ubuntu Server ISO
* From the `[ Help ]` menu, select `Enter Shell`
  * `passwd`
  * `echo "PermitRootLogin yes" >/etc/ssh/sshd_config.d/root.conf`
  * `systemctl restart sshd`
* Connect to the VPS with SSH

wget -qO- https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-arm64-root.tar.xz | tar -xJf -

## Linux OS Partitions
```bash
export DEV=/dev/vda
blkdiscard "${DEV}" -f
sudo parted "${DEV}"
```

```
mklabel gpt
mkpart bios_grub ext2 2048s 8M
set 1 bios_grub on
mkpart ESP fat32 8M 512M
set 2 ESP on
mkpart BOOT ext2 512M 2G
mkpart SWAP linux-swap 2G 8G
mkpart SSD1 ext2 8G 100%
q
```

```bash
mkfs.fat -F 32 "${DEV}2"
```

## ZFS Datasets
### bpool
>>>
**Possible improvement:** Using "copies=2" makes it so that all data in a
certain dataset is stored twice.  This allows ZFS to automatically recover from
corrupted blocks.  This uses twice the space and, because both copies are on the
same physical device, does not help in the event of device failure.  This might
be useful on bpool/BOOT/ROOT and SSD1/OS/Neon/ROOT.
>>>

The "bpool" dataset needs to be compatible with the GRUB bootloader so it needs
to be created with a minimal subset of ZFS features.  Why not just use ext4 or
even the existing FAT32 EFI partition?  ZFS still has checksuming (so you will
know if your kernel image/initrd have become corrupted) and snapshots (for
rollback).
```bash
sudo apt install -y zfsutils-linux
sudo zpool create -d \
                -o feature@async_destroy=enabled \
                -o feature@empty_bpobj=enabled \
                -o feature@spacemap_histogram=enabled \
                -o feature@enabled_txg=enabled \
                -o feature@hole_birth=enabled \
                -o feature@bookmarks=enabled \
                -o feature@embedded_data=enabled \
                -o feature@large_blocks=enabled \
                -O mountpoint=/mnt/zfs/bpool \
                -f \
                bpool /dev/disk/by-partlabel/BOOT
sudo zfs create bpool/BOOT
sudo zfs create bpool/BOOT/ROOT
sudo zfs set mountpoint=/boot bpool/BOOT/ROOT
```

### SSD1

TODO: use zstd instead of lz4?

```bash
sudo zpool create -o ashift=12 \
                  -o feature@async_destroy=enabled \
                  -o feature@encryption=enabled \
                  -o feature@bookmarks=enabled \
                  -o feature@embedded_data=enabled \
                  -o feature@empty_bpobj=enabled \
                  -o feature@enabled_txg=enabled \
                  -o feature@extensible_dataset=enabled \
                  -o feature@filesystem_limits=enabled \
                  -o feature@hole_birth=enabled \
                  -o feature@large_blocks=enabled \
                  -o feature@lz4_compress=enabled \
                  -o feature@spacemap_histogram=enabled \
                  -o feature@userobj_accounting=enabled \
                  -O acltype=posixacl \
                  -O compression=lz4 \
                  -O devices=off \
                  -O normalization=formD \
                  -O relatime=on \
                  -O xattr=sa \
                  -O mountpoint=/mnt/zfs/SSD1 \
                  -f \
                  SSD1 /dev/disk/by-partlabel/SSD1
sudo zfs create SSD1/OS
sudo zfs create -o encryption=aes-256-gcm -o keyformat=passphrase -o compression=on SSD1/OS/Jammy
sudo zfs load-key SSD1/OS/Jammy
sudo zfs create SSD1/OS/Jammy/ROOT
```

## Copy the upstream OS RootFS to the ZFS datasets
```bash
sudo zpool export SSD1
sudo zpool export bpool
sudo mkdir /target
sudo zpool import -R /target SSD1
sudo zpool import -R /target bpool
sudo zfs set overlay=on SSD1/OS/Jammy/ROOT
sudo zfs set mountpoint=/ SSD1/OS/Jammy/ROOT
sudo zpool export bpool
sudo zpool export SSD1
sudo zpool import -R /target SSD1
sudo zfs load-key SSD1/OS/Jammy
sudo zfs mount SSD1/OS/Jammy/ROOT
sudo zpool import -R /target bpool

mkdir /target/boot/efi
sudo mount /dev/disk/by-partlabel/ESP /target/boot/efi
wget -qO- https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-root.tar.xz | tar -xJf - -C /target

```

## Make the OS in the ZFS datasets bootable
We bind certain system directories into the /target directory and then chroot
into it.
```bash
sudo mkdir /target/dev /target/proc /target/sys
sudo mount --rbind /dev /target/dev
sudo mount --rbind /proc /target/proc
sudo mount --rbind /sys /target/sys
sudo mount --rbind /dev/pts /target/dev/pts
sudo mount --make-rslave /target/dev
sudo mount --make-rslave /target/proc
sudo mount --make-rslave /target/sys
sudo mount --make-rslave /target/dev/pts
sudo chroot /target
```

```bash
export DEV=/dev/vda
unlink /etc/resolv.conf
echo "nameserver 8.8.8.8" >/etc/resolv.conf
```

Not relevant yet: If your hardware needs a kernel newer than the one provided 
(5.15) you can install the HWE kernel (X.X) now:
```bash
apt install linux-image-generic-hwe-XX.XX linux-headers-generic-hwe-XX.XX
```

**Old version**
```bash
sudo apt install zfsutils-linux zfs-initramfs openssh-server linux-image-generic
sudo apt purge snapd
rm -fr /etc/default/grub.d/50-cloudimg-settings.cfg
useradd ubuntu
passwd ubuntu
usermod -a -G ubuntu sudo
echo "ChallengeResponseAuthentication yes" >/etc/ssh/sshd_config.d/ChallengeResponseAuthentication.conf
hostnamectl set-hostname lu.ghanima.net
echo "127.0.0.1 localhost lu lu.ghanima.net" >>/etc/hosts
echo -e "network:\n  ethernets:\n    enp1s0:\n      dhcp4: true\n  version: 2" >/etc/netplan/01-manual-configuration.yaml
echo "options zfs zfs_arc_max=134217728" >> /etc/modprobe.d/zfs.conf
sudo update-initramfs -c -k all
```

**New version**
```bash
apt update
apt install -y zfsutils-linux zfs-initramfs openssh-server linux-image-generic
rm -fr /etc/default/grub.d/50-cloudimg-settings.cfg
echo -e "network:\n  ethernets:\n    enp1s0:\n      dhcp4: true\n  version: 2" >/etc/netplan/01-manual-configuration.yaml
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"'ds=nocloud-net;s=https://configuration-backups.ghanima.net/cloud-init/lu.ghanima.net/'\"" >/etc/default/grub.d/cloud-init.cfg
echo "GRUB_TIMEOUT=5" >>/etc/default/grub.d/cloud-init.cfg
sudo update-initramfs -c -k all
```

The following error messages are normal (we are not using dmcrypt so they are
harmless):
```
cryptsetup: ERROR: Couldn't resolve device SSD1/OS/Jammy/ROOT
cryptsetup: WARNING: Couldn't determine root device
```

```bash
sudo grub-install --bootloader-id=ubuntu --efi-directory=/boot/efi "${DEV}"
```

Setup encrypted swap
```bash
echo "swap /dev/disk/by-partlabel/SWAP /dev/urandom swap,cipher=aes-cbc-essiv:sha256,size=256,plain" | sudo tee -a /etc/crypttab
echo "/dev/mapper/swap none swap defaults 0 0" | sudo tee -a /etc/fstab
echo "RESUME=none" |sudo tee /etc/initramfs-tools/conf.d/resume
```

Update everything
```bash
apt update; apt -y full-upgrade; apt autoremove
```

```bash
sudo zfs snapshot SSD1/OS/Jammy/ROOT@fresh-install
sudo zfs snapshot bpool/BOOT/ROOT@fresh-install
sudo update-grub
exit
```

```bash
sudo umount /target/boot/efi
sudo umount -R /target
sudo zfs umount SSD1/OS/Jammy/ROOT
sudo zpool export bpool
sudo zpool export SSD1
```

The following errors can be ignored.
```
umount: /target/mnt/zfs/SSD1/OS: no mount point specified.
cannot unmount '/target/mnt/zfs/SSD1/OS': umount failed
```

Now we reboot, hopefully into our newly installed OS.
```bash
sudo reboot
```
You should be prompted to unplug the USB boot media during shutdown.  If not,
unplug it during BIOS startup, before the machine boots.
