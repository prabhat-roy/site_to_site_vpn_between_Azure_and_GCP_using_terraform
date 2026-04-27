# Site-to-Site VPN: Azure ↔ GCP (Terraform)

IPsec tunnel between an Azure VNet and a GCP VPC, with a test VM in each cloud.

---

## Architecture

```
Azure VNet (10.0.0.0/16)             GCP VPC (10.10.0.0/24)
   |                                       |
   +-- VM (10.0.x.x) <-- IPsec VPN -->    +-- VM (10.10.x.x)
   |                                       |
Azure VPN Gateway                      GCP HA VPN Gateway
```

---

## What gets created

| Side | Resources | File |
|------|-----------|------|
| Azure | RG, VNet, GatewaySubnet, Public IP, VPN Gateway, Local Network Gateway, Connection, VM | `azure.tf`, `azure-vm.tf` |
| GCP   | VPC, subnet, firewall, HA VPN Gateway, Peer VPN Gateway, tunnel, VM | `gcp.tf`, `gcp-vm.tf` |
| Outputs | Tunnel IPs, VM public IPs | `output.tf` |

---

## Prerequisites

1. Azure subscription, `az login` complete.
2. GCP project + service account JSON (Compute Admin).
3. SSH key pair generated locally for both VMs.
4. Terraform >= 1.5.

---

## Configuration

Edit `terraform.tfvars` — Azure region, GCP project/region, both CIDRs, both key paths.

---

## Deploy

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

(Azure gateway provisioning is the slow leg — 30-45 min.)

---

## Verify

SSH into one VM, ping the other side's private IP.

---

## Tear down

```bash
terraform destroy -auto-approve
```