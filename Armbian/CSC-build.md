
## LXC Container
```
lxc init ubuntu:22.04 armbian-build
lxc config device add armbian-build loop0 unix-block path=/dev/loop0
lxc config device add armbian-build loop1 unix-block path=/dev/loop1
lxc config device add armbian-build loop2 unix-block path=/dev/loop2
lxc config device add armbian-build loop3 unix-block path=/dev/loop3
lxc config device add armbian-build loop4 unix-block path=/dev/loop4
lxc config device add armbian-build loop5 unix-block path=/dev/loop5
lxc config device add armbian-build loop6 unix-block path=/dev/loop6
lxc config device add armbian-build loop7 unix-block path=/dev/loop7
lxc config device add armbian-build loop8 unix-block path=/dev/loop8
lxc config device add armbian-build loop9 unix-block path=/dev/loop9
lxc config device add armbian-build loop10 unix-block path=/dev/loop10
lxc config device add armbian-build loop-control unix-char path=/dev/loop-control
lxc config set armbian-build raw.apparmor "mount,"
lxc config set armbian-build security.privileged true
```

```
./compile.sh \
BOARD=rockpi-4b \
BRANCH=current \
RELEASE=jammy \
BUILD_MINIMAL=yes \
BUILD_DESKTOP=no \
KERNEL_ONLY=no \
KERNEL_CONFIGURE=no
```