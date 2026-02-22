# Talos Kubernetes Cluster with Cilium CNI

Ansible playbook for deploying a production-ready Kubernetes cluster on Talos Linux with Cilium CNI. Supports both **air-gapped** and **internet-connected** deployments.

## Features

- **Flexible deployment** - air-gapped or internet-connected mode
- **Cilium CNI** installed via CLI for easy management
- **Simple image configuration** - define all images in one file
- **Customizable cluster size** via inventory file
- **Registry mirrors** for air-gapped deployments
- **Easy upgrades** - just change versions and rerun
- **Idempotent** playbook execution

## Architecture

- **Talos Linux**: Immutable Kubernetes OS
- **Cilium**: Modern eBPF-based CNI with kube-proxy replacement
- **KubePrism**: Talos local API server proxy for HA
- **CLI Installation**: Post-bootstrap Cilium deployment

## Deployment Modes

Choose the deployment mode that fits your environment:

| Feature | Internet-Connected | Air-Gapped |
|---------|-------------------|------------|
| **Setup Complexity** | Simple | Moderate |
| **Local Registry** | Not needed | Required |
| **Image Mirroring** | Not needed | Required |
| **Network Access** | Public registries | Isolated |
| **Best For** | Most environments | Secure/isolated networks |

### Internet-Connected (Default)
- Images pulled directly from public registries (quay.io, registry.k8s.io, ghcr.io)
- No local registry required
- Simpler setup for most environments
- Set `airgap_enabled: false` in `vars/airgap.yml`

### Air-Gapped
- All images served from local registry
- Requires image mirroring
- Complete network isolation
- Set `airgap_enabled: true` in `vars/airgap.yml`
- See [docs/AIRGAP.md](docs/AIRGAP.md) for setup details

## Prerequisites

### On Ansible Controller

1. **Required Tools**:
   - Ansible 2.9+
   - `talosctl` CLI (matching Talos version)
   - `kubectl` CLI
   - `cilium` CLI (for installation and management)
   - `jq` (for node status parsing)

2. **Optional Tools** (for image mirroring):
   - `skopeo` or `crane` for image copying
   - `docker` or `podman` for local image operations

### Infrastructure Requirements

1. **Nodes**:
   - 3+ control plane nodes (1 minimum, 3 recommended for HA)
   - 3+ worker nodes
   - Each node booted with Talos Linux ISO/PXE
   - DHCP-assigned or static IP addresses
   - Network connectivity on port 50000 (Talos API)

2. **Container Registry** (air-gapped only):
   - Running and accessible from all nodes
   - Sufficient storage for all required images (~5-10GB)
   - Optional: TLS with valid or self-signed certificates
   - Optional: Authentication enabled

3. **Network**:
   - Internet-connected: Nodes can reach public registries
   - Air-gapped: All nodes can reach local registry
   - Ansible controller can reach all nodes on port 50000
   - Control plane endpoint accessible (load balancer or first CP node)

## Quick Start

### Internet-Connected Deployment (Simplest)

**1. Enable internet mode** in `vars/airgap.yml`:
```yaml
airgap_enabled: false
```

**2. Configure inventory** with your node IPs in `inventory/hosts.yml`

**3. Deploy cluster**:
```bash
ansible-playbook -i inventory/hosts.yml playbook.yml
```

Done! Images pulled from public registries automatically.

### Air-Gapped Deployment

**1. Enable air-gap mode** in `vars/airgap.yml`:
```yaml
airgap_enabled: true
local_registry_url: "registry.local:5000"
```

**2. Mirror images** to your local registry:
```bash
./scripts/mirror-all-images.sh registry.local:5000
```

**3. Configure inventory** with your node IPs in `inventory/hosts.yml`

**4. Deploy cluster**:
```bash
ansible-playbook -i inventory/hosts.yml playbook.yml
```

See [docs/AIRGAP.md](docs/AIRGAP.md) for detailed air-gap setup instructions.

## Configuration

### 1. Inventory Configuration

**Edit `inventory/hosts.yml`**:
```yaml
control_plane:
  hosts:
    cp01:
      ansible_host: 192.168.1.10  # Update with actual IPs
    # Add more control plane nodes...

workers:
  hosts:
    worker01:
      ansible_host: 192.168.1.20  # Update with actual IPs
    # Add more worker nodes...
```

**Static IP Configuration** (optional):

If nodes boot with DHCP but you want permanent static IPs:
```yaml
cp01:
  ansible_host: 192.168.1.100  # Current DHCP IP (for connection)
  static_ip: 192.168.1.10       # Desired static IP
  static_gateway: 192.168.1.1
  static_netmask: "24"
  static_interface: "eth0"
```

Playbook connects via DHCP, applies config with static IPs, nodes switch automatically. See [docs/STATIC_IP.md](docs/STATIC_IP.md) for complete guide.

### 2. Deployment Mode Configuration

**For Internet-Connected** (default):
- Set `airgap_enabled: false` in `vars/airgap.yml`
- Images use public registries automatically
- No registry configuration needed

**For Air-Gapped**:
```yaml
# Edit vars/airgap.yml
airgap_enabled: true
local_registry_url: "registry.yourdomain.com:5000"
registry_username: ""  # If authentication required
registry_password: ""  # If authentication required
```

### 3. Cluster Configuration

**Edit `group_vars/all.yml`**:
```yaml
cluster_name: "my-cluster"
talos_version: "v1.12.4"
kubernetes_version: "1.32.2"
cilium_version: "1.19.1"
```

### 4. Image Version Configuration (Optional)

To change component versions, edit `vars/cilium_images.yml`:
```yaml
cilium_image:
  tag: "v1.19.2"  # Update to new version

operator_image:
  tag: "v1.19.2"
# ... update as needed
```

### 5. Deploy Cluster

```bash
# Full deployment (all phases)
ansible-playbook -i inventory/hosts.yml playbook.yml

# Or step-by-step:
ansible-playbook -i inventory/hosts.yml playbook.yml --tags prerequisites
ansible-playbook -i inventory/hosts.yml playbook.yml --tags generate
ansible-playbook -i inventory/hosts.yml playbook.yml --tags apply
ansible-playbook -i inventory/hosts.yml playbook.yml --tags bootstrap
ansible-playbook -i inventory/hosts.yml playbook.yml --tags cilium
ansible-playbook -i inventory/hosts.yml playbook.yml --tags validate
```

**Deployment Phases**:
1. **validate_airgap** - Check air-gap environment (skipped if `airgap_enabled: false`)
2. **prerequisites** - Verify CLI tools and connectivity
3. **generate** - Create Talos configs (with registry mirrors if air-gapped)
4. **apply** - Apply configs to all nodes
5. **bootstrap** - Initialize Kubernetes cluster
6. **cilium** - Install Cilium CNI via CLI
7. **validate** - Verify deployment success

### 6. Access Your Cluster

```bash
# Set kubeconfig
export KUBECONFIG=configs/kubeconfig

# Verify cluster
kubectl get nodes
kubectl get pods -A

# Check Cilium status
cilium status

# Set talosconfig
export TALOSCONFIG=generated-configs/talosconfig

# View Talos dashboard
talosctl dashboard
```

## Project Structure

```
.
├── ansible.cfg                 # Ansible configuration
├── playbook.yml                # Main playbook
├── inventory/
│   └── hosts.yml              # Node inventory
├── group_vars/
│   └── all.yml                # Cluster configuration
├── vars/
│   ├── airgap.yml             # Deployment mode & registry config
│   └── cilium_images.yml      # All image definitions (auto-switches based on mode)
├── roles/
│   ├── validate_airgap/       # Validate air-gap prerequisites
│   ├── prerequisites/         # Install required tools
│   ├── generate_configs/      # Generate Talos configs
│   ├── apply_configs/         # Apply configs to nodes
│   ├── bootstrap_cluster/     # Bootstrap Kubernetes
│   ├── install_cilium/        # Install Cilium via CLI
│   └── validate_cluster/      # Validate deployment
├── configs/                   # Generated by playbook (gitignored)
│   ├── secrets.yaml           # Talos secrets bundle
│   ├── controlplane.yaml      # Control plane config
│   ├── worker.yaml            # Worker config
│   ├── talosconfig            # Talosctl config
│   └── kubeconfig             # Kubectl config
├── scripts/
│   ├── mirror-all-images.sh   # Mirror images to registry
│   ├── verify-images.sh       # Verify mirrored images
│   └── setup-registry.sh      # Setup local registry
├── files/                     # Optional offline resources
│   └── registry-ca.crt        # Registry CA certificate (optional)
└── docs/
    ├── AIRGAP.md              # Air-gap setup guide
    ├── CILIUM_INSTALL.md      # Cilium installation guide
    ├── STATIC_IP.md           # Static IP configuration guide
    └── QUICKSTART.md          # Quick start guide
```

## Configuration Options

### Image Configuration

**All images automatically configured based on deployment mode** in `vars/cilium_images.yml`:

- **Internet-Connected** (`airgap_enabled: false`): Uses public registries
  ```yaml
  cilium_image:
    repository: "quay.io/cilium/cilium"  # Direct from quay.io
    tag: "v1.19.1"
  ```

- **Air-Gapped** (`airgap_enabled: true`): Uses local registry
  ```yaml
  cilium_image:
    repository: "registry.local:5000/cilium/cilium"  # From local registry
    tag: "v1.19.1"
  ```

The repository automatically switches - just change `airgap_enabled` flag!

### Cilium Installation Settings

Edit `vars/cilium_images.yml`:

```yaml
cilium_install_settings:
  kube_proxy_replacement: "true"   # Use eBPF kube-proxy
  tunnel: "disabled"               # Native routing
  ipam_mode: "kubernetes"          # IPAM mode
```

### Network Configuration

```yaml
pod_cidr: "10.244.0.0/16"          # Pod network CIDR (10.244.0.0 - 10.244.255.255)
service_cidr: "10.96.0.0/16"       # Service network CIDR (10.96.0.0 - 10.96.255.255)
```

**Note:** Service CIDR was changed from `/12` to `/16` to avoid address overlap with host networks in the `10.100.x.x` range.

### Registry Configuration (Air-Gapped Only)

For air-gapped deployments with self-signed certificates:

```yaml
# In vars/airgap.yml
registry_insecure_skip_verify: true

# Or provide CA certificate:
registry_ca_cert: "{{ playbook_dir }}/files/registry-ca.crt"
```

## Secrets Management

The playbook generates a `secrets.yaml` file containing cluster PKI material. Protect this file:

**Option 1: Ansible Vault** (Recommended)
```bash
# Encrypt secrets after first generation
ansible-vault encrypt generated-configs/secrets.yaml

# Run playbook with vault password
ansible-playbook -i inventory/hosts.yml playbook.yml --ask-vault-pass
```

**Option 2: External Secrets Manager**
Store `secrets.yaml` in HashiCorp Vault, AWS Secrets Manager, etc.

## Documentation

- **[Cilium Installation Guide](docs/CILIUM_INSTALL.md)** - Managing Cilium with CLI
- **[Air-Gap Setup Guide](docs/AIRGAP.md)** - Complete air-gap preparation
- **[Static IP Configuration](docs/STATIC_IP.md)** - Configure static IPs via DHCP initially
- **[Quick Start Guide](docs/QUICKSTART.md)** - Step-by-step deployment

## Operations

### Upgrade Cilium

**Easy method** - Edit version and rerun:

```bash
# 1. Edit vars/cilium_images.yml
cilium_image:
  tag: "v1.20.0"

# 2. Mirror new images
./scripts/mirror-all-images.sh registry.local:5000

# 3. Reinstall
ansible-playbook -i inventory/hosts.yml playbook.yml --tags cilium
```

See [docs/CILIUM_INSTALL.md](docs/CILIUM_INSTALL.md) for more options.

### Add Worker Nodes

1. Add new node to `inventory/hosts.yml` under `workers` group
2. Run apply configuration:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbook.yml --tags apply --limit workers
   ```

### Upgrade Kubernetes

1. Update `kubernetes_version` in `group_vars/all.yml`
2. Mirror new Kubernetes images to registry
3. Run:
   ```bash
   talosctl upgrade-k8s --to v1.32.3
   ```

### Upgrade Talos

1. Update `talos_version` in `group_vars/all.yml`
2. Mirror new Talos installer image
3. Run:
   ```bash
   talosctl upgrade --image registry.local:5000/siderolabs/installer:v1.12.5
   ```

## Troubleshooting

**Quick checks**:

```bash
# Check node status
talosctl health --nodes <node-ip>

# View node logs
talosctl logs --nodes <node-ip>

# Check image pulls
talosctl get containerstatus --nodes <node-ip>

# Cilium status
kubectl exec -n kube-system <cilium-pod> -- cilium status
```

## Security Considerations

- **Secrets**: Always encrypt `secrets.yaml` with ansible-vault
- **Registry Authentication**: Use registry authentication in production
- **Network Policies**: Implement Cilium network policies for pod segmentation
- **Pod Security**: Enable Pod Security Standards
- **API Access**: Limit Kubernetes API access with RBAC

## Contributing

Contributions welcome! Please test in a development environment before production use.

## License

MIT

## References

- [Talos Documentation](https://www.talos.dev/)
- [Cilium Documentation](https://docs.cilium.io/)
- [Talos Production Notes](https://docs.siderolabs.com/talos/v1.12/getting-started/prodnotes)
- [Cilium on Talos](https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium)