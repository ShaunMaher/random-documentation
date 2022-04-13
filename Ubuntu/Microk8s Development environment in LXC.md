# Microk8s Development environment in LXC
## Install LXC
TODO

## Add the Microk8s profile
*Reference*: https://microk8s.io/docs/lxd
### For ext4
```
lxc profile create microk8s
wget https://raw.githubusercontent.com/ubuntu/microk8s/master/tests/lxc/microk8s.profile -O microk8s.profile
cat microk8s.profile | lxc profile edit microk8s
rm microk8s.profile
```

### For zfs
```
lxc profile create microk8s
wget https://raw.githubusercontent.com/ubuntu/microk8s/master/tests/lxc/microk8s-zfs.profile -O microk8s.profile
cat microk8s.profile | lxc profile edit microk8s
rm microk8s.profile
```

## Create the LXC container
```
CNAME="microk8s"
lxc launch -p default -p microk8s ubuntu:20.04 ${CNAME}
```

## Configure DNS (systemd-resolve is not suitable)
```
lxc exec ${CNAME} -- unlink /etc/resolv.conf
lxc exec ${CNAME} -- bash -c "echo 'nameserver 1.1.1.1' > /etc/resolv.conf"
lxc exec ${CNAME} -- bash -c "echo 'nameserver 8.8.8.8' >> /etc/resolv.conf"
lxc exec ${CNAME} -- bash -c "echo '127.0.1.1 ${CNAME}' >> /etc/hosts"
```

## Install microk8s from snap into the container
```
lxc exec ${CNAME} -- apt install -y apparmor-utils
lxc exec ${CNAME} -- sudo snap install microk8s --classic
lxc exec ${CNAME} -- sudo snap alias microk8s.kubectl kubectl
```

## Install microk8s plugins (optional but recommended)
```
lxc exec ${CNAME} -- sudo microk8s enable helm3
lxc exec ${CNAME} -- sudo microk8s enable dashboard
lxc exec ${CNAME} -- sudo microk8s kubectl port-forward -n kube-system service/kubernetes-dashboard 10443:443
lxc exec ${CNAME} -- sudo microk8s enable ingress
lxc exec ${CNAME} -- sudo microk8s enable storage
```
```
lxc exec ${CNAME} -- sudo microk8s kubectl get pod --all-namespaces
```
Wait until all pods are "running", then:
```
lxc exec ${CNAME} -- sudo microk8s kubectl port-forward -n kube-system service/kubernetes-dashboard 10443:443
```

### TODO: Dashboard ingress rule
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard-nginx-ingress
  namespace: kube-system
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: "public"
  rules:
  - host: microk8s.local
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: kubernetes-dashboard
              port:
                number: 443
```

## Install helm (optional but recommended)
```
lxc exec ${CNAME} -- sudo snap install helm --classic
```

## Start the dashboard-proxy
*TODO* make a systemd unit? - Use ingress above instead
```
lxc exec ${CNAME} -- microk8s dashboard-proxy
```

## Container shutdown script
`/etc/systemd/system/microk8s-killall.service`
```
[Unit]
Description=Kill containerd-shims on shutdown
DefaultDependencies=false
Before=shutdown.target umount.target

[Service]
ExecStart=/bin/bash -c "/usr/local/bin/microk8s-killall.sh"
Type=oneshot

[Install]
WantedBy=shutdown.target
```

`/usr/local/bin/microk8s-killall.sh`
```
TODO: Steal the contents of rke2-killall.sh from a Rancher node
```

## Add the subuid/subguid stuff
TODO

## Add your current user (host) into the container (mapping UIDs/GIDs)
*Reference:* https://ubuntu.com/blog/custom-user-mappings-in-lxd-containers
```
lxc config set ${CNAME} security.idmap.isolated true
lxc config set ${CNAME} security.idmap.size 200000
printf "uid $(id -u) $(id -u)\ngid $(id -g) $(id -g)" | lxc config set ${CNAME} raw.idmap -
lxc restart ${CNAME}
```

## Create your user (host) inside the container
```
lxc exec ${CNAME} -- bash -c "userdel ubuntu"
lxc exec ${CNAME} -- bash -c "groupadd -g $(id -g) $(id -gn)"
lxc exec ${CNAME} -- bash -c "useradd -u $(id -u) -g $(id -g) -m -G sudo $(id -un)"
lxc exec ${CNAME} -- bash -c "usermod -a -G microk8s $(id -un)"
lxc exec ${CNAME} -- bash -c "mkdir /home/$(id -un)/.kube"
lxc exec ${CNAME} -- bash -c "microk8s config > /home/$(id -un)/.kube/config"
lxc exec ${CNAME} -- bash -c "chown -R $(id -u):$(id -g) /home/$(id -un)/.kube/"
lxc exec ${CNAME} -- bash -c "chmod 600 /home/$(id -un)/.kube/config"
```

## Map a directory in your home directory into the container
```
lxc config device add ${CNAME} Projects disk source=/home/work/Projects path=/home/work/Projects
```

## Wrapper scripts
`${HOME}/.local/bin/microk8s`
```
#!/usr/bin/env bash

CNAME="${CNAME:-microk8s}"

lxc exec ${CNAME} --mode interactive --cwd "${PWD}" --user $(id -u) --group $(\
    lxc exec ${CNAME} -- getent group microk8s | awk 'BEGIN{FS=":"}{print $3}'
  ) --env "HOME=/home/$(id -un)" -- \
  $(basename $0) $@
```
```
chmod +x ${HOME}/.local/bin/microk8s
ln -s ${HOME}/.local/bin/microk8s .local/bin/kubectl
ln -s ${HOME}/.local/bin/microk8s .local/bin/helm
```

## Troubleshooting
### `cannot change profile for the next exec call: No such file or directory`
**Reference:** https://sleeplessbeastie.eu/2020/07/20/how-to-deal-with-missing-apparmor-profiles-for-microk8s-on-lxd/
```
lxc exec ${CNAME} -- bash -c "apparmor_parser --add /var/lib/snapd/apparmor/profiles/snap.*.*"
```
