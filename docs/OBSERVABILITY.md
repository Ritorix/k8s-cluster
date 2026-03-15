# Observability & Logging (Prometheus, Grafana, Splunk)

This repository can optionally deploy an observability stack to monitor and log your Talos Kubernetes cluster.

## What is included

- **Prometheus + Grafana** via the `kube-prometheus-stack` Helm chart
- **Splunk Connect for Kubernetes** (optional) for sending logs, metrics, and events to Splunk
- **Cilium Gateway API** support enabled by default

## Enabling Observability

1. Edit `group_vars/all.yml`:

```yaml
observability_enabled: true
observability:
  # Optional local chart directory (for air-gapped installs)
  # Set this to the directory containing helm chart tarballs (e.g. airgap-assets/charts)
  chart_dir: ""  # e.g. /path/to/airgap-assets/charts

  prometheus:
    chart_version: "45.6.0"
    retention: "15d"
    storage: "10Gi"
  grafana:
    admin_user: "admin"
    admin_password: "admin"
    persistence: true
    persistence_size: "5Gi"
  default_dashboards: true
  default_alerts: true

  splunk_enabled: false
  splunk:
    chart_version: "2.15.0"
    hec_host: "splunk.example.com"
    hec_port: 8088
    hec_protocol: "https"
    hec_token: "<your-hec-token>"  # OR use splunk_hec_token in group_vars/vault.yml
```

2. Run the playbook with the observability tag:

```bash
ansible-playbook -i inventory/hosts.yml playbook.yml --tags observability
```

## Notes

- The observability role expects `helm` and `kubectl` to be installed on the controller machine.
- In air-gapped environments, you can download the required Helm charts and binaries using the existing airgap tooling and then install them offline.
- **Secrets:** Use `group_vars/vault.yml` (encrypted with `ansible-vault`) to store sensitive values like `splunk_hec_token`.
