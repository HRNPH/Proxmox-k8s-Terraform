# Main Cluster creation script for Proxmox
resource "proxmox_virtual_environment_vm" "k8s_nodes" {
  count     = length(var.cluster_vms)
  vm_id     = 300 + count.index
  name      = var.cluster_vms[count.index].name
  node_name = var.target_node
  started   = true

  clone {
    vm_id = var.template_id
    full  = true
  }


  agent {
    enabled = true
  }

  cpu {
    cores = var.cluster_vms[count.index].cores
  }

  memory {
    dedicated = var.cluster_vms[count.index].memory
  }

  # Disk is whatever the hell the template has

  boot_order = ["virtio0"]

  network_device {
    bridge = var.vmbr_name
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.cluster_vms[count.index].ip}/24"
        gateway = "192.168.3.1"
      }
    }
  }
}

# Jumpbox VM for cluster access
resource "proxmox_virtual_environment_vm" "jumpbox" {
  vm_id     = 399
  name      = "jumpbox-madoka-k8s"
  node_name = var.target_node
  started   = true

  clone {
    vm_id = var.template_id
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
  }

  network_device {
    bridge = "vmbr0" # real LAN access
  }

  network_device {
    bridge = "vmbr1" # cluster access
  }

  boot_order = ["virtio0"]

  initialization {
    ip_config {
      ipv4 {
        address = var.jumpbox_address
        gateway = "192.168.1.1" # adjust to your real router
      }
    }

    # Hard code is Ok since this is a jumpbox
    ip_config {
      ipv4 {
        address = "192.168.3.250/24"
      }
    }
  }
}
