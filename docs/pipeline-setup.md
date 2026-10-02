# Jenkins Declarative Pipeline & Deployment Guide

This guide documents the automated declarative CI/CD pipeline (`Jenkinsfile`), deployment architecture, releases directory layout, and Nginx reverse proxy integration for the **Retail Inventory Alert Dashboard**.

---

## 1. Pipeline Overview & Stages

The declarative pipeline is defined in the root `Jenkinsfile` and executes the following sequential stages:

```
[ Checkout ] ➔ [ Build ] ➔ [ Package ] ➔ [ Deploy ]
```

1. **Checkout**: Checks out source code from Git SCM, prints the current commit hash, and logs user-selected parameters (`DEPLOY_ENV`, `DEPLOY_ROOT`).
2. **Build**:
   - Displays Node.js and npm runtime versions (`node -v`, `npm -v`).
   - Runs clean dependency installation (`npm ci`).
   - Executes validation and build metadata generation (`npm run build`).
   - Executes unit tests and API smoke tests (`npm test`).
3. **Package**:
   - Removes any existing `*.tgz` archives.
   - Bundles the application using `npm pack`.
   - Archives `*.tgz` and `build-info.json` as build artifacts with fingerprinting.
4. **Deploy**:
   - Maps the selected environment to internal Node.js port and public Nginx proxy port.
   - Executes `scripts/deploy.ps1` wrapped in `JENKINS_NODE_COOKIE=dontKillMe` to prevent Jenkins process tree killer from terminating the background server.
   - Verifies public accessibility through Nginx and prints the application dashboard URL.

---

## 2. Pipeline Parameters

| Parameter | Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `DEPLOY_ENV` | `choice` (`dev`, `staging`) | `dev` | Target environment for deployment |
| `DEPLOY_ROOT` | `string` | `C:\deploy\retail-inventory` | Root folder on the host where application releases are deployed |

---

## 3. Environment to Port Mapping

| Environment | Internal Application Port | Public Nginx Proxy Port | Entrypoint URL |
| :--- | :--- | :--- | :--- |
| **Development (`dev`)** | `3001` | `8081` | `http://localhost:8081/items` |
| **Staging (`staging`)** | `3002` | `8082` | `http://localhost:8082/items` |

---

## 4. Deployment Directory & Release Layout

The deployment script (`scripts/deploy.ps1`) establishes an enterprise-grade atomic release layout per environment:

```text
C:\deploy\retail-inventory\<env>\
├── releases\
│   ├── <BUILD_NUMBER_1>\      # Extracted package, npm ci --omit=dev
│   ├── <BUILD_NUMBER_2>\      # Latest release
│   └── ...                    # (Retains 3 newest releases; older ones pruned)
├── current                     # Directory junction pointing to active release
├── shared\
│   └── data\
│       └── inventory.db       # SQLite database (persists across deployments)
├── logs\
│   ├── app.log                # Standard output from Node.js
│   └── err.log                # Standard error from Node.js
└── app.pid                    # Process ID of running background server
```

### Key Deployment Lifecycle Behaviors:
- **Zero Data Loss**: Database file lives in `shared\data\inventory.db` and is never overwritten on new releases. If not present on initial deployment, `npm run seed` is executed once.
- **Atomic Switching**: Updates the `current` NTFS directory junction to point to the new build folder.
- **Graceful Process Management**: Stops previous process using `app.pid` prior to switching.
- **Automated Health Validation**: Polls `http://localhost:<Port>/health` every 2s for up to 30s. If the health check fails, the last 20 lines of `err.log` are reported and the pipeline fails.
- **Automated Retention**: Keeps the 3 newest releases and cleans up older builds after a successful health check.

---

## 5. Nginx Reverse Proxy Setup

Nginx acts as the public reverse proxy fronting the Node.js application.

- **Configuration File**: [`deploy/nginx/retail-inventory.conf`](../deploy/nginx/retail-inventory.conf)
- **Installation & Operations Guide**: See [`deploy/nginx/README.md`](../deploy/nginx/README.md) for Windows installation, configuration inclusion in `nginx.conf`, startup (`start nginx`), reload (`nginx -s reload`), and shutdown procedures.

---

## 6. Jenkins Pipeline Job Setup

To create the automated Jenkins Pipeline job:

1. In Jenkins dashboard, click **New Item**.
2. Enter item name (e.g. `retail-inventory-pipeline`) and select **Pipeline**, then click **OK**.
3. Under the **Pipeline** configuration section:
   - **Definition**: Select `Pipeline script from SCM`.
   - **SCM**: Select `Git`.
   - **Repository URL**: `https://github.com/Rajit03/retail-inventory-alert-dashboard.git`
   - **Branch Specifier**: `*/develop`
   - **Script Path**: `Jenkinsfile`
4. Click **Save**.
5. Run the job via **Build with Parameters** to select `DEPLOY_ENV` and trigger the automated pipeline.
