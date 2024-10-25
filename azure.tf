resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "azure-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.azure_vpc_cidr]
}

resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.gateway_subnet]
}

resource "azurerm_subnet" "azure_subnet" {
  name                 = "WorkloadSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.azure_subnet]
}

resource "azurerm_public_ip" "azure_vpn_gateway_public_ip_1" {
  name                = "azure_vpn_gateway_public_ip_1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "azure_vpn_gateway_public_ip_2" {
  name                = "azure_vpn_gateway_public_ip_2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "vm_public_ip" {
  name                = "azure-vm-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_virtual_network_gateway" "gateway" {
  name                = "azure-gateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = true
  enable_bgp          = true
  sku                 = "VpnGw1"
  bgp_settings {
    asn         = var.azure_bgp_asn
    peer_weight = 100
    peering_addresses {
      ip_configuration_name = "gw-ip1"
      apipa_addresses       = ["169.254.21.1"]
    }
    peering_addresses {
      ip_configuration_name = "gw-ip2"
      apipa_addresses       = ["169.254.22.1"]
    }
  }
  ip_configuration {
    name                          = "gw-ip1"
    public_ip_address_id          = azurerm_public_ip.azure_vpn_gateway_public_ip_1.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
  }
  ip_configuration {
    name                          = "gw-ip2"
    public_ip_address_id          = azurerm_public_ip.azure_vpn_gateway_public_ip_2.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
  }
}

resource "azurerm_local_network_gateway" "gcp_gw1" {
  depends_on          = [azurerm_virtual_network_gateway.gateway]
  name                = "gcp-local-network-gateway-1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  gateway_address     = google_compute_ha_vpn_gateway.gcp-gateway.vpn_interfaces[0].ip_address
  bgp_settings {
    asn                 = var.gcp_bgp_asn
    bgp_peering_address = google_compute_router_peer.peer1.ip_address
  }
}

resource "azurerm_local_network_gateway" "gcp_gw2" {
  depends_on          = [azurerm_virtual_network_gateway.gateway]
  name                = "gcp-local-network-gateway-2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  gateway_address     = google_compute_ha_vpn_gateway.gcp-gateway.vpn_interfaces[1].ip_address
  bgp_settings {
    asn                 = var.gcp_bgp_asn
    bgp_peering_address = google_compute_router_peer.peer2.ip_address
  }
}

resource "azurerm_virtual_network_gateway_connection" "azure_tunnel_1" {
  name                       = "azure-to-gcp-connection-1"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  type                       = "IPsec"
  enable_bgp                 = true
  virtual_network_gateway_id = azurerm_virtual_network_gateway.gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.gcp_gw1.id
  shared_key                 = var.shared_secret
}

resource "azurerm_virtual_network_gateway_connection" "azure_tunnel_2" {
  name                       = "azure-to-gcp-connection-2"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  type                       = "IPsec"
  enable_bgp                 = true
  virtual_network_gateway_id = azurerm_virtual_network_gateway.gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.gcp_gw2.id
  shared_key                 = var.shared_secret
}