# proxmox-lab

A personal DevOps homelab project that provisions an Ubuntu VM on Proxmox using Terraform and configures it with Ansible. The VM runs a Java blog application with a full monitoring stack and a Cloudflare tunnel for secure external access. Proxmox was chosen over VMware and Hyper-V for its minimal host overhead, leaving maximum resources available for VMs, and its first-class Terraform provider support.

---

## Architecture

```
Local Machine
│
├── Terraform → Proxmox (creates VM from Cloud-Init template, static IP)
│
└── Ansible → Remote VM
        ├── Role: docker        (installs Docker + Docker Compose)
        ├── Role: docker_deploy (deploys tunnel stack)
        │       └── cloudflared
        └── Role: docker_deploy (deploys blog stack)
                ├── Java blog application
                ├── PostgreSQL
                ├── Redis
                ├── Grafana
                ├── Prometheus
                └── Node Exporter
```

---

## Project Structure

```
proxmox-lab/
├── ansible/
│   ├── ansible.cfg                # Ansible configuration
│   ├── hosts.ini                  # Inventory (static IP assigned by Terraform)
│   ├── playbook.yml               # Main playbook
│   ├── docker.yml                 # Docker installation playbook
│   ├── group_vars/
│   │   └── all/
│   │       └── vault.yml          # encrypted with ansible-vault
│   ├── roles/
│   │   ├── docker/
│   │   │   ├── defaults/
│   │   │   │   └── main.yml
│   │   │   └── tasks/
│   │   │       └── main.yml
│   │   └── docker_deploy/
│   │       ├── defaults/
│   │       │   └── main.yml
│   │       └── tasks/
│   │           └── main.yml
│   └── blog-app/
│       ├── blog/
│       │   ├── docker-compose.yml
│       │   ├── .env.j2            # rendered from vault at deploy time
│       │   └── prometheus/
│       │       └── prometheus.yml
│       └── tunnel/
│           ├── docker-compose.yml
│           └── .env.j2            # rendered from vault at deploy time
├── terraform/
│   └── main.tf
├── Makefile                       # Deployment shortcuts
├── .gitignore
└── README.md
```

---

## Prerequisites

- Proxmox VE with a Cloud-Init ready Ubuntu Server template
- Terraform installed locally
- Ansible installed locally
- `make` installed locally (`sudo dnf install make -y` on Fedora)
- `community.docker` Ansible collection:
  ```bash
  ansible-galaxy collection install community.docker
  ```

---

## Usage

### Full deployment (Terraform + Ansible)

```bash
make deploy
```

### Terraform only (provision VM)

```bash
make terraform
```

### Ansible only (configure existing VM)

```bash
make provision
```

### Destroy VM

```bash
make destroy
```

---

## Makefile

```makefile
.PHONY: deploy terraform provision destroy

deploy:
    cd terraform && terraform apply -auto-approve
    ansible-playbook playbook.yml --vault-password-file ~/.vault_pass

terraform:
    cd terraform && terraform apply -auto-approve

provision:
    ansible-playbook playbook.yml --vault-password-file ~/.vault_pass

destroy:
    cd terraform && terraform destroy -auto-approve
```

---

## Ansible

### ansible.cfg

```ini
[defaults]
inventory = hosts.ini
host_key_checking = False
retry_files_enabled = False
stdout_callback = default
result_format = yaml
roles_path = ./roles
callbacks_enabled = timer, profile_tasks

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

### playbook.yml

Roles run sequentially. The tunnel stack starts before the blog stack.

```yaml
- name: Wait for server to become ready
  hosts: server_01
  gather_facts: false
  tasks:
    - name: Wait for SSH to become available
      ansible.builtin.wait_for_connection:
        timeout: 120
    - name: Gather facts
      ansible.builtin.setup:

- name: Deploy blog applications
  hosts: server_01
  become: true
  roles:
    - role: docker
    - role: docker_deploy
      vars:
        app_name: tunnel
        docker_deploy_src: blog-app/tunnel/
        docker_deploy_dest: /opt/blog-app/tunnel
        docker_deploy_state: present
    - role: docker_deploy
      vars:
        app_name: blog
        docker_deploy_src: blog-app/blog/
        docker_deploy_dest: /opt/blog-app/blog
        docker_deploy_state: present
```

### Roles

**`docker`** — installs Docker Engine and Docker Compose plugin on the remote VM.

**`docker_deploy`** — generic role that copies a local compose project to the remote server and starts it.

| Variable | Default | Description |
|---|---|---|
| `docker_deploy_src` | `""` | Local source folder (trailing slash copies contents) |
| `docker_deploy_dest` | `""` | Remote destination path |
| `docker_deploy_state` | `present` | Compose state: `present`, `stopped`, `restarted`, `absent` |

---

## Secrets

`.env` files contain sensitive values (DB passwords, API keys, tokens). I do **not** commit them to version control.

I store encrypted secrets in Ansible Vault and render `.env` files from Jinja2 templates at deploy time.

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

---

## Deployment Order

1. Terraform provisions the VM on Proxmox with a static IP and Cloud-Init
2. Ansible waits for SSH to become available
3. `docker` role installs Docker on the VM
4. `docker_deploy` deploys the **tunnel** stack (Cloudflare tunnel comes up first)
5. `docker_deploy` deploys the **blog** stack (app, DB, monitoring)

---

## Access

| Service | URL |
|---|---|
| Blog | https://blog.udris.dev |
| Grafana | https://grafana.udris.dev |

> Grafana default credentials are set via the `GF_SECURITY_ADMIN_PASSWORD` environment variable in `blog/.env`.
