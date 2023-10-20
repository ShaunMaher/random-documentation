# KDE Plasma User session in a Network Namespace

> **Work in progress**

I would like to be able to be able to run a KDE Plasma session in a Network
Namespace.  I would like each user that logs in to have their own Network
Namespace so that, for example, my "work" user is tied to it's own VLAN and can
start VPN connections that are not available to other users.  My non-work user
sould be able to log in and get access to my home VLAN but not access any
"work" resources over the "work" VPN.

Ideally, this should extend to all sessions (e.g. SSH sessions), not just
Plasma sessions.

What works:
* Getting a single X11 Plasma session, in a Network Namespace

What doesn't work (yet):
* SDDM or any other Display Manager (i.e. graphical login)
* Convienience.  The process of starting the namespace and the Xorg session are
  entirely manual.
* Wayland (preferred as I would like to experiment with waypipe)
* Other session types, for example SSH/XPRA/Console.

## Don't use the Systemd resolver
Processes inside the Network Namespace won't have access to the
Systemd-Resolved service listening on the loopback interface.  They need a
resolv.conf that points to a real DNS resolver thay can use.

```bash
sudo unlink /etc/resolv.conf
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo sed -i 's/^.*DNSStubListener=.*/DNSStubListener=no/g' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
```

In future, replace the above with a namespace specific resolv.conf so the host
OS doesn't need the above modification.

## Create bridges
The "host" operating system (KDE Neon) has two network interfaces, one on the
LAN vLAN and one on the WORK vLAN.  The following sets up a bridge that has the
interface connected to the WORK vLAN as a member.

```bash
BRNAME="WORK"
PHYINT="enp10s0"
sudo nmcli con down 'Wired connection 1'
sudo nmcli con delete 'Wired connection 1'
sudo nmcli con add type bridge ifname br${BRNAME} con-name br${BRNAME}
sudo nmcli con add type bridge-slave ifname ${PHYINT} con-name ${PHYINT} master br${BRNAME}
sudo nmcli connection modify br${BRNAME} connection.autoconnect-slaves 1
sudo nmcli connection modify br${BRNAME} connection.autoconnect-retries 0
sudo nmcli connection modify br${BRNAME} bridge.stp no
sudo nmcli connection modify br${BRNAME} ipv4.method auto
sudo nmcli connection up br${BRNAME}
```

Repeat for the LAN interface.

## Create the namespace manually
Outside the Network Namespace, a virtual network adapter will be created called
"netns-<username>" and added to the appropraite bridge.

Inside the Network Namespace, there will be other end of the virtual network
adapter called just "<username>"

This convention should make it obvious which adapters belong to what users.

```bash
NSUSER="work"
BRNAME="WORK"
sudo ip netns add "${NSUSER}"
sudo ip link add "${NSUSER}" type veth peer name "netns-${NSUSER}"
sudo ip link set "${NSUSER}" netns "${NSUSER}"
sudo nmcli con delete "netns-${NSUSER}"
sudo nmcli con add type bridge-slave ifname "netns-${NSUSER}" con-name "netns-${NSUSER}" master br${BRNAME}
sudo nmcli con up "netns-${NSUSER}"
sudo ip netns exec "${NSUSER}" bash
```

Now, inside the namespace (assuming you have a DHCP service on this VLAN)
```bash
dhclient $(id -un)
```

## Start an X session
Edit `/etc/X11/Xwrapper.config`.  Change
```
allowed_users=console
```
to
```
allowed_users=anybody
```

```bash
sudo usermod -a -G video "${NSUSER}"
sudo usermod -a -G input "${NSUSER}"
sudo usermod -a -G tty "${NSUSER}"
sudo chmod g+rw /dev/tty*
```

The following needs to be run from the console of the host
```bash
sudo ip netns exec "${NSUSER}" bash
```
```bash
runuser -u work startx
```
