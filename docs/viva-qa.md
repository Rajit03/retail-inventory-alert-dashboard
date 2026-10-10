# Comprehensive DevOps Viva & Technical Interview Q&A

This document compiles **30 core technical viva questions and concise, production-grounded answers** covering the architecture, toolchains, automation, and operational decisions implemented across this project.

---

### 1. Git & Version Control

#### Q1: What branching model is used in this repository, and why?
**Answer:** A Gitflow-inspired branching model with `main` (production-ready code), `develop` (integration and staging branch), and ephemeral `feature/*` branches (isolated feature development). Direct pushes to `main` and `develop` are prohibited; changes are integrated solely through Pull Requests to guarantee code review and CI verification.

#### Q2: How do you identify and resolve merge conflicts between parallel feature branches?
**Answer:** A merge conflict occurs when Git cannot automatically reconcile concurrent line modifications across branches. To resolve: checkout the feature branch, run `git merge develop` (or `git rebase develop`), inspect conflicting markers (`<<<<<<<`, `=======`, `>>>>>>>`), manually edit the files to the desired state, run unit tests to verify correctness, and commit the resolved files with `git commit`.

#### Q3: What is the purpose of a Pull Request (PR) in modern CI/CD?
**Answer:** A Pull Request provides a formal review gate allowing peers to inspect diffs, comment on design decisions, and enforce automated status checks (e.g., automated test passes) prior to merging code into core branches, preventing regressions on shared branches.

---

### 2. CI/CD Pipeline & Jenkins

#### Q4: What is the core distinction between Continuous Integration (CI) and Continuous Delivery (CD)?
**Answer:** **CI** automates the building, packaging, and testing of code upon every commit to detect defects early. **Continuous Delivery (CD)** extends CI by automatically staging and preparing tested artifacts for release. In this project, Jenkins executes CI (lint, unit tests, Selenium UI gate) and CD (Docker image build/push, container deployment, and Ansible bare-metal release).

#### Q5: Explain the structure of the Declarative Jenkinsfile used in this project.
**Answer:** The `Jenkinsfile` defines a `pipeline {}` block with global `options` (timestamps, log rotation, disable concurrent builds), `triggers` (`pollSCM`), `parameters` (`DEPLOY_ENV`, `DEPLOY_ROOT`, `REGISTRY`, `RUN_ANSIBLE`), an `environment` block, and sequential `stages` (`Checkout`, `Build`, `UI Tests`, `Package`, `Docker Build`, `Docker Push`, `Deploy Container`, `Provision Node`, `Deploy Release`, `End-to-End Verification`), concluding with structured `post` actions (`success`, `failure`, `always`).

#### Q6: What pipeline parameters are configurable, and what are their defaults?
**Answer:**
- `DEPLOY_ENV` (choice: `dev`, `staging`; default `dev`): determines target ports, container names, and proxy routes.
- `DEPLOY_ROOT` (string; default `C:\deploy\retail-inventory`): root path for legacy host deployments.
- `REGISTRY` (string; default `localhost:5000`): target Docker registry endpoint.
- `RUN_ANSIBLE` (boolean; default `true`): controls whether Ansible WSL node provisioning, deployment, and verification stages execute.

#### Q7: Why does the pipeline use SCM Polling (`pollSCM`) instead of GitHub Webhooks?
**Answer:** The Jenkins server is self-hosted locally on Windows behind NAT without a public IP or inbound domain. Since GitHub cannot send HTTP POST payloads directly to an unreachable private IP, Jenkins periodically checks the GitHub repository every two minutes (`H/2 * * * *`) for new commits.

---

### 3. Selenium & UI Testing Quality Gate

#### Q8: What role does the Selenium UI test suite serve in the pipeline?
**Answer:** It acts as a mandatory **quality gate** between the Build and Package stages. If any Selenium UI test fails, the pipeline aborts immediately, blocking downstream artifact packaging, Docker builds, and deployment.

#### Q9: What is the Page Object Model (POM) pattern, and how is it used here?
**Answer:** POM is an architectural design pattern that abstracts web page UI structure and actions into dedicated Java classes (e.g., `ItemsPage.java`, `AlertsPage.java`, `TransactionsPage.java`), separating UI locators and interactions from test logic (`SearchFilterTest.java`). This maximizes maintainability when UI templates change.

#### Q10: Why are Explicit Waits preferred over Implicit Waits in Selenium?
**Answer:** Implicit waits apply a blanket timeout across all element lookups, masking race conditions and slowing suite execution. Explicit waits (`WebDriverWait` with `ExpectedConditions.visibilityOfElementLocated`) wait dynamically for specific condition states to be satisfied before proceeding, ensuring deterministic test execution without arbitrary sleep pauses.

#### Q11: How does the Selenium suite capture failure diagnostics?
**Answer:** Test suites integrate JUnit listeners (`TestWatcher`) that intercept failed test methods, automatically invoking `TakesScreenshot` to save timestamped `.png` screenshots to `tests/selenium/target/screenshots/`, while test container logs are preserved in `ci-app.log`.

---

### 4. Containerization & Docker

#### Q12: Why was a multi-stage Dockerfile necessary for this Node.js application?
**Answer:** The project uses `better-sqlite3`, an embedded database engine containing native C++ bindings that require compilation via `python3`, `make`, and `g++`. A multi-stage build uses a heavier build stage (`node:22-alpine` with build tools) to compile native addons, copying only compiled outputs into a lightweight, stripped runtime image without bloating image size or retaining compiler tools.

#### Q13: What are Docker image layers, and how does layer caching optimize CI build times?
**Answer:** Each instruction in a `Dockerfile` (`FROM`, `COPY`, `RUN`) generates an immutable read-only layer. Docker caches layers; if preceding layers and dependencies (`package.json`, `package-lock.json`) have not changed, Docker reuses cached layers, avoiding redundant dependency downloads and speeding up CI builds.

#### Q14: How does data persist across Docker container restarts and redeployments?
**Answer:** Application databases are stored on a persistent Docker named volume (`retail-inventory-dev-data`) mounted to `/app/data` inside the container. When `retail-inventory-dev` is stopped and recreated with a new image, the named volume remains attached, preventing data loss.

#### Q15: What is the difference between Docker's internal `HEALTHCHECK` and pipeline health validation?
**Answer:** Docker's `HEALTHCHECK` runs inside the container engine periodically (e.g., querying `http://localhost:3000/health`) and marks the container as `healthy` or `unhealthy` in `docker ps`. The pipeline health check validates host accessibility externally across host port bindings (`http://localhost:3001/health`) and reverse proxy ingress paths.

#### Q16: What is the difference between immutable image tags and the `latest` tag?
**Answer:** Immutable tags (e.g., `retail-inventory-alert:1.0.0-15`) tie an exact container image build to a specific CI build number and Git commit SHA, ensuring auditability and reproducible rollbacks. The `latest` tag is a mutable pointer that tracks the most recent build for convenient testing.

#### Q17: What is the role of the local Docker registry container on port 5000?
**Answer:** It acts as an isolated, self-hosted Docker Registry v2 (`registry:2`), providing a decoupled artifact repository where newly built images are pushed, stored, and subsequently pulled by deployment scripts.

---

### 5. Configuration Management & Ansible

#### Q18: What is Ansible idempotency, and why is it critical?
**Answer:** Idempotency means executing an Ansible playbook multiple times on a target system results in the exact same system state without unintended changes or errors (`changed=0`). This ensures predictability and prevents configuration drift across deployments.

#### Q19: Explain the role-based structure used in the Ansible directory.
**Answer:** Playbooks are partitioned into reusable roles:
- `common`: base system packages, node runtime, user creation.
- `nginx`: reverse proxy installation, virtual host configuration, template deployment.
- `release`: package extraction, dependency installation, atomic symlink manipulation, systemd management, and health verification.

#### Q20: What are Ansible Handlers, and when do they execute?
**Answer:** Handlers are special tasks triggered by `notify` directives (e.g., `notify: restart retail-inventory`). They execute once at the very end of the playbook play only if a preceding task actually made a change (`changed: true`), preventing unnecessary service restarts.

#### Q21: What are Jinja2 templates, and how are they used in Ansible?
**Answer:** Jinja2 (`.j2`) templates allow dynamic file generation using Ansible variables and facts. For example, `nginx.conf.j2` dynamically substitutes hostnames, proxy ports (`8300`), and backend targets (`3300`) based on group variables.

#### Q22: How does Ansible Inventory organize target environments?
**Answer:** The inventory file (`ansible/inventory/hosts.ini`) groups managed nodes (e.g., `[retail_nodes]`), mapping them to connection plugins (`ansible_connection=local`), SSH users, and variables defined in `group_vars/retail_nodes.yml`.

#### Q23: What is Ansible Check Mode (`--check`), and what challenge does it present with systemd?
**Answer:** Check mode executes playbooks in dry-run mode without mutating system state. However, tasks querying newly defined systemd services can fail if the unit file was not created yet. To prevent dry-run failures, tasks use conditional guards: `when: not ansible_check_mode`.

---

### 6. Deployment Architecture, Rollback & Nginx

#### Q24: Explain the atomic release directory structure (`/opt/retail-inventory`).
**Answer:**
- `/opt/retail-inventory/releases/<id>`: immutable folders housing each extracted release.
- `/opt/retail-inventory/shared/data`: persistent directory holding the shared SQLite database.
- `/opt/retail-inventory/current`: active symlink pointed atomically to the running release folder.
- `/opt/retail-inventory/stable`: pointer to the last verified healthy release.
- `/opt/retail-inventory/previous`: pointer to the prior release for instant fallback.

#### Q25: How does automatic rollback operate if a deployment fails health checks?
**Answer:** The Ansible deployment role uses a `block / rescue` structure. If health checks (`/health`) fail following a release switch, Ansible enters the `rescue` block: it redirects the `current` symlink back to the `stable` release, restarts `retail-inventory.service`, and asserts health, ensuring zero downtime while failing the CI pipeline build.

#### Q26: Why is Nginx deployed as a reverse proxy in front of Node.js?
**Answer:** Nginx provides high-performance HTTP request handling, security shielding (preventing direct internet exposure of the application server), centralized SSL/TLS termination, request buffering, static asset caching, and reverse proxy routing without running Node.js as root.

#### Q27: Why was Node.js/npm used for the application while Maven was used for testing?
**Answer:** Node.js/Express is an asynchronous, event-driven stack ideal for lightweight web services with server-rendered EJS templates. Maven was utilized specifically to orchestrate the Java Selenium WebDriver testing framework, leveraging Java's robust multithreading, type safety, and JUnit test reporting.

---

### 7. Process Management & Troubleshooting

#### Q28: Why was `JENKINS_NODE_COOKIE=dontKillMe` required in Windows batch steps?
**Answer:** Jenkins includes a built-in `ProcessTreeKiller` that scans for and terminates background processes spawned during a build step upon step exit. Setting `JENKINS_NODE_COOKIE=dontKillMe` prevents Jenkins from terminating the ephemeral background application process required by Selenium tests.

#### Q29: How does `scripts/deploy-container.ps1` resolve host port conflicts on port 3001?
**Answer:** It inspects active listeners via `Get-NetTCPConnection -LocalPort 3001`. If occupied by a leftover repository Node process (`node.exe` running `src/server.js`), it forcibly terminates the process (`Stop-Process -Force`) and waits for the socket to clear before executing `docker run`. If occupied by an unrelated foreign process, it halts safely with an error.

#### Q30: What are the primary security limitations of the current demonstration environment?
**Answer:** The system runs on a single host without network perimeter firewalls, uses plain HTTP without TLS certificates, runs an unauthenticated local Docker registry, stores plain-text database credentials, and lacks user authentication/RBAC within the application itself.
