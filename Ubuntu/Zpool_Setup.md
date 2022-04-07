# Zpool configuration for Ubuntu Servers
## `bpool`: A Grub compatible zpool for storing /boot
```
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

## A regular data zpool (can include the Ubuntu OS installation)
Assumes a GPT partition has been created which is labelled "`SSD1`"
```
sudo zpool create -o ashift=12  -o feature@async_destroy=enabled \
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

```
