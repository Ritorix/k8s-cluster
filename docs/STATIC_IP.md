# Static IP Configuration

This guide explains how to configure static IPs for Talos nodes while connecting via DHCP initially.

## Workflow Overview

```
1. Boot nodes with DHCP
   └─> Nodes get temporary DHCP IPs
   
2. Discover IPs from DHCP server
   └─> Update ansible_host in inventory
   
3. Configure static IPs in inventory
   └─> Set static_ip, static_gateway, etc.
   
4. Deploy playbook
   └─> Connects via DHCP (ansible_host)
   └─> Applies config with static IPs
   
5. Nodes reboot and use static IPs
   └─> Network switches from DHCP to static
```

## Configuration

### 1. Discover DHCP IPs

After booting Talos nodes, find their DHCP-assigned IPs:

**Option A: Check DHCP Server**
```bash
# View DHCP leases (varies by DHCP server)
cat /var/lib/dhcp/dhcpd.leases
```

**Option B: Check Node Console**
```bash
# Boot node and view console
# IP shown during boot or via:
ip addr show
```

**Option C: Scan Network**
```bash
nmap -p 50000 192.168.1.0/24
```

### 2. Configure Inventory

Edit `inventory/hosts.yml`:

```yaml
control_plane:
  hosts:
    cp01:
      # DHCP IP for initial connection
      ansible_host: 192.168.1.50
      
      # Static IP configuration (applied in machine config)
      static_ip: 192.168.1.10
      static_gateway: 192.168.1.1
      static_netmask: "24"          # CIDR notation (24 = /24 = 255.255.255.0)
      static_interface: "eth0"      # Network interface name
      
    cp02:
      ansible_host: 192.168.1.51    # Current DHCP IP
      static_ip: 192.168.1.11        # Desired static IP
      static_gateway: 192.168.1.1
      static_netmask: "24"
      static_interface: "eth0"
```

### 3. Important: Cluster Endpoint

If using first control plane as endpoint, use **static IP**:

```yaml
# In group_vars/all.yml
# BAD - uses DHCP IP
cluster_endpoint: "192.168.1.50"

# GOOD - uses static IP
cluster_endpoint: "192.168.1.10"

# BEST - use load balancer or DNS
cluster_endpoint: "k8s-api.yourdomain.com"
```

### 4. Deploy Cluster

```bash
# Deploy with static IPs
ansible-playbook -i inventory/hosts.yml playbook.yml

# Playbook will:
# 1. Connect to nodes via ansible_host (DHCP IP)
# 2. Generate static IP patches per node
# 3. Apply configs with static IP settings
# 4. Nodes reboot and switch to static IPs
```

### 5. After Deployment

Nodes are now using static IPs. Update `ansible_host` to match for clarity:

```yaml
cp01:
  ansible_host: 192.168.1.10  # Now matches static_ip
  static_ip: 192.168.1.10
  # ...
```

## Configuration Options

### Per-Node Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `static_ip` | Yes | - | Static IP address (without CIDR) |
| `static_gateway` | Yes | - | Default gateway IP |
| `static_netmask` | No | `24` | CIDR netmask (24 = /24) |
| `static_interface` | No | `eth0` | Network interface name |

### Common Netmasks

| CIDR | Subnet Mask | Hosts |
|------|-------------|-------|
| `/24` | 255.255.255.0 | 254 |
| `/23` | 255.255.254.0 | 510 |
| `/22` | 255.255.252.0 | 1022 |
| `/16` | 255.255.0.0 | 65534 |

## Examples

### Example 1: Simple Static IPs

All nodes on same subnet with sequential IPs:

```yaml
control_plane:
  hosts:
    cp01:
      ansible_host: 192.168.1.100  # DHCP
      static_ip: 192.168.1.10
      static_gateway: 192.168.1.1
      static_netmask: "24"
      static_interface: "eth0"
    cp02:
      ansible_host: 192.168.1.101  # DHCP
      static_ip: 192.168.1.11
      static_gateway: 192.168.1.1
      static_netmask: "24"
      static_interface: "eth0"
```

### Example 2: Different Subnets

Control plane and workers on different subnets:

```yaml
control_plane:
  hosts:
    cp01:
      ansible_host: 192.168.1.100
      static_ip: 10.0.1.10
      static_gateway: 10.0.1.1
      static_netmask: "24"
      static_interface: "eth0"

workers:
  hosts:
    worker01:
      ansible_host: 192.168.1.200
      static_ip: 10.0.2.10
      static_gateway: 10.0.2.1
      static_netmask: "24"
      static_interface: "eth0"
```

### Example 3: Mixed DHCP and Static

Some nodes use DHCP, others use static:

```yaml
control_plane:
  hosts:
    cp01:
      ansible_host: 192.168.1.10
      static_ip: 192.168.1.10      # Static
      static_gateway: 192.168.1.1
      static_netmask: "24"
    
workers:
  hosts:
    worker01:
      ansible_host: 192.168.1.20  # DHCP only (no static_* vars)
```

## Troubleshooting

### Node Not Reachable After Apply

**Cause**: Node switched to static IP but can't be reached

**Solution**:
1. Check static IP is correct and not in use
2. Verify gateway is reachable: `ping 192.168.1.1`
3. Check physical interface name: `ip link show`
4. Access node console to see network status

### Wrong Interface Name

**Symptom**: Node has no network after applying config

**Solution**:
```bash
# Boot node with DHCP first, check interface name
talosctl -n <dhcp-ip> get links

# Common names: eth0, ens192, enp0s3, eno1
# Update static_interface in inventory
```

### Gateway Unreachable

**Symptom**: Node has IP but no external connectivity

**Solution**:
```bash
# Verify gateway is correct for your network
# Check routing: 
talosctl -n <node-ip> get routes
```

### Cluster Endpoint Not Working

**Symptom**: Can't reach cluster after switching to static IPs

**Solution**:
- Ensure `cluster_endpoint` in `group_vars/all.yml` uses static IP or DNS
- Don't use temporary DHCP IP as cluster endpoint
- Use load balancer VIP or first control plane static IP

## Advanced: Bond Interfaces

For bonded interfaces (LACP, active-backup):

```yaml
cp01:
  ansible_host: 192.168.1.100
  static_ip: 192.168.1.10
  static_gateway: 192.168.1.1
  static_netmask: "24"
  static_interface: "bond0"
```

**Note**: Bond configuration requires additional Talos machine config patches. See Talos documentation for bond interface setup.

## Reference

- [Talos Network Configuration](https://www.talos.dev/latest/reference/configuration/#networkconfiguration)
- [Main Deployment Guide](../README.md)
- [Inventory Configuration](../inventory/hosts.yml)
