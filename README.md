# Overview

Madoka terraform is a Proxmox k8s terraform template for deploying a Kubernetes cluster on Proxmox using Ansible and Terraform.

# Features & What's Included

- Automated deployment of a Kubernetes cluster on Proxmox using Terraform and Ansible.
- microk8s for Kubernetes
- Customize the number of nodes and their specifications.
- the domain need to be configured in the code (intended)
- Rancher included
- ArgoCD included
- Delete what you don't need it was designed to be modified

# Notes

- This repository contains a Terraform module for deploying a Kubernetes cluster on Proxmox using Ansible.
- The module uses Ansible to automate the installation and configuration of Kubernetes on the cluster nodes.
- The module is designed to be used with Terraform to provision the infrastructure and Ansible to configure the software.
- The module is designed to be reusable and customizable for different environments and use cases.
- You should sequentially follow the steps below to set up your Kubernetes cluster using this module.
  - Skipping the steps could be done if you know what you are doing
  - If that's not the case try to follow the steps sequentially

# Prerequisites

- Proxmox VE 7.0 or later
- Terraform v1.11.0 or later
- Ansible 2.9 or later
- SSH access to the Proxmox nodes
- SSH key for Ansible access to the Proxmox nodes
- Template VM with cloud-init
- Tested on ubuntu 24.04 but it work with whatever version that got microk8s on snap --classic

# Running the code

## Proxmox Networking

- Necessary to create a bridge network for the cluster nodes to communicate with each other.
- Cluster IP Isolation in Vmbr1
- Vmbr1 -> Vmbr0 (actual home network) for internet access

### Access `shell` of the node containing your k8s cluster

```etc/network/interfaces
# Change the IP address and network mask as per your network configuration
# This is your home network configuration
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.100/24
    gateway 192.168.1.1
    bridge_ports eno1
    bridge_stp off
    bridge_fd 0

# This is your cluster network configuration
auto vmbr1
iface vmbr1 inet static
    address 192.168.3.1/24
    bridge_ports none
    bridge_stp off
    bridge_fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up iptables -t nat -A POSTROUTING -s 192.168.3.0/24 -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s 192.168.3.0/24 -o vmbr0 -j MASQUERADE
```

- then restart the network

```bash
ifreload -a
```

- check the network configuration
- after this the master and worker nodes should be able to ping www.google.com via Vmbr0
- the commmunication between the nodes should still be done via Vmbr1
- you can check the network configuration with

## Terraform VM Provisioning

- Terraform will create the VMs and configure the network as specified in the `main.tf` file.
- create a file called `terraform.tfvars` in the root directory of the repository and add the variable according to `terraform.tfvars.example`

```tfvars
# Proxmox configuration
pm_password    = "xxxxxx"
template_id    = "xxxxxx" # ID should be a number
target_node    = "xxxxxx"
ssh_public_key = "xxxxxx" # can be generated with ssh-keygen -t rsa in case you don't have one

# Cluster VMs configuration
# note that if this was modified, the IPs should be updated in the inventory.ini file for ansible to work
# Refer to the README.md for more details
cluster_vms = [
  { name = "master-1", ip = "192.168.3.11", cores = 2, memory = 4096, disk = 32 },
  { name = "master-2", ip = "192.168.3.12", cores = 2, memory = 4096, disk = 32 },
  { name = "worker-1", ip = "192.168.3.21", cores = 2, memory = 4096, disk = 32 },
  { name = "worker-2", ip = "192.168.3.22", cores = 2, memory = 4096, disk = 32 },
  { name = "worker-3", ip = "192.168.3.23", cores = 2, memory = 4096, disk = 32 },
]
```

- Run the following commands to initialize and apply the Terraform configuration:
- VM should be created and started automatically
- There's a `Jumpbox` VM created to access the cluster via SSH

```bash
terraform init
terraform plan -out ./plans/1-init
terraform apply ./plans/1-init
```

## Ansible

### Cluster Configuration (Optional)

> If you have not modified the `tfvars` file, you can skip this step.

- ensure the `inventory.ini` file is updated with the correct IP addresses of the VMs

```ini
[jumpbox_vm]
jumpbox ansible_host=192.168.1.240

; For Excluding the jumpbox from proxing itself
[k8s_nodes:vars]
; Change the proxy IP (jumpbox ip) and username
ansible_ssh_common_args='-o ProxyJump=madoka@192.168.1.240 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ForwardAgent=yes'

[masters]
; Add and remove the IP address of the nodes in the cluster according to your needs
master-1 ansible_host=192.168.3.11
master-2 ansible_host=192.168.3.12

[workers]
; Add and remove the IP address of the nodes in the cluster according to your needs
worker-1 ansible_host=192.168.3.21
worker-2 ansible_host=192.168.3.22
worker-3 ansible_host=192.168.3.23

[k8s_nodes:children]
masters
workers

[all:vars]
ansible_user=madoka
; It's unnecessary to set this, as we've already use forward agent
; ansible_ssh_private_key_file=~/.ssh/proxmox_madoka_k8s
```

### Ansible playbook

- forward ssh agent basically to forward the ssh key to the jumpbox so you can access the cluster nodes
- The Ansible playbook will install and configure Kubernetes on the cluster nodes.
- The playbook will also install and configure the necessary dependencies for Kubernetes.

```bash
ssh-add ~/.ssh/proxmox_madoka_k8s # Add the ssh key to the agent change to wherever you have the key
```

- it should took like 4-5 minute for all VM to initialized properly
- so ensure that you can
  1. ping the jumpbox VM ip
  2. ssh into the jumpbox VM
  3. ssh into the jumpbox VM and then ssh into the cluster nodes via the jumpbox VM
- If you can ssh into the cluster nodes via the jumpbox VM, then you are good to go
- Run the following command to run the Ansible playbook

```bash
ansible-playbook -i inventory.ini playbook.yml
```

# Destroy Everything

- To destroy the VMs and the network configuration

## Destroy Only VMs (For Resetting the Cluster)

- To destroy only the VMs and keep the network configuration
- Run the following command to destroy the VMs
- After this the VMs should be destroyed, and you can get back to Terraform -> Ansible Step to recreate the VMs and reconfigure the cluster
- it is recommended to do this once you configured everything properly and it worked once, to ensure clean installation.

```bash
terraform destroy -auto-approve
```

- Destroy the VMs and the network configuration
- Run the above command to destroy the VMs
- vim /etc/network/interfaces # in the node shell containing the cluster
- delete the network configuration for vmbr1 (u can do this via the web interface as well)
- then restart the network

```bash
ifreload -a # or just reboot the node
```

# Post-Setup Network Configuration

- After the setup is complete, you may want to configure the network settings for your Kubernetes cluster.
- This includes setting up the network policies for both k8s and proxmox for various proposes.

## Allow k8s to be accessed from the home network

1. Give master-1 a static IP address in the home network
2. Configure the firewall rules in Proxmox to allow traffic from the home network to the master-1 node

```
Proxmox GUI -> Datacenter -> Node(The node containing the k8s cluster) -> Master-1 (your 1st master node ofd k8s) -> Hardware -> Firewall -> Add -> Network Device -> vmbr0 (home network), virtio(paravisulized), firewall enabled, other settings as default virtio(paravisulized), firewall enabled, other settings as default -> cloud-init -> IP Config (net-1, or whatever used vmbr0) -> set the IP address of the master-1 node in the home network and the gateway of the home network (your router admin page ip address) -> save
```

3. Now you can access the k8s dashboard from your home network by adding the DNS which will be resolved by the k8s ingress.

```
# Will not covered advance DNS server configuration (see pihole DNS server/local dns server topic)
# The domain of rancher is default to `rancher.madoka` but you can change it to whatever you want, This repo is intended to be forked and customized for your needs, not used as is.
# But you can use your pc local dns server to resolve the DNS to the master-1 node IP address
# mac and linux example

sudo vim /etc/hosts # vim can be exited wit esc -> :q! (forced exit) or :wq (save and exit)

# The DNS Cache flush maybe needed for MacOS (optional)

sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

# 📂 Important File Overview

This section explains the key files in this repository, what they do, and why they matter.  
**If you're new to Terraform or Ansible**, read this carefully before editing!

| File / Folder                | Purpose                                                                                                                                                                       |
| :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `main.tf`                    | Defines the infrastructure Terraform will create: VMs for Kubernetes masters, workers, and the jumpbox.                                                                       |
| `terraform.tfvars.example`   | A sample file showing what variables you need to define for Terraform (like your Proxmox login, cluster IPs, VM specs). Copy this to `terraform.tfvars` and edit your values. |
| `inventory.ini`              | Ansible inventory file. Lists the IP addresses of all VMs and sets the SSH proxy (jumpbox) settings. Must match your Terraform IP plan.                                       |
| `playbook.yml`               | Main Ansible playbook. Defines **step-by-step actions** like installing MicroK8s, setting up Rancher and ArgoCD. This controls the whole software configuration part.         |
| `/plans/`                    | Folder where you store Terraform plan output files (like `terraform plan -out plans/1-init`). Helps you review and apply planned changes cleanly.                             |
| `/roles/` (optional/empty)   | Not actively used after the recent update. Originally meant for modular Ansible roles like Rancher setup.                                                                     |
| `README.md`                  | This guide you are reading. Describes the full process, structure, and important tips for operating or modifying the setup.                                                   |
| `.terraform/` (auto-created) | Terraform internal cache and plugins folder. No need to edit manually. Can be deleted if you reset the project (`terraform init` will recreate it).                           |
| `terraform.tfstate`          | Tracks what Terraform has created. **Don't edit manually!** Keep it safe. It represents your live cluster state.                                                              |

---

# 🛠️ How Files Connect Together

```plaintext
Terraform (.tf files)
 └─> Proxmox: Create VMs
     └─> VMs boot (cloud-init injects SSH keys)
         └─> Ansible (inventory.ini + playbook.yml)
             └─> Connects via jumpbox
                 └─> Installs MicroK8s, Rancher, ArgoCD
Network
 └─> VMs communicate to each other via vmbr1 (cluster network)
     └─> You Access via vmbr0 (home network) through master-1 static ip via configured DNS (local)
        └─> k8s ingress resolved to services
```
