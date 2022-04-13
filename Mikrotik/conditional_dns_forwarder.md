# Conditional DNS forwarder on Mikrotik RouterOS
TODO: description and references

## Layer 7 Rule
**Reference:** https://forum.mikrotik.com/viewtopic.php?t=109657

This Layer 7 rule might be different to others you find online.  Other guides
more broadly catch any DNS traffic (port 53) that contains your target domain
anywhere in the packet.  I found that this had the adverse reaction of causing
seemingly unrelated DNS requests to the forward server.  This is because
requests **from** "my-laptop.ad.ghanima.net" might match the rule.

Under normal conditions this wouldn't be an issue but the undesirable result
was that, if the forward server is offline, all of these unrelated DNS requests
would also fail.

Because you're not expecting the unrelated requests to be going to your forward
server, you might consider it as being your issue when your network DNS starts
playing up.

This rule more specifically looks for some DNS query protocol stuff that
indicates that it's specifically a request **for** ad.ghanima.net.

Here are the parts of the regex:
* `\\x02`: The following 2 bytes (represented by a literal hex 2) are the first
  domain name segment of the query.
* `ad`: The first domain name segment of the query (2 bytes long)
* `\\x07`: The following 7 bytes (represented by a literal hex 7) are the next
  domain name segment of the query.
* `ghamina`: The next domain name segment of the query (7 bytes long)
* `\\x03`: The following 3 bytes (represented by a literal hex 3) are the next
  domain name segment of the query.
* `net`: The final domain name segment of the query (3 bytes long)
* `.`: Match any single charactor.  I think this is always a NULL and the
  Mikrotik regex parser has trouble with NULL so we just match any single byte.
* `\\x01`: Query Class (IN).  This is the key to avoiding unrelated DNS
  requests matching.  Unrelated requests might contain "ad.ghanima.net" but
  they are unlikely to have the specific combination of "ad.ghanima.net"
  followed by hex 01.

```
/ip firewall layer7-protocol
add name=ad.ghanima.net regexp="\\x02ad\\x07ghanima\\x03net.\\x01"
```

## Mangle Rules
The mangle rules look for packets on UDP or TCP port 53 that match the above
Layer 7 rule and give them a unique connection mark ("ad.ghanima.net-forward").
```
/ip firewall mangle
add action=mark-connection chain=prerouting comment="Mark TCP DNS (port 53) packets that match the ad.ghanima.net Layer 7 rule" dst-port=53 \
    layer7-protocol=ad.ghanima.net new-connection-mark=ad.ghanima.net-forward passthrough=yes protocol=tcp
add action=mark-connection chain=prerouting comment="Mark UDP DNS (port 53) packets that match the ad.ghanima.net Layer 7 rule" dst-port=53 \
    layer7-protocol=ad.ghanima.net new-connection-mark=ad.ghanima.net-forward passthrough=yes protocol=udp
```

## NAT Rules
Finally a NAT rule looks for the connection mark and changes the destination of
the UDP/TCP packet to the IP of the local forward server.  Masquerading the
source ensures the reply from the forward server is properly sent back to this
router (avoiding any asymetric routes).
```
add action=dst-nat chain=dstnat comment="Send any DNS packets with the \"ad.ghanima.net-forward\" mark to ad2.ad.ghanima.net" connection-mark=\
    ad.ghanima.net-forward to-addresses=172.30.0.14
add action=masquerade chain=srcnat comment=\
    "Masquarade any DNS packets with the \"ad.ghanima.net-forward\" mark so the return packets are properly routed" connection-mark=\
    ad.ghanima.net-forward
```
