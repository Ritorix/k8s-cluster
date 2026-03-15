#!/usr/bin/env bash
# =============================================================================
# Fetch Required Tools & Assets for Air-Gapped Deployment
# =============================================================================
# This script downloads the CLI tools and Helm chart required to deploy the
# Talos + Cilium cluster in an air-gapped environment.
#
# Usage (on an internet-connected machine):
#   ./scripts/fetch-airgap-assets.sh [output-dir]
#
# Example:
#   ./scripts/fetch-airgap-assets.sh ./airgap-assets
#
# Copy the resulting directory to the air-gapped environment and install the
# binaries manually.
#
# Variables:
#   OUTPUT_DIR             - where to save downloaded artifacts (default: ./airgap-assets)
#   TALOS_VERSION          - Talos version (default matches group_vars/all.yml)
#   KUBERNETES_VERSION     - Kubernetes version (default matches group_vars/all.yml)
#   HELM_VERSION           - Helm version (default: v3.17.1)
#   CILIUM_CHART_VERSION   - Cilium Helm chart version (default matches group_vars/all.yml)
#   PROMETHEUS_CHART_VERSION - kube-prometheus-stack Helm chart version (default: 45.6.0)
#   SPLUNK_CHART_VERSION   - splunk-connect-for-kubernetes Helm chart version (default: 2.15.0)
#
# Note: This is intended for interactive use. It does NOT attempt to install
# packages locally (that should be done on the air-gapped host).
# =============================================================================

set -euo pipefail

OUTPUT_DIR="${1:-./airgap-assets}"
TALOS_VERSION="${TALOS_VERSION:-v1.12.4}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.35.0}"
HELM_VERSION="${HELM_VERSION:-v3.17.1}"
CILIUM_CHART_VERSION="${CILIUM_CHART_VERSION:-1.19.1}"
PROMETHEUS_CHART_VERSION="${PROMETHEUS_CHART_VERSION:-45.6.0}"
SPLUNK_CHART_VERSION="${SPLUNK_CHART_VERSION:-2.15.0}"

# Determine OS and architecture for downloads.
detect_platform() {
  local uname_s uname_m
  uname_s="$(uname -s)"
  uname_m="$(uname -m)"

  case "${uname_s}" in
    Linux)   OS=linux ;; 
    Darwin)  OS=darwin ;; 
    MINGW*|MSYS*|CYGWIN*) OS=windows ;; 
    *) echo "Unsupported OS: ${uname_s}" >&2; exit 1 ;;
  esac

  case "${uname_m}" in
    x86_64|amd64) ARCH=amd64 ;; 
    aarch64|arm64) ARCH=arm64 ;; 
    *) echo "Unsupported architecture: ${uname_m}" >&2; exit 1 ;;
  esac

  echo "Detected platform: ${OS}/${ARCH}"
}

download_file() {
  local url=$1
  local dest=$2

  mkdir -p "$(dirname "${dest}")"

  if [ -f "${dest}" ]; then
    echo "Skipping existing file: ${dest}"
    return
  fi

  echo "Downloading ${url} -> ${dest}"
  curl -fsSL "${url}" -o "${dest}"
}

fetch_talosctl() {
  local bin_name="talosctl"
  local url
  local dest

  if [ "${OS}" = "windows" ]; then
    bin_name="talosctl.exe"
  fi

  url="https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/talosctl-${OS}-${ARCH}"
  dest="${OUTPUT_DIR}/bin/${bin_name}"

  download_file "${url}" "${dest}"
  if [ "${OS}" != "windows" ]; then
    chmod +x "${dest}"
  fi
}

fetch_kubectl() {
  local bin_name="kubectl"
  local url
  local dest

  if [ "${OS}" = "windows" ]; then
    bin_name="kubectl.exe"
  fi

  url="https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/${OS}/${ARCH}/${bin_name}"
  dest="${OUTPUT_DIR}/bin/${bin_name}"

  download_file "${url}" "${dest}"
  if [ "${OS}" != "windows" ]; then
    chmod +x "${dest}"
  fi
}

fetch_helm() {
  local archive
  local url
  local dest

  case "${OS}" in
    linux|darwin)
      archive="helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz"
      url="https://get.helm.sh/${archive}"
      dest="${OUTPUT_DIR}/downloads/${archive}"
      download_file "${url}" "${dest}"
      tar -xzf "${dest}" -C "${OUTPUT_DIR}/bin" --strip-components=1 "${OS}-${ARCH}/helm"
      chmod +x "${OUTPUT_DIR}/bin/helm"
      ;;
    windows)
      archive="helm-${HELM_VERSION}-${OS}-${ARCH}.zip"
      url="https://get.helm.sh/${archive}"
      dest="${OUTPUT_DIR}/downloads/${archive}"
      download_file "${url}" "${dest}"
      unzip -o "${dest}" -d "${OUTPUT_DIR}/bin"
      ;;
    *)
      echo "Unsupported OS for Helm: ${OS}" >&2
      exit 1
      ;;
  esac
}

fetch_helm_chart() {
  local repo_name=$1
  local repo_url=$2
  local chart_name=$3
  local version=$4

  echo "Fetching Helm chart ${repo_name}/${chart_name} (version ${version})"
  mkdir -p "${OUTPUT_DIR}/charts"
  helm repo add "${repo_name}" "${repo_url}" 2>/dev/null || true
  helm repo update
  helm pull "${repo_name}/${chart_name}" --version "${version}" --destination "${OUTPUT_DIR}/charts"
}

fetch_cilium_chart() {
  # Requires Helm binary available in OUTPUT_DIR/bin
  echo "Fetching Cilium Helm chart v${CILIUM_CHART_VERSION}"
  export PATH="${OUTPUT_DIR}/bin:${PATH}"

  mkdir -p "${OUTPUT_DIR}/charts"
  helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
  helm repo update
  helm pull cilium/cilium --version "${CILIUM_CHART_VERSION}" --destination "${OUTPUT_DIR}/charts"
}

fetch_observability_charts() {
  # Requires Helm binary available in OUTPUT_DIR/bin
  echo "Fetching observability Helm charts"
  export PATH="${OUTPUT_DIR}/bin:${PATH}"

  mkdir -p "${OUTPUT_DIR}/charts"
  fetch_helm_chart prometheus-community https://prometheus-community.github.io/helm-charts kube-prometheus-stack "${PROMETHEUS_CHART_VERSION}"
  fetch_helm_chart splunk https://splunk.github.io/splunk-connect-for-kubernetes splunk-connect-for-kubernetes "${SPLUNK_CHART_VERSION}"
}

fetch_all() {
  detect_platform
  echo "Saving assets to: ${OUTPUT_DIR}"

  fetch_talosctl
  fetch_kubectl
  fetch_helm
  fetch_cilium_chart
  fetch_observability_charts

  echo ""
  echo "✅ Air-gap asset download complete."
  echo "Copy the contents of ${OUTPUT_DIR} to your air-gapped environment."
  echo "Example: tar -czf airgap-assets.tar.gz -C ${OUTPUT_DIR} ."
}

main() {
  fetch_all
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
