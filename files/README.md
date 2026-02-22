# Offline Resources

Place offline resources in this directory:

## Required Files

### Cilium Helm Chart
- **File**: `cilium-1.17.2.tgz`
- **Download**: 
  ```bash
  helm repo add cilium https://helm.cilium.io/
  helm repo update
  helm pull cilium/cilium --version 1.17.2
  ```

### Optional: Registry CA Certificate
- **File**: `registry-ca.crt`
- **When**: Using self-signed certificates on registry
- **Usage**: Referenced in `vars/airgap.yml`:
  ```yaml
  registry_ca_cert: "{{ playbook_dir }}/files/registry-ca.crt"
  ```

### Optional: CLI Binaries (if distributing with playbook)
- `talosctl` (Linux/Windows/Mac)
- `kubectl` (Linux/Windows/Mac)
- `helm` (Linux/Windows/Mac)

## File Structure

```
files/
├── README.md                 # This file
├── cilium-1.18.0.tgz        # Required: Offline Helm chart
├── registry-ca.crt          # Optional: Registry CA certificate
└── tools/                   # Optional: Offline CLI tools
    ├── talosctl-linux-amd64
    ├── kubectl-linux-amd64
    └── helm-linux-amd64
```

## Notes

- Files in this directory are typically large and not stored in git
- Add to `.gitignore` as needed
- Ensure files are downloaded before running playbook in air-gapped environment
