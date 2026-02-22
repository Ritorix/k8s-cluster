# Offline Resources

Place offline resources in this directory:

## Optional Files

### Registry CA Certificate
- **File**: `registry-ca.crt`
- **When**: Using self-signed certificates on registry
- **Usage**: Referenced in `vars/airgap.yml`:
  ```yaml
  registry_ca_cert: "{{ playbook_dir }}/files/registry-ca.crt"
  ```

### Optional: CLI Binaries (if distributing with playbook)
- `talosctl` (Linux/Windows/Mac)
- `kubectl` (Linux/Windows/Mac)
- `cilium` CLI (Linux/Windows/Mac)

## File Structure

```
files/
├── README.md                 # This file
├── registry-ca.crt          # Optional: Registry CA certificate
└── tools/                   # Optional: Offline CLI tools
    ├── talosctl-linux-amd64
    ├── kubectl-linux-amd64
    └── cilium-linux-amd64
```

## Notes

- This directory is for optional offline resources
- Files here are typically large and not stored in git
- Add to `.gitignore` as needed
- Main deployment uses `cilium install` CLI command (no chart needed)
