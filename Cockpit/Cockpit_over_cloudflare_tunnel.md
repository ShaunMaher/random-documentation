## 403 error on wss://<fqdn>/cockpit/socket
**Reference:** https://github.com/cockpit-project/cockpit/issues/16396

Add to `/etc/cockpit/cockpit.conf` (create if it doesn't exist):
```
[WebService]
Origins = https://cockpit-cvhn51.mach.net.au wss:\/\/cockpit-cvhn51.mach.net.au
ProtocolHeader = X-Forwarded-Proto
AllowUnencrypted = true
```

Restart the `cockpit` service
```
sudo systemctl restart cockpit
```