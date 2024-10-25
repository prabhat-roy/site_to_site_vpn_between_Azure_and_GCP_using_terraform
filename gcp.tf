resource "google_compute_network" "gcp-vpc" {
  name                    = "gcp-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "gcp_subnet" {
  name                     = "gcp-subnet"
  ip_cidr_range            = var.gcp_cidr
  region                   = var.gcp_region
  network                  = google_compute_network.gcp-vpc.name
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow-icmp" {
  name          = "allow-icmp"
  network       = google_compute_network.gcp-vpc.id
  source_ranges = [var.azure_vpc_cidr]
  allow {
    protocol = "icmp"

  }
}
resource "google_compute_firewall" "allow-ssh" {
  name    = "allow-ssh"
  network = google_compute_network.gcp-vpc.id
  #source_ranges = ["35.235.240.0/20","${format(jsondecode(data.http.ipinfo.body).ip)}/32"]
  source_ranges = ["35.235.240.0/20", "${chomp(data.http.icanhazip.response_body)}/32"]
  allow {
    protocol = "tcp"
    ports    = [22]
  }
}

resource "google_compute_router" "gcp-router" {
  name    = "gcp-router"
  region  = var.gcp_region
  network = google_compute_network.gcp-vpc.id

  bgp {
    asn               = var.gcp_bgp_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

resource "google_compute_router_nat" "gcp-nat" {
  name                               = "gcp-nat-router"
  router                             = google_compute_router.gcp-router.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

}

resource "google_compute_ha_vpn_gateway" "gcp-gateway" {
  name       = "azure-vpn"
  region     = var.gcp_region
  network    = google_compute_network.gcp-vpc.name
  stack_type = "IPV4_IPV6"
}

resource "google_compute_external_vpn_gateway" "azure-gateway" {
  name            = "azure-gateway"
  redundancy_type = "TWO_IPS_REDUNDANCY"
  description     = "VPN gateway on Azure side"
  interface {
    id         = 0
    ip_address = azurerm_public_ip.azure_vpn_gateway_public_ip_1.ip_address
  }
  interface {
    id         = 1
    ip_address = azurerm_public_ip.azure_vpn_gateway_public_ip_2.ip_address
  }
}

resource "google_compute_vpn_tunnel" "vpn1" {
  name                            = "vpn-tunnel-1"
  peer_external_gateway           = google_compute_external_vpn_gateway.azure-gateway.id
  peer_external_gateway_interface = 0
  shared_secret                   = var.shared_secret
  ike_version                     = 2
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-gateway.self_link
  router                          = google_compute_router.gcp-router.name
  vpn_gateway_interface           = 0
}

resource "google_compute_router_peer" "peer1" {
  name                      = "peer-1"
  router                    = google_compute_router.gcp-router.name
  region                    = google_compute_router.gcp-router.region
  peer_ip_address           = "169.254.21.1"
  peer_asn                  = var.azure_bgp_asn
  interface                 = google_compute_router_interface.int1.name
  advertised_route_priority = 100
}

resource "google_compute_router_interface" "int1" {
  name       = "interface-1"
  router     = google_compute_router.gcp-router.name
  region     = google_compute_router.gcp-router.region
  ip_range   = "169.254.21.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.vpn1.name
}

resource "google_compute_vpn_tunnel" "vpn2" {
  name                            = "vpn-tunnel-2"
  peer_external_gateway           = google_compute_external_vpn_gateway.azure-gateway.id
  peer_external_gateway_interface = 1
  shared_secret                   = var.shared_secret
  ike_version                     = 2
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-gateway.self_link
  router                          = google_compute_router.gcp-router.name
  vpn_gateway_interface           = 1
}

resource "google_compute_router_peer" "peer2" {
  name            = "peer-2"
  router          = google_compute_router.gcp-router.name
  region          = google_compute_router.gcp-router.region
  peer_ip_address = "169.254.22.1"
  peer_asn        = var.azure_bgp_asn
  interface       = google_compute_router_interface.int2.name
}

resource "google_compute_router_interface" "int2" {
  name       = "interface-2"
  router     = google_compute_router.gcp-router.name
  region     = google_compute_router.gcp-router.region
  ip_range   = "169.254.22.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.vpn2.name
}