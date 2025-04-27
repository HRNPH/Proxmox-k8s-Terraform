provider "proxmox" {
  endpoint = "https://192.168.1.100:8006/"
  username = "root@pam"
  password = var.pm_password
  insecure = true

  ssh {
    agent = true
  }
}
