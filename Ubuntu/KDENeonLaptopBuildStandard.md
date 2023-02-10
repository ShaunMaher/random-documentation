## Linux OS Partitions
```bash
export DEV=/dev/nvme0n1
blkdiscard "${DEV}" -f
sudo parted "${DEV}"
```

```
mklabel gpt
mkpart bios_grub ext2 2048s 8M
set 1 bios_grub on
mkpart ESP fat32 8M 1G
set 2 ESP on
mkpart BOOT ext2 1G 3G
mkpart SWAP linux-swap 3G 19G
mkpart SSD1 ext2 19G 39G
mkpart TMP ext2 39G 63G
q
```

```bash
mkfs.fat -F 32 "${DEV}p2"
```

## Install KDE Neon
TODO

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
                  -O mountpoint=/mnt/zfs/SSD1 SSD1 /dev/disk/by-partlabel/SSD1
sudo zfs create SSD1/OS
sudo zfs create -o encryption=aes-256-gcm -o keyformat=passphrase -o compression=on SSD1/OS/NeonJammy
sudo zfs load-key SSD1/OS/NeonJammy
sudo zfs create SSD1/OS/NeonJammy/ROOT
```

## Copy the Installed OS to the ZFS datasets
```bash
sudo zpool export SSD1
sudo zpool export bpool
sudo mkdir /target
sudo zpool import -R /target SSD1
sudo zpool import -R /target bpool
sudo zfs set overlay=on SSD1/OS/NeonJammy/ROOT
sudo zfs set mountpoint=/ SSD1/OS/NeonJammy/ROOT
sudo zpool export bpool
sudo zpool export SSD1
sudo zpool import -R /target SSD1
sudo zfs load-key SSD1/OS/NeonJammy
sudo zfs mount SSD1/OS/NeonJammy/ROOT
sudo zpool import -R /target bpool

sudo mkdir /source
sudo mount --bind --make-slave /tmp/calamares-root-* /source
sudo rsync -avPX /source/. /target/.
```

## Make the OS in the ZFS datasets bootable
We bind certain system directories into the /target directory and then chroot
into it.
```bash
sudo mount /dev/disk/by-partlabel/ESP /target/boot/efi
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
export DEV=/dev/nvme0n1
unlink /etc/resolv.conf
echo "nameserver 8.8.8.8" >/etc/resolv.conf
```

Not relevant yet: If your hardware needs a kernel newer than the one provided 
(5.15) you can install the HWE kernel (X.X) now:
```bash
apt install linux-image-generic-hwe-XX.XX linux-headers-generic-hwe-XX.XX
```

```bash
sudo apt install zfsutils-linux zfs-initramfs openssh-server
sudo update-initramfs -c -k all
```

The following error messages are normal (we are not using dmcrypt so they are
harmless):
```
cryptsetup: ERROR: Couldn't resolve device SSD1/OS/NeonFocal/ROOT
cryptsetup: WARNING: Couldn't determine root device
```

```bash
sudo grub-install --bootloader-id=neon --efi-directory=/boot/efi "${DEV}"
sudo grub-install --bootloader-id=ubuntu --efi-directory=/boot/efi "${DEV}"
```

Setup encrypted swap
```bash
echo "swap /dev/disk/by-partlabel/SWAP /dev/urandom swap" | sudo tee -a /etc/crypttab
echo "/dev/mapper/swap none swap defaults 0 0" | sudo tee -a /etc/fstab
```

Update everything
```bash
apt update; apt -y full-upgrade; apt autoremove
```

```bash
sudo zfs snapshot SSD1/OS/NeonJammy/ROOT@fresh-install
sudo zfs snapshot bpool/BOOT/ROOT@fresh-install
sudo update-grub
exit
```

```bash
sudo umount /target/boot/efi
sudo umount -R /target
sudo zfs umount SSD1/OS/NeonJammy/ROOT
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

## Backup Image
If you want to take a backup of the fresh install for re-use, consider a command
like this:
```
zpool trim --wait SSD1
sudo dd if=/dev/nvme0n1 bs=512 count=76171264 | tee >(sha256sum >/dev/stderr) | zstd -10 | tee >(sha256sum >/dev/stderr) | mbuffer | ssh [user]@[some other machine] "mbuffer >/path/to/FreshInstall.dd.zst"
```

sudo dd if=/dev/nvme0n1 bs=512 count=76171264 | tee >(sha256sum >/dev/stderr) | zstd -10 | tee >(sha256sum >/dev/stderr) | mbuffer | ssh ubuntu@ph3.local "mbuffer >/mnt/zfs/RaidZ3Disk/shares/Backups/spare-e7470/FreshInstall.dd.zst"

sudo dd if=/dev/nvme0n1 bs=512 count=76171264 | tee >(sha256sum >/dev/stderr) | zstd -10 | tee >(sha256sum >/dev/stderr) | mbuffer | ssh ubuntu@ph3.local "mbuffer >/mnt/zfs/RaidZ3Disk/shares/Backups/spare-e7470/WorkInstall.dd.zst"


To Restore the above image:
```
ssh ssh [user]@[some other machine] "dd if=/path/to/FreshInstall.dd.zst bs=512 | mbuffer" | mbuffer zstd -d -c | tee >(sha256sum >/dev/stderr) sudo dd if=/dev/nvme0n1 bs=512
```

### Before "gold" image
* Extra packages from [KDE Neon Work Laptop Extras](KDENeonWorkLaptopExtras.md)
* Remove TEMP partition and make sure it's not in grub
* cfs-zen-tweaks: https://wiki.mach.com.au/index.php?title=Shaun:Mach_Laptop_Ubuntu_Build_Standard#CPU_Scheduler
* CPU governor: https://wiki.mach.com.au/index.php?title=Shaun:Mach_Laptop_Ubuntu_Build_Standard#CPU_Governor

## Security Hardening
* In Firefox "about:config" set "network.IDN_show_punycode" to "true"

## TODO
* https://blog.trifork.com/2020/05/22/linux-homedir-encryption/
