# Air-Gapped Environment Setup Guide

This guide covers preparing an air-gapped environment for Talos Kubernetes cluster deployment.

## Overview

An air-gapped deployment requires:
1. Local container registry
2. Mirrored container images
3. Offline Helm charts
4. CLI tools on Ansible controller

## Prerequisites Checklist

- [ ] Local container registry running
- [ ] Network connectivity from all nodes to registry
- [ ] Sufficient storage in registry (~5-10GB)
- [ ] CLI tools downloaded and installed
- [ ] Offline Helm chart downloaded
- [ ] All images mirrored to local registry

## Step 1: Set Up Local Container Registry

### Option A: Docker Registry (Simple)

```bash
# Run registry container
docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name registry \
  -v /mnt/registry:/var/lib/registry \
  registry:2

# Verify
curl http://localhost:5000/v2/_catalog
```

### Option B: Harbor (Production)

Harbor provides:
- Web UI
- Image scanning
- Replication
- Authentication
- Audit logging

See [Harbor Installation Guide](https://goharbor.io/docs/latest/install-config/)

### Option C: Registry with TLS

```bash
# Generate self-signed certificate
mkdir -p certs
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout certs/registry.key \
  -x509 -days 365 \
  -out certs/registry.crt \
  -subj "/CN=registry.local"

# Run registry with TLS
docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name registry \
  -v /mnt/registry:/var/lib/registry \
  -v $(pwd)/certs:/certs \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  registry:2

# Copy CA cert for clients
cp certs/registry.crt files/registry-ca.crt
```

Update `vars/airgap.yml`:
```yaml
registry_ca_cert: "{{ playbook_dir }}/files/registry-ca.crt"
```

## Step 2: Download CLI Tools

On a connected machine, download for your OS:

### Talosctl

```bash
# Linux
VERSION=v1.12.4
curl -Lo talosctl https://github.com/siderolabs/talos/releases/download/${VERSION}/talosctl-linux-amd64
chmod +x talosctl

# Windows
curl -Lo talosctl.exe https://github.com/siderolabs/talos/releases/download/${VERSION}/talosctl-windows-amd64.exe

# Mac
curl -Lo talosctl https://github.com/siderolabs/talos/releases/download/${VERSION}/talosctl-darwin-amd64
chmod +x talosctl
```

### Kubectl

```bash
# Linux
VERSION=1.32.2
curl -LO "https://dl.k8s.io/release/v${VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl

# Windows
curl -LO "https://dl.k8s.io/release/v${VERSION}/bin/windows/amd64/kubectl.exe"

# Mac
curl -LO "https://dl.k8s.io/release/v${VERSION}/bin/darwin/amd64/kubectl"
chmod +x kubectl
```

### Helm

```bash
# Linux
curl -fsSL https://get.helm.sh/helm-v3.17.1-linux-amd64.tar.gz | tar -xz
mv linux-amd64/helm .

# Windows
curl -fsSL https://get.helm.sh/helm-v3.17.1-windows-amd64.zip -o helm.zip

# Mac
curl -fsSL https://get.helm.sh/helm-v3.17.1-darwin-amd64.tar.gz | tar -xz
mv darwin-amd64/helm .
```

Copy these tools to your air-gapped environment and install them.

## Step 3: Download Offline Helm Chart

```bash
# Add Cilium repo
helm repo add cilium https://helm.cilium.io/
helm repo update

# Download chart
helm pull cilium/cilium --version 1.17.2

# Copy to playbook files directory
mv cilium-1.17.2.tgz /path/to/k8s-cluster/files/
```

## Step 4: Mirror Container Images

### Required Images

The playbook needs these images mirrored to your local registry:

**Cilium Images** (~2GB):
- quay.io/cilium/cilium:v1.17.2
- quay.io/cilium/operator-generic:v1.17.2
- quay.io/cilium/hubble-relay:v1.17.2
- quay.io/cilium/hubble-ui:v0.13.1
- quay.io/cilium/hubble-ui-backend:v0.13.1
- quay.io/cilium/cilium-envoy:v1.31.6-1738872074-d9c8b3ad18c67d43c24de78b6b74ed8b3e1eec5e
- quay.io/cilium/certgen:v0.2.1

**Kubernetes Images** (~1GB):
- registry.k8s.io/kube-apiserver:v1.32.2
- registry.k8s.io/kube-controller-manager:v1.32.2
- registry.k8s.io/kube-scheduler:v1.32.2
- registry.k8s.io/coredns/coredns:v1.12.0
- registry.k8s.io/pause:3.11
- registry.k8s.io/etcd:3.5.17-0

**Talos Images** (~1GB):
- ghcr.io/siderolabs/installer:v1.12.4
- ghcr.io/siderolabs/kubelet:v1.32.2

### Mirroring Methods

#### Method 1: Using Skopeo (Recommended)

```bash
#!/bin/bash
# mirror-images.sh

REGISTRY="registry.local:5000"

# Cilium images
skopeo copy docker://quay.io/cilium/cilium:v1.17.2 \
  docker://${REGISTRY}/cilium/cilium:v1.17.2 --dest-tls-verify=false

skopeo copy docker://quay.io/cilium/operator-generic:v1.17.2 \
  docker://${REGISTRY}/cilium/operator-generic:v1.17.2 --dest-tls-verify=false

# Add remaining images...

# Kubernetes images
skopeo copy docker://registry.k8s.io/kube-apiserver:v1.32.2 \
  docker://${REGISTRY}/kube-apiserver:v1.32.2 --dest-tls-verify=false

# Continue for all images...
```

Run: `bash mirror-images.sh`

#### Method 2: Using Crane

```bash
#!/bin/bash
# mirror-images-crane.sh

REGISTRY="registry.local:5000"

crane cp quay.io/cilium/cilium:v1.17.2 ${REGISTRY}/cilium/cilium:v1.17.2
crane cp quay.io/cilium/operator-generic:v1.17.2 ${REGISTRY}/cilium/operator-generic:v1.17.2

# Continue for all images...
```

#### Method 3: Using Docker

```bash
#!/bin/bash
# mirror-images-docker.sh

REGISTRY="registry.local:5000"

# Function to mirror image
mirror_image() {
  local source=$1
  local dest=$2
  
  docker pull ${source}
  docker tag ${source} ${dest}
  docker push ${dest}
}

# Cilium images
mirror_image quay.io/cilium/cilium:v1.17.2 ${REGISTRY}/cilium/cilium:v1.17.2
mirror_image quay.io/cilium/operator-generic:v1.17.2 ${REGISTRY}/cilium/operator-generic:v1.17.2

# Continue for all images...
```

#### Method 4: Image Tarballs (For Complete Air-Gap)

```bash
# Save images to tarball
docker save \
  quay.io/cilium/cilium:v1.17.2 \
  quay.io/cilium/operator-generic:v1.17.2 \
  ... \
  > k8s-images.tar.gz

# Transfer tarball to air-gapped environment

# Load images in air-gapped environment
docker load < k8s-images.tar.gz

# Tag and push to local registry
docker tag quay.io/cilium/cilium:v1.17.2 registry.local:5000/cilium/cilium:v1.17.2
docker push registry.local:5000/cilium/cilium:v1.17.2
# Repeat for all images...
```

### Complete Mirror Script

A comprehensive script is provided at: `scripts/mirror-all-images.sh`

```bash
#!/bin/bash
# scripts/mirror-all-images.sh

set -e

REGISTRY="${REGISTRY:-registry.local:5000}"
METHOD="${METHOD:-skopeo}"  # skopeo, crane, or docker

echo "Mirroring images to ${REGISTRY} using ${METHOD}"

declare -a IMAGES=(
  # Cilium
  "quay.io/cilium/cilium:v1.17.2|cilium/cilium:v1.17.2"
  "quay.io/cilium/operator-generic:v1.17.2|cilium/operator-generic:v1.17.2"
  # Add all images from vars/airgap.yml...
)

for img in "${IMAGES[@]}"; do
  source=$(echo $img | cut -d'|' -f1)
  dest="${REGISTRY}/$(echo $img | cut -d'|' -f2)"
  
  echo "Mirroring: ${source} -> ${dest}"
  
  case $METHOD in
    skopeo)
      skopeo copy docker://${source} docker://${dest} --dest-tls-verify=false
      ;;
    crane)
      crane cp ${source} ${dest}
      ;;
    docker)
      docker pull ${source}
      docker tag ${source} ${dest}
      docker push ${dest}
      ;;
  esac
done

echo "Image mirroring complete!"
```

## Step 5: Verify Mirrored Images

```bash
# List all images in registry
curl -X GET http://registry.local:5000/v2/_catalog | jq

# Check specific image tags
curl -X GET http://registry.local:5000/v2/cilium/cilium/tags/list | jq

# Or use skopeo
skopeo list-tags docker://registry.local:5000/cilium/cilium --tls-verify=false
```

Create a verification script:

```bash
#!/bin/bash
# scripts/verify-images.sh

REGISTRY="registry.local:5000"
MISSING=0

check_image() {
  local repo=$1
  local tag=$2
  
  if curl -sf -X GET "http://${REGISTRY}/v2/${repo}/manifests/${tag}" > /dev/null; then
    echo "✓ ${repo}:${tag}"
  else
    echo "✗ MISSING: ${repo}:${tag}"
    MISSING=$((MISSING+1))
  fi
}

# Check all required images
check_image "cilium/cilium" "v1.17.2"
check_image "cilium/operator-generic" "v1.17.2"
# Add all required images...

if [ $MISSING -eq 0 ]; then
  echo "All images present!"
  exit 0
else
  echo "Missing ${MISSING} images"
  exit 1
fi
```

## Step 6: Configure Playbook Variables

Update `vars/airgap.yml`:

```yaml
local_registry_url: "registry.local:5000"
local_registry_mirror_prefix: "registry.local:5000"

# If using authentication
registry_username: "admin"
registry_password: "password"  # Use ansible-vault encrypt_string

# If using self-signed cert
registry_insecure_skip_verify: false
registry_ca_cert: "{{ playbook_dir }}/files/registry-ca.crt"
```

## Step 7: Pre-Deployment Validation

Run the validation playbook:

```bash
ansible-playbook -i inventory/hosts.yml playbook.yml --tags validate
```

This checks:
- Registry accessibility
- Offline Helm chart present
- Sample images in registry

## Troubleshooting

### Registry Not Accessible

```bash
# Check registry is running
docker ps | grep registry

# Check network connectivity
curl -v http://registry.local:5000/v2/

# Check DNS resolution
nslookup registry.local

# Check firewall
netstat -tulpn | grep 5000
```

### Image Pull Failures

```bash
# View Talos node logs
talosctl logs --nodes <node-ip> -f

# Check container status
talosctl get containerstatus --nodes <node-ip>

# Verify registry mirror configuration
talosctl get machineconfig -o yaml --nodes <node-ip> | grep -A 20 registries
```

### Certificate Issues

```bash
# Distribute CA cert to nodes (already handled by playbook)
# Verify in machine config:
talosctl get machineconfig -o yaml --nodes <node-ip> | grep -A 5 "tls:"

# Or set insecureSkipVerify in vars/airgap.yml
registry_insecure_skip_verify: true
```

## Additional Considerations

### Storage Requirements

- **Registry**: 5-10GB for base images
- **Add 2-3GB** per additional application
- **Recommend**: 20GB+ for production

### Network Bandwidth

Initial deployment pulls ~5-8GB of images. Plan accordingly for:
- Multiple nodes pulling simultaneously
- Registry on same network segment preferred
- Consider CDN/caching layer for large deployments

### Image Updates

Establish process for:
1. Periodically checking for security updates
2. Mirroring new versions
3. Testing in dev before production
4. Maintaining image inventory

### Disaster Recovery

Backup:
- Registry data volume
- Generated `secrets.yaml` (encrypted)
- Machine configurations
- Documentation of versions deployed

## Reference Scripts

All helper scripts are in `scripts/`:
- `mirror-all-images.sh` - Mirror all required images
- `verify-images.sh` - Verify all images present
- `download-offline-tools.sh` - Download CLI tools
- `setup-registry.sh` - Deploy local registry

## Next Steps

After completing air-gap setup:
1. Verify all prerequisites
2. Update inventory with node IPs
3. Run full deployment: `ansible-playbook -i inventory/hosts.yml playbook.yml`
4. Monitor first deployment closely
5. Document any environment-specific changes
