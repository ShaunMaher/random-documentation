
## big.LITTLE considerations
If you are running a VM on hardware that supports big.LITTLE (some fast cores, some slower cores) you may have issues starting a VM.

I'm using an RK3399 based board with 4 "little" cores, which the system sees as
CPUs 1, 2, 3 and 4.  The following will pin a VM to run on only these 4 "litte"
cores:
```
 <vcpu placement="static" cpuset="0-3">4</vcpu>
```


taskset -c 0,1 qemu-system-aarch64 -m 2G -smp 2 -M virt,accel=kvm,gic-version=3 -cpu host,pmu=off -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd -drive if=virtio,file=/jammy-server-cloudimg-arm64.img,id=hd0 -nographic -net none