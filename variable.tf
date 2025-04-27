variable "pm_password" {}
variable "template_id" {}
variable "target_node" {}
variable "ssh_public_key" {}
variable "vmbr_name" {
  default = "vmbr1"
}
variable "cluster_vms" {
  type = list(object({
    name   = string
    ip     = string
    cores  = number
    memory = number
    disk   = number
  }))
}

variable "jumpbox_address" {
  default = "192.168.1.240/24"
}
