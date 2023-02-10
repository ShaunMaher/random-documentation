## Extra packages
### Apt
#### Built-in Repositories
* apt-transport-https
* avahi-daemon
* bind9-dnsutils
* bridge-utils
* build-essential
* curl
* ddcutil
* dmsetup
* flatpak
* git
* gnome-keyring
* kcalc
* kexec-tools
* mbuffer
* qemu-system-x86
* qemu-utils
* sanoid
* socat
* tcpdump
* libsecret-1-0
* libsecret-1-dev
* libglib2.0-dev
* libvirt-clients
* libvirt-daemon
* libvirt-daemon-driver-qemu
* tmux
* ufw
* virt-manager
* vim
* vlc
* vokoscreen-ng
* wireguard-tools
* wireshark-qt
* xdotool
* zsh

#### From Extra Repositories
**Note:** Should these be pulled into the custom repo for simplicity

* terraform
  **Reference:** https://developer.hashicorp.com/terraform/downloads
  ```
  wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com jammy main" | \
    sudo tee -a /etc/apt/sources.list.d/hashicorp.list
  apt update
  apt install -y terraform
  ```

* xpra
  **Reference:** https://github.com/Xpra-org/xpra/wiki/Download#-linux
  ```bash
  wget -O- https://xpra.org/xpra-2022.gpg | \
    sudo tee /usr/share/keyrings/xpra-2022.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/xpra-2022.gpg] https://xpra.org/ jammy main" | \
    sudo tee -a /etc/apt/sources.list.d/xpra.list
  apt update
  apt install -y xpra
  ```

* signal
  **Reference:** https://signal.org/en/download/linux/
  ```bash
  wget -O- https://updates.signal.org/desktop/apt/keys.asc | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" | \
    sudo tee -a /etc/apt/sources.list.d/signal.list
  apt update
  apt install -y signal-desktop
  ```

* cloudflared
  **Reference:** https://pkg.cloudflare.com/index.html
  ```bash
  wget -O- https://pkg.cloudflare.com/cloudflare-main.gpg | \
    sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared jammy main" | \
    tee /etc/apt/sources.list.d/cloudflare.list
  apt update; apt install -y cloudflared
  ```

* vscode
  ```bash
  wget -O- https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor | \
    sudo tee /usr/local/share/keyrings/vscode.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/usr/local/share/keyrings/vscode.gpg] https://packages.microsoft.com/repos/vscode stable main" | \
    tee /etc/apt/sources.list.d/vscode.list
  apt update; apt install -y code
  ```

#### Custom Repo
```bash
GIT_LOGIN_USER="work"
GIT_TOKEN="1jhzomRhTzsRzqeXu2Hw"
CODENAME="jammy"
PROJECT_NAME="work-laptop"
PROJECT_ID="48"
echo "machine git.ghanima.net login ${GIT_LOGIN_USER} password ${GIT_TOKEN}" | \
  sudo tee /etc/apt/auth.conf.d/${PROJECT_NAME}.conf
sudo mkdir -p /usr/local/share/keyrings
curl --header "PRIVATE-TOKEN: ${GIT_TOKEN}" \
      "https://git.ghanima.net/api/v4/projects/${PROJECT_ID}/debian_distributions/${CODENAME}/key.asc" \
      | \
      gpg --dearmor \
      | \
      sudo tee /usr/local/share/keyrings/${PROJECT_NAME}-${CODENAME}-archive-keyring.gpg \
      >/dev/null
echo "deb [ signed-by=/usr/local/share/keyrings/${PROJECT_NAME}-${CODENAME}-archive-keyring.gpg ] https://git.ghanima.net/api/v4/projects/${PROJECT_ID}/packages/debian ${CODENAME} main" \
   | sudo tee /etc/apt/sources.list.d/${PROJECT_NAME}.list
apt install signal-desktop cloudflared code terraform forticlient webex icaclient cfs-zen-tweaks
```

* [x] webex
* [x] Citrix ICA client
* [x] cisco-amp
* [x] forticlient
* [x] cfs-zen-tweaks

### Flatpak
#### (--user)
```
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

* com.jgraph.drawio.desktop
  `flatpak install --user com.jgraph.drawio.desktop`
* org.gimp.GIMP
  `flatpak install --user org.gimp.GIMP`
* org.libreoffice.LibreOffice
  `flatpak install --user org.libreoffice.LibreOffice`

### Snap
* chromium
* keeweb
* lxd
* winbox

## Oh-My-ZSH
```
wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O - | sh
sed -i 's/ZSH_THEME=.*/ZSH_THEME="agnoster"/g' ${HOME}/.zshrc;
sed -i 's/plugins=(/plugins=(zsh-autosuggestions /g' ${HOME}/.zshrc
git clone https://github.com/zsh-users/zsh-autosuggestions ${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions
```

## Chromium under xpra
```
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1002/bus"
xhost + local:
```