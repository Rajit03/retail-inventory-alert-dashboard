# Configuration Specification — Retail Inventory Alert Dashboard

This document specifies the Linux node configuration managed by Ansible (Task 13). The playbook **prepares** the node (packages, users, folders, files, ports, and services). Application release deployment, idempotency demonstration, health check of the Node.js app, and rollback are **Task 14**.

---

## 1. Target node and control node

| Role | OS | Connection | Notes |
| :--- | :--- | :--- | :--- |
| Control node | Windows host + WSL 2 distribution **Ubuntu-Retail** (Ubuntu 26.04.1 LTS) | Run Ansible inside WSL: `wsl -d Ubuntu-Retail` | Do **not** use the `Ubuntu` distribution (broken disk). |
| Target node | Same Ubuntu-Retail instance | `ansible_connection=local` (inventory host `retail-node` in group `retail_nodes`) | Passwordless `sudo` for the Linux user. |
| Ansible | `ansible [core 2.20.1]` | Project config `ansible/ansible.cfg` | `ANSIBLE_CONFIG` must be set because `/mnt/c` is world-writable and Ansible otherwise ignores `ansible.cfg`. |

Docker is **not** used inside WSL for this task. Puppet is **not** used. See [How to run](#9-how-to-run) for the exact commands.

---

## 2. Packages

| Name | Purpose |
| :--- | :--- |
| `nginx` | Reverse proxy on port 8300 |
| `curl` | HTTP checks and NodeSource key/repo operations |
| `git` | Source control tools on the node |
| `ca-certificates` | TLS trust store for HTTPS apt repositories |
| `gnupg` | Apt keyring support |
| `build-essential` | Native add-on compilation (for example `better-sqlite3` in a later release) |
| `python3` | Ansible modules on the target |
| `nodejs` | Node.js runtime from **NodeSource** (`node_{{ node_major }}.x`, major version **22**, matching the Dockerfile `FROM node:22-bookworm-slim`) |

Base packages (`nginx`, `curl`, `git`, `ca-certificates`, `gnupg`, `build-essential`, `python3`) are installed by the `common` role. `nodejs` is installed by the `nodejs` role after the NodeSource repository is added.

---

## 3. Users and groups

| Name | Type | Shell | Home | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `retailapp` | system group | — | — | Application group (`app_group`) |
| `retailapp` | system user | `/usr/sbin/nologin` | `/opt/retail-inventory` | No login; `create_home` is false (directories are created by Ansible) |

---

## 4. Folders

| Path | Owner | Mode | Purpose |
| :--- | :--- | :--- | :--- |
| `/opt/retail-inventory` | `retailapp:retailapp` | `755` | Application root (`app_root`) |
| `/opt/retail-inventory/releases` | `retailapp:retailapp` | `755` | Release directories (populated in Task 14) |
| `/opt/retail-inventory/shared/data` | `retailapp:retailapp` | `750` | SQLite database directory (`DB_PATH` parent) |
| `/var/log/retail-inventory` | `retailapp:retailapp` | `750` | Application stdout/stderr logs |
| `/etc/retail-inventory` | `root:retailapp` | `750` | Environment file directory (`env_dir`) |

---

## 5. Files

| Path | Source | Owner | Mode | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `/etc/retail-inventory/retail-inventory.env` | template `retail-inventory.env.j2` | `root:retailapp` | `640` | `NODE_ENV`, `PORT`, `DB_PATH` |
| `/etc/systemd/system/retail-inventory.service` | template `retail-inventory.service.j2` | `root:root` | `644` | systemd unit |
| `/etc/nginx/conf.d/retail-inventory.conf` | template `nginx.conf.j2` | `root:root` | `644` | Nginx server on `nginx_port` |
| `/etc/nginx/sites-enabled/default` | removed (`state: absent`) | — | — | Default site must not steal the default HTTP port |

---

## 6. Ports

| Port | Process | Binding | Purpose |
| :--- | :--- | :--- | :--- |
| `3300` | Node.js (`PORT`) | `127.0.0.1` via Nginx `proxy_pass` | Application behind the reverse proxy (not public) |
| `8300` | Nginx | public listen | Public HTTP entry (`/nginx-health`, later `/health` and `/items`) |

These ports avoid Windows/WSL ports already in use (3001, 3002, 3100, 3200, 5000, 8080, 8095, 8096).

---

## 7. Services

| Unit | Enabled | Started | Notes |
| :--- | :--- | :--- | :--- |
| `nginx` | yes | yes | Reverse proxy; reload via handler after config change (`nginx -t` validation) |
| `retail-inventory` | yes | **only when** `/opt/retail-inventory/current/src/server.js` exists | Defined and enabled now; first start is Task 14 after a release is deployed |

---

## 8. Variables

| Name | Default | Meaning |
| :--- | :--- | :--- |
| `app_name` | `retail-inventory` | Application / unit / env file name |
| `app_user` | `retailapp` | System user that will run the app |
| `app_group` | `retailapp` | System group |
| `app_root` | `/opt/retail-inventory` | Install root |
| `app_data_dir` | `{{ app_root }}/shared/data` | SQLite data directory |
| `app_log_dir` | `/var/log/retail-inventory` | Log directory |
| `env_dir` | `/etc/retail-inventory` | Directory for the environment file |
| `app_port` | `3300` | Node.js listen port (`PORT`) |
| `nginx_port` | `8300` | Public Nginx listen port |
| `node_major` | `22` | NodeSource major version (Dockerfile Node 22) |
| `node_env` | `production` | `NODE_ENV` value |
| `base_packages` | `nginx`, `curl`, `git`, `ca-certificates`, `gnupg`, `build-essential`, `python3` | Packages installed by the `common` role |

Inventory: `ansible/inventory/hosts.ini`. Group variables: `ansible/inventory/group_vars/retail_nodes.yml`. Playbook: `ansible/site.yml` (roles `common`, `nodejs`, `app_service`, `nginx`).

---

## 9. How to run

Always use the **Ubuntu-Retail** WSL distribution (not `Ubuntu`). Ansible ignores `ansible.cfg` in a world-writable folder such as `/mnt/c` unless `ANSIBLE_CONFIG` is set.

From Windows PowerShell:

```powershell
wsl -d Ubuntu-Retail -- echo ok

wsl -d Ubuntu-Retail -- bash -lc "cd /mnt/c/Projects/retail-inventory-alert-dashboard/ansible && export ANSIBLE_CONFIG=/mnt/c/Projects/retail-inventory-alert-dashboard/ansible/ansible.cfg && ansible-playbook site.yml --syntax-check"

wsl -d Ubuntu-Retail -- bash -lc "cd /mnt/c/Projects/retail-inventory-alert-dashboard/ansible && export ANSIBLE_CONFIG=/mnt/c/Projects/retail-inventory-alert-dashboard/ansible/ansible.cfg && ansible-playbook site.yml --check --diff"

wsl -d Ubuntu-Retail -- bash -lc "cd /mnt/c/Projects/retail-inventory-alert-dashboard/ansible && export ANSIBLE_CONFIG=/mnt/c/Projects/retail-inventory-alert-dashboard/ansible/ansible.cfg && ansible-playbook site.yml"

wsl -d Ubuntu-Retail -- bash -lc "cd /mnt/c/Projects/retail-inventory-alert-dashboard/ansible && export ANSIBLE_CONFIG=/mnt/c/Projects/retail-inventory-alert-dashboard/ansible/ansible.cfg && ansible-playbook site.yml --tags nginx"
```

Role tags: `common`, `nodejs`, `app_service`, `nginx`.

This playbook only **prepares** the node. Application release deployment, idempotency demonstration, health check of the Node.js app, and rollback come in **Task 14**.
