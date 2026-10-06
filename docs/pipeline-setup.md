# Jenkins Declarative Pipeline & Deployment Guide

This guide documents the automated declarative CI/CD pipeline (`Jenkinsfile`), deployment architecture, releases directory layout, and Nginx reverse proxy integration for the **Retail Inventory Alert Dashboard**.

---

## 1. Pipeline Overview & Stages

The declarative pipeline is defined in the root `Jenkinsfile` and executes the following sequential stages:

```
[ Checkout ] ➔ [ Build ] ➔ [ UI Tests (Selenium) ] ➔ [ Package ] ➔ [ Docker Build ] ➔ [ Docker Push ] ➔ [ Deploy Container ]
```

1. **Checkout**: Checks out source code from Git SCM, prints the current commit hash, and logs user-selected parameters (`DEPLOY_ENV`, `DEPLOY_ROOT`).
2. **Build**:
   - Displays Node.js and npm runtime versions (`node -v`, `npm -v`).
   - Runs clean dependency installation (`npm ci`).
   - Executes validation and build metadata generation (`npm run build`).
   - Executes unit tests and API smoke tests (`npm test`).
3. **UI Tests (Selenium) — Quality Gate**:
   - Runs `scripts/run-selenium-ci.ps1` using PowerShell.
   - Cleans up existing port 3100 listeners, creates a dedicated test database (`data/selenium-ci.db`), seeds sample data, and boots an isolated background test instance.
   - Polls `/health` until ready, then executes the full Maven Selenium WebDriver E2E suite (`mvn test`) in headless Chrome against `http://localhost:3100`.
   - **Quality Gate Behavior**: If any UI test fails, the stage fails and terminates the pipeline immediately. **Package, Docker Build, Docker Push, and Deploy Container never run on UI test failure.**
   - Generates Surefire HTML report (`mvn surefire-report:report-only`) and cleans up the test server process tree and database.
   - Publishes test results and archives build artifacts in `post { always { ... } }`.
4. **Package**:
   - Removes any existing `*.tgz` archives.
   - Bundles the application using `npm pack`.
   - Archives `*.tgz` and `build-info.json` as build artifacts with fingerprinting.
5. **Docker Build**:
   - Runs `docker version` first and fails fast if the Docker engine is unreachable.
   - Reads `package.json` version and tags the image as `<version>-<BUILD_NUMBER>` (for example `1.0.0-12`).
   - Builds `localhost:5000/retail-inventory-alert:<version>-<BUILD_NUMBER>` and `:latest` with `build.number` and `git.commit` labels.
6. **Docker Push**:
   - Runs `scripts/ensure-registry.ps1` so the local registry container is running.
   - Pushes the versioned tag and `:latest`, then writes `docker-registry-evidence.txt`.
7. **Deploy Container**:
   - Maps `dev` to host port `3001` (Nginx `8095`) and `staging` to host port `3002` (Nginx `8096`).
   - Runs `scripts/deploy-container.ps1` to pull the registry image, replace `retail-inventory-<env>`, stop any leftover Task 8 `app.pid` process, wait until the container is healthy, and seed an empty database.
   - Automated rollback of a previous image is **not** implemented yet (later task).

---

## 2. Test Results & Build Artifacts in Jenkins

The `UI Tests (Selenium)` stage publishes test reports and archives artifacts so build failures can be inspected effortlessly:

- **Jenkins Test Result Page**: The JUnit plugin parses `tests/selenium/target/surefire-reports/*.xml`, presenting interactive test breakdown, failure stack traces, and historical pass/fail trends.
- **Archived Build Artifacts**:
  - `tests/selenium/target/screenshots/*.png`: Automatic screenshots captured upon any test failure via `ScreenshotOnFailureExtension`.
  - `tests/selenium/target/site/surefire-report.html`: Maven Surefire HTML test report.
  - `tests/selenium/target/ci-app*.log`: Standard output (`ci-app.log`) and standard error (`ci-app-err.log`) from the background test server.
  - `*.tgz` and `build-info.json`: npm pack archive and build metadata.
  - `docker-registry-evidence.txt`: image reference, timestamp, `GET /v2/_catalog`, and `GET /v2/retail-inventory-alert/tags/list`.
  - `docker-state.txt`: `docker ps -a --filter name=retail-inventory` and `docker images localhost:5000/retail-inventory-alert` captured in `post { always }`.

---

## 3. Host & Jenkins Agent Prerequisites

To ensure the automated UI test stage succeeds on the Jenkins agent or `LocalSystem` service:
1. **Java 17+ / JDK**: Required for compiling and running the JUnit 5 / Selenium test suite.
2. **Apache Maven**: `mvn` must be installed and configured in the system `PATH`.
3. **Google Chrome**: Google Chrome must be installed on the host (Selenium Manager automatically provisions compatible ChromeDriver binaries).
4. **Node.js & npm**: Configured on `PATH` for running the server and seed scripts.
5. **Docker Engine**: Jenkins must run as a **user that can use Docker** (the agent account must be able to run `docker version`, `docker build`, `docker push`, and `docker run`). If Jenkins runs as `LocalSystem` or another account that cannot talk to Docker Desktop, Docker Build / Docker Push / Deploy Container will fail even when your interactive user can run Docker.

---

## 4. Pipeline Parameters

| Parameter | Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `DEPLOY_ENV` | `choice` (`dev`, `staging`) | `dev` | Target environment for deployment |
| `DEPLOY_ROOT` | `string` | `C:\deploy\retail-inventory` | Root folder used to locate leftover Task 8 `app.pid` files |
| `REGISTRY` | `string` | `localhost:5000` | Local Docker registry host:port |

---

## 5. Environment to Port Mapping

| Environment | Internal Application Port | Public Nginx Proxy Port | Entrypoint URL |
| :--- | :--- | :--- | :--- |
| **Development (`dev`)** | `3001` | `8095` | `http://localhost:8095/items` |
| **Staging (`staging`)** | `3002` | `8096` | `http://localhost:8096/items` |

---

## 6. Docker Registry, Image Tags, and Containers

After tests pass, the pipeline builds a **versioned** image, publishes it to a **local registry**, and deploys a **fresh container** from that registry image. This replaces the Task 8 host process deployment (`scripts/deploy.ps1`). Nginx on `8095` / `8096` is unchanged because the container still publishes the same host ports (`3001` / `3002`).

### Image tag format

`localhost:5000/retail-inventory-alert:<package.json version>-<Jenkins BUILD_NUMBER>`

Example: `localhost:5000/retail-inventory-alert:1.0.0-12`. The pipeline also tags and pushes `:latest`.

### Local registry

| Item | Value |
| :--- | :--- |
| Container name | `registry` |
| Image | `registry:2` |
| Host port | `5000` (`-p 5000:5000`) |
| Data volume | `registry-data` → `/var/lib/registry` |
| Restart policy | `unless-stopped` |
| Catalog API | `http://localhost:5000/v2/` |

`scripts/ensure-registry.ps1` is idempotent: it starts a stopped `registry` container or creates one if missing, then waits until `http://localhost:5000/v2/` responds.

### Container per environment

| Environment | Container name | Host port | Nginx port | Named volume |
| :--- | :--- | :--- | :--- | :--- |
| `dev` | `retail-inventory-dev` | `3001` → container `3000` | `8095` | `retail-inventory-dev-data` → `/app/data` |
| `staging` | `retail-inventory-staging` | `3002` → container `3000` | `8096` | `retail-inventory-staging-data` → `/app/data` |

Labels: `deploy.environment=<env>`, `deploy.build=<BUILD_NUMBER>`. On replace, the script prints `Previous image: <ref>` for a later rollback task (not implemented here). Local tags of `localhost:5000/retail-inventory-alert` are pruned to the **5 newest**.

---

## 7. Deployment Directory & Release Layout (Task 8, superseded for runtime)

The Task 8 process deployment (`scripts/deploy.ps1`) is no longer used by the Jenkins runtime path. Container deploy still stops `<DeployRoot>\<env>\app.pid` if it exists so host ports `3001`/`3002` are free. The old layout remains on disk:

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

## 8. Nginx Reverse Proxy Setup

Nginx acts as the public reverse proxy fronting the Node.js application.

- **Configuration File**: [`deploy/nginx/retail-inventory.conf`](../deploy/nginx/retail-inventory.conf)
- **Installation & Operations Guide**: See [`deploy/nginx/README.md`](../deploy/nginx/README.md) for Windows installation, configuration inclusion in `nginx.conf`, startup (`start nginx`), reload (`nginx -s reload`), and shutdown procedures.

---

## 9. Jenkins Pipeline Job Setup

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
