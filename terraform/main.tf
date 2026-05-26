terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc04"
    }
  }
}

provider "proxmox" {
  pm_api_url      = "https://192.168.88.200:8006/api2/json"
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "ubuntu_vm" {
  name        = "server-01"
  target_node = "proxmox"
  clone       = "ubuntu-template"
  full_clone  = true
  os_type     = "cloud-init"
  agent       = 1

  cpu { cores = 2 }
  memory = 2048

  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disk {
    slot     = "scsi0"
    size     = "15G"
    type     = "disk"
    storage  = "local-lvm"
    iothread = true
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-lvm"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  ipconfig0  = "ip=192.168.88.101/24,gw=192.168.88.1"
  nameserver = "8.8.8.8"

  ciuser     = "ubuntu"
  cipassword = "1234"

  sshkeys = file("~/.ssh/key1.pub")
}

