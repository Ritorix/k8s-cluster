# Cilium Installation via CLI

This playbook uses the `cilium install` command instead of inline manifests for easier management and upgrades.

## How It Works

1. **Bootstrap Cluster**: Talos boots with CNI disabled
2. **Install Cilium**: Run `cilium install` with air-gap registry overrides
3. **Validate**: Verify Cilium is running on all nodes

## Configuring Cilium Images

All Cilium images are configured in **`vars/cilium_images.yml`**:

```yaml
# Example: Change image repositories and tags
cilium_image:
  repository: "registry.local:5000/cilium/cilium"
  tag: "v1.19.1"

operator_image:
  repository: "registry.local:5000/cilium/operator-generic"
  tag: "v1.19.1"

# Configure installation settings
cilium_install_settings:
  kube_proxy_replacement: "true"
  k8s_service_host: "localhost"
  k8s_service_port: "7445"
  tunnel: "disabled"
  ipam_mode: "kubernetes"
  enable_gateway_api: "true"  # Enables Kubernetes Gateway API support
```

### Easy Image Updates

To update Cilium or any component:

1. **Edit `vars/cilium_images.yml`**:
   ```yaml
   cilium_image:
     tag: "v1.19.2"  # Change version
   ```

2. **Reinstall**:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbook.yml --tags cilium
   ```

### Custom Registry

Change the registry for all images:

```yaml
# In vars/airgap.yml
local_registry_url: "my-registry.company.com:5000"

# All images in cilium_images.yml will use:
# my-registry.company.com:5000/cilium/cilium:v1.19.1
# my-registry.company.com:5000/cilium/operator-generic:v1.19.1
```

## Installation Phases

### Full Installation
```bash
ansible-playbook -i inventory/hosts.yml playbook.yml
```

### Step-by-Step
```bash
# 1-4: Generate configs and bootstrap
ansible-playbook -i inventory/hosts.yml playbook.yml --tags bootstrap

# 5: Install Cilium
ansible-playbook -i inventory/hosts.yml playbook.yml --tags cilium

# 6: Validate
ansible-playbook -i inventory/hosts.yml playbook.yml --tags validate
```

### Reinstall Cilium Only
```bash
# Delete existing Cilium
kubectl delete namespace cilium --ignore-not-found
kubectl delete daemonset cilium -n kube-system --ignore-not-found

# Reinstall
ansible-playbook -i inventory/hosts.yml playbook.yml --tags cilium
```

## Upgrading Cilium

### Method 1: Via Ansible

1. Update `vars/cilium_images.yml`:
   ```yaml
   cilium_image:
     tag: "v1.20.0"  # New version
   
   operator_image:
     tag: "v1.20.0"
   ```

2. Run upgrade:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbook.yml --tags cilium
   ```

### Method 2: Direct CLI

```bash
export KUBECONFIG=configs/kubeconfig

cilium upgrade \
  --version 1.20.0 \
  --set image.repository=registry.local:5000/cilium/cilium \
  --set image.tag=v1.20.0 \
  --set operator.image.repository=registry.local:5000/cilium/operator-generic \
  --set operator.image.tag=v1.20.0
```

## Connectivity Testing

Enable connectivity testing:

```yaml
# In group_vars/all.yml or at runtime
run_connectivity_test: true
```

Or run manually:
```bash
cilium connectivity test
```

## Troubleshooting

### Check Cilium Status
```bash
export KUBECONFIG=configs/kubeconfig
cilium status
```

### View Cilium Pods
```bash
kubectl get pods -n kube-system -l k8s-app=cilium
```

### Check Installation Logs
```bash
kubectl logs -n kube-system daemonset/cilium
```

### Reinstall from Scratch
```bash
# Remove Cilium completely
kubectl delete namespace cilium
kubectl delete daemonset/cilium -n kube-system
kubectl delete deployment/cilium-operator -n kube-system

# Reinstall
ansible-playbook -i inventory/hosts.yml playbook.yml --tags cilium
```

## Advanced Configuration

### Add Custom Helm Values

Edit `roles/install_cilium/tasks/main.yml` and add `--set` flags:

```yaml
--set myCustomValue=true \
--set another.nested.value=123 \
```

### Multiple CNI Options

To switch CNI mode, edit `cilium_install_settings`:

```yaml
cilium_install_settings:
  tunnel: "vxlan"        # or "disabled" for native routing
  ipam_mode: "cluster-pool"  # or "kubernetes"
```

## Benefits of CLI Installation

✅ **Easy upgrades** - Just change version and rerun
✅ **Simple configuration** - All images in one file
✅ **Better debugging** - cilium CLI provides clear status
✅ **Flexible** - Easy to customize settings
✅ **No helm template complexity** - Direct CLI installation
