# Toggling two monitors with a single port KVM Switch
## The problem
I have two PCs and two monitors and a single port HDMI KVM switch that toggles
one monitor, keyboard and mouse between the PCs.  This leaves the second
monitor that I need to press buttons on (go into the menu, select an input)
whenever I toggle the KVM.

## The solution
Then I discovered `ddcutil` which is command line tool that can interact with
monitors and change their settings (e.g. color profiles, **change inputs**).

I took a look at `dmesg` to see if either of my PCs logs anything when the KVM
toggles.  I found that the PC notices that the USB keyboard dongle is removed
when the KVM toggles to the other PC and is added the the KVM is toggled back.

The means that we can create a `udev` rule that monitors for specific hardware
changes.  When it sees the dongle go away, switch the screen to the other
input.  When it sees the dongle appear, toggle the screen back to the local
input.

## `ddcutil`
On Ubuntu, install the `ddcutil` package (`sudo apt install ddcutil`).  Then
have it probe your monitors:
```
ddcutil detect
```
```
Display 1
   I2C bus:             /dev/i2c-1
   EDID synopsis:
      Mfg id:           ACR
      Model:            Acer KA241
      Serial number:    T6RSA0014200
      Manufacture year: 2018
      EDID version:     1.3
   VCP version:         2.1

Display 2
   I2C bus:             /dev/i2c-2
   EDID synopsis:
      Mfg id:           ACR
      Model:            Acer KA241
      Serial number:    T6RSA0014200
      Manufacture year: 2018
      EDID version:     1.3
   VCP version:         2.1

Invalid display
   I2C bus:             /dev/i2c-4
   EDID synopsis:
      Mfg id:           LGD
      Model:            
      Serial number:    
      Manufacture year: 2014
      EDID version:     1.4
   DDC communication failed
   This is an eDP laptop display. Laptop displays do not support DDC/CI.
```
My two external monitors (the final entry is the built-in display on my laptop)
show up on `/dev/i2c-1` and `/dev/i2c-2`.

Running the same command on my other PC shows the second monitor as not
supported.  I assume that this is because it is connected via DVI instead of 
HDMI.  This means that only one PC can control that second monitor.

```
sudo ddcutil capabilities --bus 1
```
```
MCCS version: 2.1
Commands:
   Command: 01 (VCP Request)
   Command: 02 (VCP Response)
   Command: 03 (VCP Set)
   Command: 07 (Timing Request)
   Command: 0c (Save Settings)
   Command: 4e (unrecognized command)
   Command: f3 (Capabilities Request)
   Command: e3 (Capabilities Reply)
VCP Features:
   Feature: 02 (New control value)
   Feature: 04 (Restore factory defaults)
   Feature: 05 (Restore factory brightness/contrast defaults)
   Feature: 08 (Restore color defaults)
   Feature: 0B (Color temperature increment)
   Feature: 0C (Color temperature request)
   Feature: 10 (Brightness)
   Feature: 12 (Contrast)
   Feature: 14 (Select color preset)
      Values:
         05: 6500 K
         08: 9300 K
         0b: User 1
   Feature: 16 (Video gain: Red)
   Feature: 18 (Video gain: Green)
   Feature: 1A (Video gain: Blue)
   Feature: 52 (Active control)
   Feature: 6C (Video black level: Red)
   Feature: 6E (Video black level: Green)
   Feature: 70 (Video black level: Blue)
   Feature: AC (Horizontal frequency)
   Feature: AE (Vertical frequency)
   Feature: B6 (Display technology type)
   Feature: C0 (Display usage time)
   Feature: C6 (Application enable key)
   Feature: C8 (Display controller type)
   Feature: C9 (Display firmware level)
   Feature: CC (OSD Language)
      Values:
         00: Reserved value, must be ignored
         01: Chinese (traditional, Hantai)
         02: English
         03: French
         04: German
         05: Italian
         06: Japanese
         08: Portuguese (Portugal)
         09: Russian
         0a: Spanish
         0c: Turkish
         0d: Chinese (simplified / Kantai)
         0e: Portuguese (Brazil)
         14: Dutch
         16: Finish
         1e: Polish
   Feature: D6 (Power mode)
      Values:
         01: DPM: On,  DPMS: Off
         04: DPM: Off, DPMS: Off
         05: Write only value to turn off display
   Feature: DF (VCP Version)
   Feature: 60 (Input Source)
      Values:
         01: VGA-1
         03: DVI-1
         11: HDMI-1
   Feature: FF (manufacturer specific feature)
```

I want to target feature `60`.  I want to be able to change between `03` and
`11`.  Just to frustrate people, that `11` is a hex value.  The `setvcp`
command we will use in a moment expects a decimal input.  `11` becomes `17`.

Switch the first monitor to DVI input:
```
sudo ddcutil setvcp 60 03 --bus 1
```

Switch the first monitor back to HDMI input:
```
sudo ddcutil setvcp 60 17 --bus 1
```

If that worked for you, your display hardware is compatible.

## USB device
Start the udev monitoring tool:
```
sudo udevadm monitor --kernel --property --subsystem-match=usb
```

Toggle your KVM back and forth.  If the above command returned a bunch of
events then there are hardware events that we can attach to.

Look for something like this:
```
KERNEL[1741870.274946] remove   /devices/pci0000:00/0000:00:14.0/usb1/1-4/1-4:1.0 (usb)
ACTION=remove
DEVPATH=/devices/pci0000:00/0000:00:14.0/usb1/1-4/1-4:1.0
SUBSYSTEM=usb
DEVTYPE=usb_interface
PRODUCT=46d/c52b/1211
TYPE=0/0/0
INTERFACE=3/1/1
MODALIAS=usb:v046DpC52Bd1211dc00dsc00dp00ic03isc01ip01in00
SEQNUM=183078
```
The PRODUCT seems to be unique to my USB dongle and correlates with the output
of `lsusb`:
```
Bus 001 Device 049: ID 046d:c52b Logitech, Inc. Unifying Receiver
```

## udev Rules
```
ACTION=="add", SUBSYSTEM=="usb", ENV{PRODUCT}=="46d/c52b/1211",
  RUN+="/bin/sh /usr/local/bin/ddcswitch"
```

## Handler script
The script that is executed on matching events can be found here:
[ddcswitch](2_monitor_kvm/ddcswitch).  Put the file in `/usr/local/bin`

* Change the "PRODUCT" string on line 5
* Change the Feature Code and values on lines 8 and 10

Make the script executable:
```
chmod +x /usr/local/bin/ddcswitch
```

In it's default form, the script logs a lot of information to `/tmp/ddcswitch`.
If it doesn't work right away, look to this file for clues.
