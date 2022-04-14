# Setup DNS for your RKE2 Cluster
Your RKE2/Rancher nodes need to be able to find each other by name.  This means
DNS.

I generally like to install and configure the Avahi Daemon so that things can
just find each other automagically but this doesn't work for RKE2.  We need
another solution.

Unless your solution involves dynamic DNS registration (probably not), now is
the time to think about IP allocations.  You can either:
* Use Static IPs
  * Should be in the same subnet as the rest of the LAN you're connecting to,
    unless you are deliberately segregating things (e.g. in a seperate VLAN)
  * Should be excluded from the network's DHCP pool to avoid conflicts
* Use DHCP and/or IPv6 Auto Configuration (my preference)
  * DHCP leases should be made static/persistant in your DHCP server.  Not all
    (read: cheap/simple) DHCP servers (e.g. in home routers) suppport this.
  * **TODO:** IPv6 Auto Configuration IPs are generally not static.  How do we
    deal with this?

### LAN DNS Server: Microsoft Active Directory DNS Server
If your network already has an Active Directory, you might as well use it's DNS
server.
* Create a new "Forward Lookup" zone (unless the zone you want to use already
  exists)
* Create A or AAAA records for each VM's hostname pointing at the VM's IP.

### LAN DNS Server: Zentyal
**TODO**

### LAN DNS Server: Samba 4 (internal or bind)
**TODO**

### LAN Router: Mikrotik
```
/ip dns static
add address=172.30.1.94 name=rke1.ghanima.net ttl=1h
add address=172.30.1.95 name=rke2.ghanima.net ttl=1h
add address=172.30.1.93 name=rke3.ghanima.net ttl=1h
```

### LAN Router: opnSense
**TODO**

### LAN Router: pfSense
**TODO**

### If all else fails: `hosts` file entries
**TODO**
