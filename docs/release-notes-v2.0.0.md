# Release Notes - v2.0.0 (Final DevOps Release)

**Release Date:** October 10, 2026  
**Pipeline Run:** Jenkins Build #33 (Fully Green)  
**Target Environments:** Docker Dev Container (`:3001`), Windows Nginx Reverse Proxy (`:8095`), Ansible WSL Node (`:8300` / `172.22.235.151:8300`)

---

## 1. Project Milestone & Task Summary (Tasks 1 - 15)

The table below summarizes the comprehensive DevOps lifecycle and deliverables implemented across the 15 mini-project tasks:

| Task # | Milestone & Feature | Key Deliverables & Outcome |
| :---: | :--- | :--- |
| **Task 1** | **Project Setup & Architecture** | Initialized Node.js/Express web project, established Git repository with Gitflow branching (`main`, `develop`), and created initial baseline layout. |
| **Task 2** | **Item Catalogue Management** | Implemented CRUD routes and EJS views for retail items (SKU, name, category, price, quantity, reorder threshold) backed by SQLite. |
| **Task 3** | **Transactions & Stock Management** | Added stock receipts (IN) and sales deductions (OUT) with server-side validation preventing negative quantities and recording audit history. |
| **Task 4** | **Search, Filter & Exception Alerts** | Built real-time keyword search, category filtering, and automated low-stock and out-of-stock exception dashboards (`NORMAL`, `LOW STOCK`, `OUT OF STOCK`). |
| **Task 5** | **Unit Testing & Model Validation** | Developed automated Node.js test suites validating inventory calculations, negative stock guards, and REST API contract endpoints. |
| **Task 6** | **Selenium WebDriver UI Quality Gate** | Built Java/Maven Selenium regression test suite using Page Object Model (POM), explicit waits, and automated failure screenshot capture. |
| **Task 7** | **CI Environment & Service Toolchain** | Configured Windows developer environment with Node.js, Python 3.13, JDK 21, Maven 3.9, and headless ChromeDriver. |
| **Task 8** | **Jenkins CI Pipeline** | Implemented declarative `Jenkinsfile` with automated SCM polling (`pollSCM`), dependency installation (`call npm ci`), unit tests, Selenium UI gate, and `.tgz` packaging. |
| **Task 9** | **Service Account & Process Management** | Reconfigured Jenkins Windows Service to execute under the developer user account with access to Docker Desktop and WSL 2, and solved background process termination with `JENKINS_NODE_COOKIE`. |
| **Task 10** | **Docker Containerization** | Designed a multi-stage `Dockerfile` with native C++ compilation (`python3`, `make`, `g++`) for `better-sqlite3` and persistent named volumes. |
| **Task 11** | **Local Docker Registry** | Established private Docker Registry v2 container on `localhost:5000` with automated image tagging (`version-BUILD_NUMBER` and `latest`) and evidence generation. |
| **Task 12** | **Continuous Deployment & Reverse Proxy** | Built `deploy-container.ps1` for automated zero-downtime container replacement, port conflict cleanup, health checks, and configured Windows Nginx proxy on port `8095`. |
| **Task 13** | **Ansible Configuration Management** | Provisioned dedicated WSL 2 Linux distribution (`Ubuntu-Retail`) via Ansible roles (`common`, `nginx`), configuring systemd service `retail-inventory` and Linux Nginx on port `8300`. |
| **Task 14** | **Ansible Atomic Release & Rollback** | Engineered zero-downtime release deployment playbook (`deploy.yml`) managing `/opt/retail-inventory/releases` with atomic symlinks (`current`, `stable`, `previous`) and automated fault rollback. |
| **Task 15** | **Unified Pipeline & End-to-End Release** | Extended Jenkins pipeline to orchestrate Docker and Ansible deployments from a single commit, hardened deployment scripts, built `preflight.ps1`, and created complete documentation. |

---

## 2. Final System Architecture Summary

The **Retail Inventory Alert Dashboard** employs a dual-target continuous delivery architecture orchestrated entirely through Jenkins:

1. **Source Control**: Commits are merged into `develop` via pull requests on GitHub.
2. **Continuous Integration**: Jenkins polls GitHub every 2 minutes, running linting, unit tests, and headless Chrome Selenium UI regression suites on an ephemeral application instance (`:3100`).
3. **Artifact Packaging**: Successful builds produce production npm tarballs (`.tgz`) and immutable multi-stage Docker images (`localhost:5000/retail-inventory-alert:<tag>`).
4. **Containerized Continuous Deployment**: Jenkins deploys the Docker container to host port `3001` (`retail-inventory-dev`), verifies port mapping via `docker port`, and routes ingress through Windows Nginx on port `8095`.
5. **Ansible Bare-Metal Continuous Deployment**: Jenkins invokes Ansible inside WSL 2 (`Ubuntu-Retail`), unpacking the release tarball to `/opt/retail-inventory/releases/b<N>`, switching the atomic `current` symlink, restarting systemd (`retail-inventory.service`), and validating health via Linux Nginx on port `8300`.
6. **End-to-End Verification**: Synthetic verification script (`scripts/e2e-verify.ps1`) asserts health across Docker `:3001`, WSL `:8300`, the Items REST API, and Windows Nginx proxy, archiving `e2e-verification.txt`.

---

## 3. CI/CD Pipeline Stages (in Execution Order)

```text
1. Checkout                  -> Clones Git revision and logs environment parameters
2. Build                     -> Executes npm ci, verifies Express module, and runs unit tests
3. UI Tests (Selenium)       -> Spawns ephemeral test server on :3100; executes headless Chrome POM tests
4. Package                   -> Packages application tarball (*.tgz) and generates build-info.json
5. Docker Build              -> Builds multi-stage Docker image with native SQLite compilation
6. Docker Push               -> Pushes versioned and latest image tags to local registry on port 5000
7. Deploy Container          -> Clears host port 3001 conflicts, starts fresh container, asserts health
8. Provision Node (Ansible)  -> Runs ansible-playbook site.yml in WSL Ubuntu-Retail (idempotent)
9. Deploy Release (Ansible)  -> Deploys tarball, updates atomic symlink, restarts systemd, auto-rolls back on failure
10. End-to-End Verification  -> Synthetic verification of Docker, WSL node, Items API, and Nginx proxy
```

---

## 4. Environment & Network Port Allocation

| Port | Service / Component | Target Host | Purpose & Ingress Route |
| :---: | :--- | :--- | :--- |
| **3000** | Standalone Local Dev | Windows Host | Standalone developer execution (`npm start`). |
| **3001** | Docker Container (`retail-inventory-dev`) | Docker Host Port | Production-like containerized runtime deployed from registry. |
| **3002** | Docker Container (`retail-inventory-staging`) | Docker Host Port | Staging runtime container (optional / on-demand parameter). |
| **3100** | Selenium Test Instance | Windows Host | Ephemeral background application for CI UI tests. |
| **3200** | Manual Docker Demo | Docker Host Port | Standalone manual demonstration and sandbox container. |
| **3300** | Node.js App Service | WSL 2 (`Ubuntu-Retail`) | Internal Express app service managed by systemd. |
| **5000** | Local Docker Registry v2 | Docker Container | Private container registry storing build image artifacts. |
| **8080** | Jenkins CI/CD Server | Windows Host | Central automation server orchestrating the 10-stage pipeline. |
| **8095** | Windows Nginx Dev Proxy | Windows Host | Reverse proxy routing incoming traffic to container port 3001. |
| **8096** | Windows Nginx Staging Proxy | Windows Host | Reverse proxy routing incoming traffic to container port 3002. |
| **8300** | Linux Nginx Reverse Proxy | WSL 2 (`Ubuntu-Retail`) | Ingress proxy forwarding traffic to internal service port 3300. |

---

## 5. Live Demonstration Change: "v2.0 DevOps Edition" Badge

To demonstrate end-to-end continuous delivery across all runtime environments, a visible UI badge was introduced:
- **Change**: Added `<span class="badge-devops">v2.0 DevOps Edition</span>` to the shared header partial (`src/views/partials/header.ejs`) with custom styling in `public/css/style.css`.
- **Flow**: Merged via Pull Request #27 into `develop`, triggering Jenkins Build #33.
- **Propagation Outcome**:
  - **Docker Dev Container (`http://localhost:3001/items`)**: Badge verified (1 occurrence).
  - **Windows Nginx Ingress (`http://localhost:8095/items`)**: Badge verified (1 occurrence).
  - **Ansible WSL Node (`http://172.22.235.151:8300/items`)**: Badge verified (1 occurrence).
  - **Ansible WSL Internal (`http://localhost:8300/items` in WSL)**: Badge verified (1 occurrence).

---

## 6. Known Limitations & Roadmap

A comprehensive, candid architectural evaluation of the current single-workstation demonstration environment is documented in [docs/limitations-and-future-enhancements.md](file:///c:/Projects/retail-inventory-alert-dashboard/docs/limitations-and-future-enhancements.md):

- **Single Host Topology**: Jenkins, Docker Desktop, WSL 2, and Nginx run on a single developer workstation without distributed node fault tolerance.
- **Local Registry**: Docker registry on port 5000 operates over HTTP without TLS certificates or user authentication.
- **Database Concurrency**: Embedded SQLite utilizes file-level locking, unsuitable for multi-replica horizontal clustering.
- **Authentication**: Application currently provides open access without user sessions or Role-Based Access Control (RBAC).
- **SCM Polling**: Local Jenkins instance behind NAT relies on 2-minute polling (`pollSCM`) rather than inbound webhooks.
- **Network Isolation**: WSL 2 Linux Nginx on port 8300 is bound within the WSL utility VM network (`172.22.235.151`) and requires host port forwarding to bind directly to Windows `localhost:8300`.
