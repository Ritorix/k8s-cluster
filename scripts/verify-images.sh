#!/bin/bash
# =============================================================================
# Image Verification Script for Air-Gapped Deployment
# =============================================================================
# Verify all required images are present in local registry
#
# Usage: ./verify-images.sh [registry-url]
# Example: ./verify-images.sh registry.local:5000
#
# Note: Image versions match vars/cilium_images.yml
# =============================================================================

set -e

REGISTRY="${1:-registry.local:5000}"
INSECURE="${INSECURE:-true}"
MISSING=0
PRESENT=0

echo "============================================"
echo "Image Verification Script"
echo "============================================"
echo "Registry: ${REGISTRY}"
echo "============================================"
echo ""
echo "💡 TIP: Image versions defined in vars/cilium_images.yml"
echo ""

# Function to check image
check_image() {
  local repo=$1
  local tag=$2
  
  local url="http://${REGISTRY}/v2/${repo}/manifests/${tag}"
  
  if curl -sf -X GET "${url}" > /dev/null 2>&1; then
    echo "✓ ${repo}:${tag}"
    PRESENT=$((PRESENT+1))
  else
    echo "✗ MISSING: ${repo}:${tag}"
    MISSING=$((MISSING+1))
  fi
}

# Check Cilium images
echo "=== Cilium Images ==="
check_image "cilium/cilium" "v1.19.1"
check_image "cilium/operator-generic" "v1.19.1"
check_image "cilium/hubble-relay" "v1.19.1"
check_image "cilium/hubble-ui" "v0.13.1"
check_image "cilium/hubble-ui-backend" "v0.13.1"
check_image "cilium/cilium-envoy" "v1.35.9-1770979049-232ed4a26881e4ab4f766f251f258ed424fff663"
check_image "cilium/certgen" "v0.3.2"
echo ""

# Check Kubernetes images
echo "=== Kubernetes Images ==="
check_image "kube-apiserver" "v1.32.2"
check_image "kube-controller-manager" "v1.32.2"
check_image "kube-scheduler" "v1.32.2"
check_image "coredns/coredns" "v1.12.0"
check_image "pause" "3.11"
check_image "etcd" "3.5.17-0"
echo ""

# Check Talos images
echo "=== Talos Images ==="
check_image "siderolabs/installer" "v1.12.4"
check_image "siderolabs/kubelet" "v1.32.2"
echo ""

echo "============================================"
echo "Verification Results"
echo "============================================"
echo "Present: ${PRESENT}"
echo "Missing: ${MISSING}"
echo "============================================"

if [ $MISSING -eq 0 ]; then
  echo "✓ All images present!"
  exit 0
else
  echo "✗ ${MISSING} images missing"
  echo ""
  echo "Run mirror script:"
  echo "  ./scripts/mirror-all-images.sh ${REGISTRY}"
  exit 1
fi
