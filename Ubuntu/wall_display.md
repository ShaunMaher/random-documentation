# Ubuntu powered Wall Display using Systemd
Setup a wall display machine that is intended to operate without a user.  It
opens a Browser and displays a web page full screen and boarderless.

I set this up ages ago and didn't document it as I went so these instructions
are incomplete.

```
loginctl enable-linger <the target user>
sudo systemctl disable sddm
systemctl --user enable xorg@0.socket
systemctl --user enable xorg@0.service
systemctl --user set-environment XDG_VTNR=1
systemctl --user enable ratpoison
systemctl --user enable firefox-kiosk
systemctl --user enable unclutter
```