#!/bin/bash
# =============================================================================
# Image Mirroring Script for Air-Gapped Deployment
# =============================================================================
# Mirror all required images from public registries to your local registry
# 
# BEFORE RUNNING:
# 1. Edit vars/cilium_images.yml to define all image versions
# 2. Ensure local registry is running and accessible
# 
# Usage: ./mirror-all-images.sh [registry-url]
# Example: ./mirror-all-images.sh registry.local:5000
# 
# Environment Variables:
#   METHOD   - Image copying tool: skopeo (default), crane, or docker
#   INSECURE - Skip TLS verification: true (default) or false
#
# =============================================================================

set -e

REGISTRY="${1:-registry.local:5000}"
METHOD="${METHOD:-skopeo}"  # skopeo, crane, or docker
INSECURE="${INSECURE:-true}"

echo "============================================"
echo "Image Mirroring Script"
echo "============================================"
echo "Registry: ${REGISTRY}"
echo "Method: ${METHOD}"
echo "Insecure: ${INSECURE}"
echo "============================================"
echo ""
echo "💡 TIP: Image versions defined in vars/cilium_images.yml"
echo "        Edit that file to change versions, then re-run this script"
echo ""

# Function to mirror image
mirror_image() {
  local source=$1
  local dest_repo=$2
  local tag=$3
  
  local dest="${REGISTRY}/${dest_repo}:${tag}"
  
  echo "Mirroring: ${source}:${tag}"
  echo "      To: ${dest}"
  
  case $METHOD in
    skopeo)
      if [ "$INSECURE" = "true" ]; then
        skopeo copy --dest-tls-verify=false "docker://${source}:${tag}" "docker://${dest}"
      else
        skopeo copy "docker://${source}:${tag}" "docker://${dest}"
      fi
      ;;
    crane)
      crane cp "${source}:${tag}" "${dest}"
      ;;
    docker)
      docker pull "${source}:${tag}"
      docker tag "${source}:${tag}" "${dest}"
      docker push "${dest}"
      ;;
    *)
      echo "Unknown method: ${METHOD}"
      exit 1
      ;;
  esac
  
  echo "  ✓ Complete"
  echo ""
}

# Cilium images
echo "=== Cilium Images ==="
mirror_image "quay.io/cilium/cilium" "cilium/cilium" "v1.19.1"
mirror_image "quay.io/cilium/operator-generic" "cilium/operator-generic" "v1.19.1"
mirror_image "quay.io/cilium/hubble-relay" "cilium/hubble-relay" "v1.19.1"
mirror_image "quay.io/cilium/hubble-ui" "cilium/hubble-ui" "v0.13.1"
mirror_image "quay.io/cilium/hubble-ui-backend" "cilium/hubble-ui-backend" "v0.13.1"
mirror_image "quay.io/cilium/cilium-envoy" "cilium/cilium-envoy" "v1.35.9-1770979049-232ed4a26881e4ab4f766f251f258ed424fff663"
mirror_image "quay.io/cilium/certgen" "cilium/certgen" "v0.3.2"

# Kubernetes images
echo "=== Kubernetes Images ==="
mirror_image "registry.k8s.io/kube-apiserver" "kube-apiserver" "v1.32.2"
mirror_image "registry.k8s.io/kube-controller-manager" "kube-controller-manager" "v1.32.2"
mirror_image "registry.k8s.io/kube-scheduler" "kube-scheduler" "v1.32.2"
mirror_image "registry.k8s.io/coredns/coredns" "coredns/coredns" "v1.12.0"
mirror_image "registry.k8s.io/pause" "pause" "3.11"
mirror_image "registry.k8s.io/etcd" "etcd" "3.5.17-0"

# Talos images
echo "=== Talos Images ==="
mirror_image "ghcr.io/siderolabs/installer" "siderolabs/installer" "v1.12.4"
mirror_image "ghcr.io/siderolabs/kubelet" "siderolabs/kubelet" "v1.32.2"

echo "============================================"
echo "Image mirroring complete!"
echo "============================================"
echo ""
echo "Verify with:"
echo "  curl http://${REGISTRY}/v2/_catalog | jq"
echo ""
