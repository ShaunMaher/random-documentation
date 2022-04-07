# K3s Development environment in LXC
## Notes
I tried to use this to create a K3s cluster and install Rancher.  This mostly
worked but Longhorn would get stuck attaching disks and I coundn't work out
why.  I ended up switching to using VMs with RKE2 instead.

This implementation should still be a very usable single node development
environment.

## Install LXC

**TODO**

### Increase kernel limits
**Reference:** https://linuxcontainers.org/lxd/docs/master/production-setup/

`/etc/sysctl.d/90-lxd-limits.conf`
```
fs.aio-max-nr = 524288
fs.inotify.max_queued_events = 1048576
fs.inotify.max_user_instances = 1048576
fs.inotify.max_user_watches = 1048576
kernel.dmesg_restrict = 1
kernel.keys.maxbytes = 2000000
kernel.keys.maxkeys = 2000
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv6.neigh.default.gc_thresh3 = 8192
vm.max_map_count = 262144
```
Reboot the server

## Add the Microk8s profile (which we're re-purposing)
**Reference**: https://microk8s.io/docs/lxd

### For ext4

```
lxc profile create k8s
wget https://raw.githubusercontent.com/ubuntu/microk8s/master/tests/lxc/microk8s.profile -O microk8s.profile
cat microk8s.profile | lxc profile edit k8s
rm microk8s.profile
```

### For zfs

```
lxc profile create k8s
wget https://raw.githubusercontent.com/ubuntu/microk8s/master/tests/lxc/microk8s-zfs.profile -O microk8s.profile
cat microk8s.profile | lxc profile edit k8s
rm microk8s.profile
```

## Create the LXC container

```
CNAME="$(hostname)-k3s"
lxc launch -p default -p k8s ubuntu:20.04 ${CNAME}
```

## Configure DNS (systemd-resolve is not suitable)

```
lxc exec ${CNAME} -- unlink /etc/resolv.conf
lxc exec ${CNAME} -- bash -c "echo 'nameserver 1.1.1.1' > /etc/resolv.conf"
lxc exec ${CNAME} -- bash -c "echo 'nameserver 8.8.8.8' >> /etc/resolv.conf"
lxc exec ${CNAME} -- bash -c "echo '127.0.1.1 ${CNAME}' >> /etc/hosts"
```

## Install k3s into the container
**Reference:** https://github.com/corneliusweig/kubernetes-lxd/blob/master/README-k3s.md

```
lxc exec ${CNAME} -- apt install -y apparmor-utils avahi-daemon
lxc exec ${CNAME} -- bash -c "echo 'L /dev/kmsg - - - - /dev/console' > /etc/tmpfiles.d/kmsg.conf"
```

First node in a new cluster
```
lxc exec ${CNAME} -- bash -c "curl -sfL https://get.k3s.io | sh -s - server --snapshotter=native --disable traefik"
lxc exec ${CNAME} -- k3s kubectl get pods --all-namespaces
```

### Shutdown script
**Reference:** https://github.com/k3s-io/k3s/issues/2400

By default, when the LXC container (or VM or OS on metal) is shut down, no
action is taken to shut down the running containers.  This adds a huge delay to
the shutdown process.  The following resolves the issue.

`/etc/systemd/system/cgroup-kill-on-shutdown@.service`
```
[Unit]
Description=Kill cgroup procs on shutdown for %i
DefaultDependencies=false
Before=shutdown.target umount.target
[Service]
# Instanced units are not part of system.slice for some reason
# without this, the service isn't started at shutdown
Slice=system.slice
ExecStart=/bin/bash -c "/usr/local/bin/k3s-killall.sh"
Type=oneshot
[Install]
WantedBy=shutdown.target
```
```
lxc exec ${CNAME} -- systemctl enable cgroup-kill-on-shutdown@k3s.service
```

## *Optional:* Install Helm

```
lxc exec ${CNAME} -- snap install helm --classic
lxc exec ${CNAME} -- bash -c "mkdir -p \${HOME}/.kube/; cat /etc/rancher/k3s/k3s.yaml > \${HOME}/.kube/config"
lxc exec ${CNAME} -- bash -c "chmod 600 \${HOME}/.kube/config"
```

## *Optional:* Nginx Ingress

```
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set service.type=LoadBalancer
```

### Issue: `svclb-ingress-nginx-controller-xxxxx` won't start
**TODO:** Apply the following in a persistent manner:

```
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
```

## *Optional:* K8s Dashboard

```
lxc exec ${CNAME} -- bash
```
```
GITHUB_URL=https://github.com/kubernetes/dashboard/releases
VERSION_KUBE_DASHBOARD=$(curl -w '%{url_effective}' -I -L -s -S ${GITHUB_URL}/latest -o /dev/null | sed -e 's|.*/||')
sudo k3s kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/${VERSION_KUBE_DASHBOARD}/aio/deploy/recommended.yaml
```

```
vim dashboard.admin-user.yml
```
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
```

```
vim dashboard.admin-user-role.yml
```
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```

```
k3s kubectl create -f dashboard.admin-user.yml -f dashboard.admin-user-role.yml
```

### Ingress (assuming you installed the Nginx ingress controller)

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard-nginx-ingress
  namespace: kubernetes-dashboard
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - host: e7470-k3s.local
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

## *Optional:* Add your current user (host) into the container (mapping UIDs/GIDs)
*Reference:* https://ubuntu.com/blog/custom-user-mappings-in-lxd-containers

```
lxc config set ${CNAME} security.idmap.isolated true
lxc config set ${CNAME} security.idmap.size 200000
printf "uid $(id -u) $(id -u)\ngid $(id -g) $(id -g)" | lxc config set ${CNAME} raw.idmap -
lxc restart ${CNAME}
```

## *Optional:* Create your user (host) inside the container

```
lxc exec ${CNAME} -- bash -c "groupadd -r k3s"
lxc exec ${CNAME} -- bash -c "chown root:k3s /etc/rancher/k3s/k3s.yaml"
lxc exec ${CNAME} -- bash -c "chmod g+r /etc/rancher/k3s/k3s.yaml"
lxc exec ${CNAME} -- bash -c "userdel ubuntu"
lxc exec ${CNAME} -- bash -c "groupadd -g $(id -g) $(id -gn)"
lxc exec ${CNAME} -- bash -c "useradd -u $(id -u) -g $(id -g) -m -G sudo $(id -un)"
lxc exec ${CNAME} -- bash -c "usermod -a -G k3s $(id -un)"
lxc exec ${CNAME} -- bash -c "mkdir /home/$(id -un)/.kube"
lxc exec ${CNAME} -- bash -c "cat /etc/rancher/k3s/k3s.yaml > /home/$(id -un)/.kube/config"
lxc exec ${CNAME} -- bash -c "chown -R $(id -u):$(id -g) /home/$(id -un)/.kube/"
```

## *Optional:* Map a directory in your home directory into the container

```
lxc config device add ${CNAME} Projects disk source=/home/work/Projects path=/home/work/Projects
```

## *Optional:* Wrapper scripts

`${HOME}/.local/bin/k3s`
```
#!/usr/bin/env bash

CNAME="${CNAME:-e7470-k3s}"

lxc exec ${CNAME} --mode interactive --cwd "${PWD}" --user $(id -u) --group $(\
    lxc exec ${CNAME} -- getent group k3s | awk 'BEGIN{FS=":"}{print $3}'
  ) --env "HOME=/home/$(id -un)" -- \
  $(basename $0) $@
```
```
chmod +x ${HOME}/.local/bin/microk8s
ln -s ${HOME}/.local/bin/microk8s .local/bin/kubectl
ln -s ${HOME}/.local/bin/microk8s .local/bin/helm
```
