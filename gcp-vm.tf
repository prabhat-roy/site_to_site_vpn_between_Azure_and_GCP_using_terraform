resource "google_compute_instance" "vm" {
  name         = "vm"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["gcp-vm"]
  boot_disk {
    initialize_params {
      image = var.image
    }
  }
  metadata = {
    ssh-keys = "${var.user}:${file(var.public-key)}"
  }
  network_interface {
    subnetwork = google_compute_subnetwork.gcp_subnet.id
    access_config {
      nat_ip = google_compute_address.vm.address
    }
  }
}
resource "google_compute_address" "vm" {
  name    = "gcp-ip"
  project = var.project_id
  region  = var.gcp_region
}
