# Experiments with Mikrotik RouterOS NPK Files
I have it in mind to see if I can run a RouterOS virtual router on an Arm
device.  This is easily done on x86_64 as Mikrotik provide VM images that are
ready to go.  No so for Arm.

My initial assumptions are that we will need:
* Root filesystem (SquashFS image in NPK) which does not include a kernel; so
* A kernel image

## Extract the parts of the NPK file
**TODO:** Flesh out htis part

https://github.com/botlabsDev/npkpy

## Extract a Kernel from "CntZlibDompressedData.raw"

**TODO:**
* Make the script take a file name as a parameter
* Make the script handle the zlib-flate on it's own

First up, this data blob is compressed with Zlib, decompress it:
```
sudo apt install qpdf
zlib-flate -uncompress < 010_cnt_CntZlibDompressedData.raw >010_cnt_CntZlibDompressedData
```

Now use [extract_kernel.sh](npk_experiments/extract_kernel.sh) to extract the
indervidual files contained within this blob:
```
bash ./extract_kernel.sh
```

The result should be a file called `kernel` in the current directory.  The
script may have also extracted other files (`bash`, `UPGRADED`).  I don't think
we need these files at this stage.

## Booting a VM
No idea yet.  The next steps will need to wait until a future time.

https://qemu-project.gitlab.io/qemu/system/linuxboot.html

* We probably need to turn 008_cnt_CntSquashFsImage.raw into a partition on
  virtual disk image
* sdio for disk interface?  IDE?  SATA?
* The end of the `kernel` file has the kernel command line arguments.  Can
  these be overridden?
  * Added verbosity would be handy

```
qemu-system-aarch64 -m 2G -smp 2 -M virt,accel=kvm,gic-version=3 -cpu host,pmu=off -kernel ./kernel -drive if=virtio,file=./008_cnt_CntSquashFsImage.raw,id=hd0 -nographic -net none
```