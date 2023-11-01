# Using TCPDump to inspect network traffic inside a Kubernetes pod

```
kubectl debug -it <pod name> -n <pod namespace> --image=dockersec/tcpdump --target <container name> -- bash
```