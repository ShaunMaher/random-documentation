# Connecting to a remote SSH server with traffic tunnelled over MeshCentral
The MeshCentralRouter.exe Windows tool seems to work OK over wine.

## Prerequsites
* Install wine
* Install socat
* `freeport` script (TODO: include script here somewhere)

## `~/.ssh/config` snippet

This is a work in progress!

* It doesn't really detect when MeshCentralRouter makes the connection.  It just loops socat until it connects.  Infinite loop if you cancel the MeshCentralRouter dialog.  Working out how to get the MeshCentralRouter "-debug" option and parsing a log would be better.
* It starts a new MeshCentralRouter instance for each SSH connection.

```
Host <target hostname>
  user    <username>
  ProxyCommand  bash -c 'TMPLOG=$(mktemp); PORT=$(freeport); echo "${TMPLOG}" >/dev/tty; nohup wine Z:\\home\\work\\Downloads\\MeshCentralRouter.exe -map:TCP:${PORT}:<name in meshcentral>::22 -tray >${TMPLOG} 2>${TMPLOG} & loop=1; while [ $loop -gt 0 ]; do socat tcp:127.0.0.1:${PORT} STDIO 2>/dev/tty; loop=$?; sleep 0.5; done' 2>/dev/tty
```