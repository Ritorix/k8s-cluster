# Quick Reference: Image Configuration

All Cilium component images are configured in a single file for easy management.

## File Location

**`vars/cilium_images.yml`** ← Edit this file to change any image

## Quick Examples

### Change Cilium Version

```yaml
cilium_image:
  repository: "registry.local:5000/cilium/cilium"
  tag: "v1.20.0"  # ← Change this

operator_image:
  repository: "registry.local:5000/cilium/operator-generic"
  tag: "v1.20.0"  # ← Change this
```

### Use Different Registry

```yaml
# In vars/airgap.yml, change:
local_registry_url: "my-registry.company.com:5000"

# All images automatically use new registry:
# my-registry.company.com:5000/cilium/cilium:v1.19.1
# my-registry.company.com:5000/cilium/operator-generic:v1.19.1
```

### Use Specific Image Builds

```yaml
envoy_image:
  repository: "registry.local:5000/cilium/cilium-envoy"
  tag: "v1.35.9-custom-build-abc123"  # ← Custom build tag
```

### Change Component Repository

```yaml
hubble_ui_frontend_image:
  repository: "registry.local:5000/my-custom/hubble-ui"  # ← Different repo
  tag: "v0.13.1"
```

## Installation Settings

```yaml
cilium_install_settings:
  kube_proxy_replacement: "true"   # eBPF kube-proxy
  k8s_service_host: "localhost"    # KubePrism
  k8s_service_port: "7445"         # KubePrism port
  tunnel: "disabled"               # Native routing
  ipam_mode: "kubernetes"          # Kubernetes IPAM
```

## After Changes

```bash
# Mirror new images
./scripts/mirror-all-images.sh registry.local:5000

# Reinstall/upgrade Cilium
ansible-playbook -i inventory/hosts.yml playbook.yml --tags cilium
```

## All Available Images

| Component | Variable | Default Tag |
|-----------|----------|-------------|
| Cilium | `cilium_image` | v1.19.1 |
| Operator | `operator_image` | v1.19.1 |
| Hubble Relay | `hubble_relay_image` | v1.19.1 |
| Hubble UI Backend | `hubble_ui_backend_image` | v0.13.1 |
| Hubble UI Frontend | `hubble_ui_frontend_image` | v0.13.1 |
| Envoy | `envoy_image` | v1.35.9-* |
| Cert Generator | `certgen_image` | v0.3.2 |

See `vars/cilium_images.yml` for complete configuration.
