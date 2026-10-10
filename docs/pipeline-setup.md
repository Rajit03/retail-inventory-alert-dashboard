# Jenkins Declarative Pipeline & Deployment Guide

This guide documents the automated declarative CI/CD pipeline (`Jenkinsfile`), deployment architecture, releases directory layout, and Nginx reverse proxy integration for the **Retail Inventory Alert Dashboard**.

---

## 1. Pipeline Overview & Stages

The declarative pipeline is defined in the root `Jenkinsfile` and executes the following sequential stages:

```
[ Checkout ] ➔ [ Build ] ➔ [ UI Tests (Selenium) ] ➔ [ Package ] ➔ [ Deploy ]
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
   - **Quality Gate Behavior**: If any UI test fails, the stage fails and terminates the pipeline immediately. **Package and Deploy stages never run on UI test failure.**
   - Generates Surefire HTML report (`mvn surefire-report:report-only`) and cleans up the test server process tree and database.
   - Publishes test results and archives build artifacts in `post { always { ... } }`.
4. **Package**:
   - Removes any existing `*.tgz` archives.
   - Bundles the application using `npm pack`.
   - Archives `*.tgz` and `build-info.json` as build artifacts with fingerprinting.
5. **Deploy**:
   - Maps the selected environment to internal Node.js port and public Nginx proxy port.
   - Executes `scripts/deploy.ps1` wrapped in `JENKINS_NODE_COOKIE=dontKillMe` to prevent Jenkins process tree killer from terminating the background server.
   - Verifies public accessibility through Nginx and prints the application dashboard URL.

---

## 2. Test Results & Build Artifacts in Jenkins

The `UI Tests (Selenium)` stage publishes test reports and archives artifacts so build failures can be inspected effortlessly:

- **Jenkins Test Result Page**: The JUnit plugin parses `tests/selenium/target/surefire-reports/*.xml`, presenting interactive test breakdown, failure stack traces, and historical pass/fail trends.
- **Archived Build Artifacts**:
  - `tests/selenium/target/screenshots/*.png`: Automatic screenshots captured upon any test failure via `ScreenshotOnFailureExtension`.
  - `tests/selenium/target/site/surefire-report.html`: Maven Surefire HTML test report.
  - `tests/selenium/target/ci-app*.log`: Standard output (`ci-app.log`) and standard error (`ci-app-err.log`) from the background test server.

---

## 3. Host & Jenkins Agent Prerequisites

To ensure the automated UI test stage succeeds on the Jenkins agent or `LocalSystem` service:
1. **Java 17+ / JDK**: Required for compiling and running the JUnit 5 / Selenium test suite.
2. **Apache Maven**: `mvn` must be installed and configured in the system `PATH`.
3. **Google Chrome**: Google Chrome must be installed on the host (Selenium Manager automatically provisions compatible ChromeDriver binaries).
4. **Node.js & npm**: Configured on `PATH` for running the server and seed scripts.

---

## 4. Pipeline Parameters

| Parameter | Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `DEPLOY_ENV` | `choice` (`dev`, `staging`) | `dev` | Target environment for deployment |
| `DEPLOY_ROOT` | `string` | `C:\deploy\retail-inventory` | Root folder on the host where application releases are deployed |

---

## 5. Environment to Port Mapping

| Environment | Internal Application Port | Public Nginx Proxy Port | Entrypoint URL |
| :--- | :--- | :--- | :--- |
| **Development (`dev`)** | `3001` | `8095` | `http://localhost:8095/items` |
| **Staging (`staging`)** | `3002` | `8096` | `http://localhost:8096/items` |

---

## 6. Deployment Directory & Release Layout

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

## 7. Nginx Reverse Proxy Setup

Nginx acts as the public reverse proxy fronting the Node.js application.

- **Configuration File**: [`deploy/nginx/retail-inventory.conf`](../deploy/nginx/retail-inventory.conf)
- **Installation & Operations Guide**: See [`deploy/nginx/README.md`](../deploy/nginx/README.md) for Windows installation, configuration inclusion in `nginx.conf`, startup (`start nginx`), reload (`nginx -s reload`), and shutdown procedures.

---

## 8. Jenkins Pipeline Job Setup

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
