# Ubuntu Unattended-Upgrades (with optional automatic reboot)
## Install the packages
**Reference:** https://help.ubuntu.com/community/AutomaticSecurityUpdates
```
DEBIAN_FRONTEND=noninteractive sudo apt install -y unattended-upgrades
```

## Enable
**Reference:** https://wiki.debian.org/UnattendedUpgrades
```
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | sudo debconf-set-selections
sudo dpkg-reconfigure -f noninteractive unattended-upgrades
```

## *Optional:* Install regular (i.e. not just secuity) updates
```
sudo sed -i -e 's/\/\/.*"${distro_id}:${distro_codename}-updates";/\t"${distro_id}:${distro_codename}-updates";/g' /etc/apt/apt.conf.d/50unattended-upgrades
```

## *Optional:* Eanble Automatic Reboot
**Reference:** https://www.cyberciti.biz/faq/how-to-set-up-automatic-updates-for-ubuntu-linux-18-04/
```
echo 'Unattended-Upgrade::Automatic-Reboot "true";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades
```
