As a temporary solution to needing a load balancer in front of the Rancher
cluster, it's possible to use a simple Ubuntu VM or LXC container with HAProxy
and certbot installed.

## Certbot: Get a certificate
```
certbot certonly --standalone --http-01-port 8080 --http-01-address 127.0.0.1 -d rke.ghanima.net
cat /etc/letsencrypt/live/rke.ghanima.net/fullchain.pem /etc/letsencrypt/live/rke.ghanima.net/privkey.pem >/etc/letsencrypt/live/rke.ghanima.net/haproxy.pem
```
