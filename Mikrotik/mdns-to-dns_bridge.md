# MDNS-to-DNS bridge
## Purpose
TODO

## Installation
```
sudo apt install git npm nodejs
sudo mkdir /var/lib/dns-to-mdns
cd /var/lib/dns-to-mdns
git clone https://github.com/hardillb/dns-to-mdns.git .
sudo npm install
sudo npm audit fix
```

### A quick test
```
zentyal@ad2:~$ nslookup
> t14.local
Server:         127.0.0.1
Address:        127.0.0.1#53

** server can't find t14.local: SERVFAIL
> server 127.0.0.1
Default server: 127.0.0.1
Address: 127.0.0.1#53
> set port=5300
> t14.local
Server:         127.0.0.1
Address:        127.0.0.1#5300

Non-authoritative answer:
Name:   t14.local
Address: 172.30.1.27
```

## DNS Server Configuration
