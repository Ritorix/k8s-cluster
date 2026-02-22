# Quick Start Guide

This guide will get you from zero to a running Talos Kubernetes cluster with Cilium CNI in an air-gapped environment.

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] Ansible controller with required tools installed (talosctl, kubectl, helm)
- [ ] Local container registry running and accessible
- [ ] All images mirrored to local registry
- [ ] Offline Cilium Helm chart downloaded
- [ ] Nodes booted with Talos Linux ISO
- [ ] Node IP addresses documented

## Step-by-Step Deployment

### 1. Clone and Configure (5 minutes)

```bash
# Navigate to project directory
cd k8s-cluster

# Copy and edit inventory
cp inventory/hosts.yml inventory/hosts.yml
# Edit inventory/hosts.yml with your node IPs

# Edit cluster configuration
# Update group_vars/all.yml with your cluster name, versions
# Update vars/airgap.yml with your registry URL
```

### 2. Prepare Air-Gap (30-60 minutes)

```bash
# Set up local registry (if not already running)
./scripts/setup-registry.sh 5000

# Mirror all required images
export REGISTRY=registry.local:5000
./scripts/mirror-all-images.sh $REGISTRY

# Verify all images
./scripts/verify-images.sh $REGISTRY

# Ensure Cilium chart is in files/
ls -lh files/cilium-*.tgz
```

### 3. Validate Environment (2 minutes)

```bash
# Run validation playbook
ansible-playbook -i inventory/hosts.yml playbook.yml --tags validate

# You should see:
# ✓ Registry accessible
# ✓ Cilium chart found
# ✓ Sample images present
```

### 4. Deploy Cluster (10-15 minutes)

```bash
# Full deployment
ansible-playbook -i inventory/hosts.yml playbook.yml

# The playbook will:
# 1. Validate prerequisites
# 2. Generate Talos configurations with Cilium
# 3. Apply configs to all nodes
# 4. Bootstrap Kubernetes cluster
# 5. Validate deployment
```

**Alternative: Step-by-step execution**

```bash
# Run each phase separately for more control
ansible-playbook -i inventory/hosts.yml playbook.yml --tags prerequisites
ansible-playbook -i inventory/hosts.yml playbook.yml --tags generate
ansible-playbook -i inventory/hosts.yml playbook.yml --tags apply
ansible-playbook -i inventory/hosts.yml playbook.yml --tags bootstrap
ansible-playbook -i inventory/hosts.yml playbook.yml --tags validate
```

### 5. Access Cluster (1 minute)

```bash
# Export kubeconfig
export KUBECONFIG=$(pwd)/generated-configs/kubeconfig

# Verify cluster
kubectl get nodes
kubectl get pods -A

# Export talosconfig
export TALOSCONFIG=$(pwd)/generated-configs/talosconfig

# View Talos dashboard
talosctl dashboard
```

## Expected Output

### Successful Deployment

```
PLAY RECAP *********************************************************
localhost : ok=45   changed=12   unreachable=0    failed=0

Cluster Validation Complete
✓ Cluster Name: my-cluster
✓ Kubernetes Endpoint: https://192.168.1.10:6443
✓ Nodes: 6/6 Ready
✓ Cilium CNI: Running
✓ Registry: registry.local:5000
```

### Cluster Status

```bash
$ kubectl get nodes
NAME     STATUS   ROLES           AGE   VERSION
cp01     Ready    control-plane   5m    v1.31.4
cp02     Ready    control-plane   5m    v1.31.4
cp03     Ready    control-plane   5m    v1.31.4
worker01 Ready    <none>          5m    v1.31.4
worker02 Ready    <none>          5m    v1.31.4
worker03 Ready    <none>          5m    v1.31.4

$ kubectl get pods -n kube-system
NAME                     READY   STATUS    RESTARTS   AGE
cilium-xxxxx             1/1     Running   0          5m
cilium-xxxxx             1/1     Running   0          5m
cilium-operator-xxxxx    1/1     Running   0          5m
coredns-xxxxx            1/1     Running   0          5m
```

## Common Issues

### Registry Not Accessible

**Symptom**: Validation fails with registry connection error

**Solution**:
1. Check registry is running: `docker ps | grep registry`
2. Test connectivity: `curl http://registry.local:5000/v2/`
3. Check DNS resolution: `nslookup registry.local`
4. Update `/etc/hosts` if needed

### Nodes Not Reachable

**Symptom**: "Connection timed out" when applying configs

**Solution**:
1. Verify nodes are booted with Talos
2. Check network connectivity: `ping <node-ip>`
3. Verify port 50000 is accessible: `nc -zv <node-ip> 50000`
4. Check firewall rules

### Image Pull Failures

**Symptom**: Pods stuck in ImagePullBackOff

**Solution**:
1. Verify images in registry: `./scripts/verify-images.sh`
2. Check registry mirrors in machine config:
   ```bash
   talosctl get machineconfig -o yaml | grep -A 20 registries
   ```
3. View node logs: `talosctl logs -f`

### Bootstrap Hangs

**Symptom**: Playbook hangs at "Bootstrap etcd" task

**Solution**:
1. Check first control plane node status: `talosctl health`
2. View bootstrap logs: `talosctl dmesg -f`
3. Ensure only one bootstrap command was run
4. Check if cluster already exists (re-run is safe, will skip)

## Next Steps

After successful deployment:

1. **Deploy Applications**:
   ```bash
   kubectl create deployment nginx --image=registry.local:5000/library/nginx:alpine
   ```

2. **Configure Network Policies**:
   - See Cilium documentation for network policy examples
   - Implement pod-to-pod security

3. **Set Up Monitoring**:
   - Deploy Prometheus/Grafana
   - Enable Hubble for network observability

4. **Backup Secrets**:
   ```bash
   # Encrypt secrets bundle
   ansible-vault encrypt generated-configs/secrets.yaml
   
   # Backup to secure location
   cp generated-configs/secrets.yaml /secure/backup/location/
   ```

5. **Document Your Environment**:
   - Node IP addresses
   - Registry URL and credentials
   - Cluster endpoint
   - Any custom configurations

## Getting Help

- Check logs: `talosctl logs -f --nodes <node-ip>`
- View events: `kubectl get events -A --sort-by='.lastTimestamp'`
- Cilium status: `kubectl exec -n kube-system <cilium-pod> -- cilium status`
- Talos health: `talosctl health --nodes <node-ip>`

## Time Estimates

- **First-time setup** (with image mirroring): 1-2 hours
- **Subsequent deployments** (images cached): 15-20 minutes
- **Add worker node**: 5 minutes
- **Cluster upgrade**: 20-30 minutes

## Reference

- Full documentation: [README.md](../README.md)
- Air-gap setup: [AIRGAP.md](AIRGAP.md)
- Talos docs: https://www.talos.dev/
- Cilium docs: https://docs.cilium.io/
