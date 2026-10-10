# Comprehensive Troubleshooting & Diagnosis Guide

This guide documents real operational issues encountered across the development, CI/CD automation, containerization, and configuration management lifecycle of the **Retail Inventory Alert Dashboard**, along with diagnostic procedures and resolutions.

---

## 1. Problem Diagnosis Matrix

| # | Symptom | Root Cause | Remediation / Fix | How to Verify |
| :- | :--- | :--- | :--- | :--- |
| **1** | Port 8081 responds with "Not Found" or conflicts with third-party software. | Port 8081 was already occupied by a local system process (e.g., McAfee Web Gateway or Windows utility). | Reconfigured Windows Nginx `nginx.conf` to bind reverse proxy listeners to dedicated, unoccupied ports: `8095` (dev) and `8096` (staging). | Run `curl.exe -I http://localhost:8095/health` and verify HTTP 200 response. |
| **2** | Maven Selenium build fails with `UnsupportedClassVersionError` or Java version mismatch. | System `JAVA_HOME` pointed to legacy JDK 11, whereas modern Maven/Selenium testing required Java 21 features. | Configured Jenkins stage toolchain `withEnv(['PATH+MAVEN=...'])` and ensured JDK 21 is in the active PATH. | Run `mvn -version` and verify `Java version: 21.x`. |
| **3** | Jenkins pipeline fails invoking `docker`, `wsl`, or launching headless Chrome with access denied. | Jenkins service was originally running under the restricted `Local System` Windows account, lacking access to user WSL distributions and Docker Desktop sockets. | Reconfigured the `Jenkins` Windows Service in `services.msc` to run under the active developer user account (`Log On -> This Account`). | Execute `whoami` and `wsl -l -v` inside a Jenkins build step; verify user identity and WSL distribution list. |
| **4** | Jenkins Windows batch step abruptly exits after the first `npm` command without completing remaining lines. | In Windows cmd/bat, invoking a `.cmd` or `.bat` executable without `call` permanently transfers execution control away from the calling script. | Prepended all npm and npx invocations with `call` (e.g., `call npm ci`, `call npm test`, `call npm run build`). | Ensure batch scripts execute all sequential commands through completion. |
| **5** | Ephemeral Node.js application process spawned during Selenium testing terminates prematurely when the step ends. | Jenkins ProcessTreeKiller automatically identifies and kills background processes spawned during build execution. | Set `env.JENKINS_NODE_COOKIE = 'dontKillMe'` before spawning the background process, allowing Selenium to interact with `http://localhost:3100`. | Confirm `curl.exe http://localhost:3100/health` answers `{"status":"UP"}` during test execution. |
| **6** | PowerShell command fails with `The token '&&' is not a valid statement separator` or curl options fail. | Windows PowerShell 5.1 does not support bash-style `&&` syntax and aliases `curl` to `Invoke-WebRequest` and `sc` to `Set-Content`. | Use semicolon `;` for command chaining and call binary executables explicitly (`curl.exe`, `sc.exe`). | Run `curl.exe -s http://localhost:5000/v2/` without parameter binding errors. |
| **7** | WSL execution fails with missing virtual disk error or distribution corrupted. | The default `Ubuntu` distribution had a missing or corrupt `ext4.vhdx` image. | Created and registered a dedicated, clean distribution `Ubuntu-Retail` (`wsl --import Ubuntu-Retail ...`) with systemd enabled and passwordless sudo. | Run `wsl -d Ubuntu-Retail -- echo ok` returning `ok`. |
| **8** | Ansible execution ignores `ansible.cfg` in WSL repository mount. | Ansible ignores configuration files in world-writable directories (such as NTFS `/mnt/c` mounts) for security reasons. | Explicitly export `ANSIBLE_CONFIG` pointing to the exact configuration file path in all scripts and playbooks. | Check playbook execution header showing `ansible.cfg` being loaded. |
| **9** | Ansible playbook execution fails in Linux with unexpected syntax errors or carriage return errors (`\r`). | Windows Git checkout defaulted to CRLF line endings for YAML, Jinja2 templates, and shell scripts. | Added `.gitattributes` rule `* text=auto eol=lf` to enforce LF endings on all Ansible and Linux configuration files. | Run `file ansible/roles/nginx/templates/nginx.conf.j2` inside WSL and verify ASCII text without CRLF line terminators. |
| **10** | Ansible `site.yml` fails during `--check` mode on systemd service operations. | Ansible `ansible.builtin.systemd` module attempts state queries that fail in dry-run/check mode when services are newly defined. | Added `when: not ansible_check_mode` guards on systemd enablement and restart tasks. | Run `ansible-playbook site.yml --check` and verify clean execution with zero failures. |
| **11** | Container build fails or crashes due to missing native C++ compilation tools for SQLite bindings. | `better-sqlite3` requires Python, make, and g++ for native compilation, which are absent in minimal alpine runtime images. | Implemented a multi-stage `Dockerfile` with a build stage (`node:22-alpine` with `python3 make g++`) compiling native addons and a slim runtime stage. | Run `docker build -t test-build .` and verify clean container startup and SQLite database operations. |
| **12** | Release deployment fails during `npm ci --production` because `package-lock.json` was excluded. | `npm pack` excluded `package-lock.json` by default, causing `npm ci` to error on the target node. | Updated release deployment tasks in Ansible to check for `package-lock.json` and fallback gracefully to `npm install --omit=dev --no-audit` when needed. | Deploy release package and observe successful `npm install` completing production dependency resolution. |
| **13** | WSL distribution stops and systemd services become unreachable after idle period. | WSL 2 terminates inactive instances to conserve host memory. | Configured `wsl.conf` with `[boot] systemd=true` and automated preflight wake-up checks in CI scripts. | Run `scripts/preflight.ps1` to ensure WSL node is active and services are running. |
| **14** | Merge conflict between parallel feature branches modifying project configuration. | Concurrent feature branch development introduced conflicting dependency or configuration changes into `develop`. | Resolved merge conflicts by rebasing or merging `develop` locally, resolving file diffs, and verifying tests before pushing. | Run `git status` confirming clean working tree and all unit/UI tests passing. |
| **15** | GitHub webhooks fail to trigger local Jenkins instance behind NAT/firewall. | Self-hosted Jenkins runs on `localhost:8080` without a public IP or DNS record. | Configured SCM polling trigger `pollSCM('H/2 * * * *')` in `Jenkinsfile` to poll GitHub every 2 minutes for changes. | Push a commit to `develop` and observe automatic build initiation within 2 minutes. |
| **16** | `http://localhost:3001/health` responds, but `docker ps` shows container has no published port mapping. | A leftover Node.js process from Task 8 process deployment was holding host port `3001` before container startup. | Enhanced `scripts/deploy-container.ps1` to detect processes holding port 3001, automatically stop leftover repository Node processes, and assert `docker port` mapping. | Check `docker port retail-inventory-dev` returning `3000/tcp -> 0.0.0.0:3001`. |
| **17** | Windows Nginx port `8096` returns `502 Bad Gateway`. | Staging environment container (`retail-inventory-staging` on port `3002`) is optional and was not deployed. | Expected behavior. Staging is deployed on-demand by triggering the pipeline with parameter `DEPLOY_ENV=staging`. | When `DEPLOY_ENV=dev`, verify port `8095` (PASS) and treat port `8096` as expected offline. |

---

## 2. If a Jenkins Stage Fails: Triage & Inspection Map

When a build fails, consult the corresponding stage in the table below to locate diagnostic logs and evidence:

```
+-----------------------------------------------------------------------------------------------+
| STAGE                    | PRIMARY DIAGNOSTIC LOCATION    | KEY ARTEFACTS / LOGS              |
+--------------------------+--------------------------------+-----------------------------------+
| 1. Checkout              | Jenkins Console Output         | Git revision & branch logs        |
| 2. Build                 | Jenkins Console Output         | npm ci, npm ls, npm test logs     |
| 3. UI Tests (Selenium)   | Test Result Dashboard          | tests/selenium/target/screenshots |
|                          | surefire-report.html           | tests/selenium/target/ci-app.log  |
| 4. Package               | Jenkins Console Output         | *.tgz, build-info.json            |
| 5. Docker Build          | Jenkins Console Output         | Docker build layer output         |
| 6. Docker Push           | docker-registry-evidence.txt   | Registry catalog & tags API log   |
| 7. Deploy Container      | docker-state.txt               | Container logs, docker port, ps   |
| 8. Provision Node        | logs/ansible-provision-<N>.log | Ansible recap & task failures     |
| 9. Deploy Release        | logs/ansible-deploy-<N>.log    | Deploy task & rollback status     |
| 10. End-to-End Verify    | e2e-verification.txt           | Full endpoint verification table  |
+-----------------------------------------------------------------------------------------------+
```

### Stage-by-Stage Diagnostics:
1. **Build Stage**:
   - Check Console Output for `npm ci` dependency resolution errors or unit test assertion failures.
2. **UI Tests (Selenium)**:
   - Navigate to the **Test Result** link in Jenkins to inspect failed JUnit tests.
   - Review captured error screenshots in `tests/selenium/target/screenshots/` and background application logs in `ci-app-*.log`.
3. **Docker Push Stage**:
   - Inspect `docker-registry-evidence.txt` to verify registry connectivity on `http://localhost:5000/v2/`.
4. **Deploy Container Stage**:
   - Inspect `docker-state.txt` for container runtime exit codes and `docker logs retail-inventory-dev`.
5. **Ansible Provisioning / Deploy Stages**:
   - Download and inspect `logs/ansible-provision-${BUILD_NUMBER}.log` and `logs/ansible-deploy-${BUILD_NUMBER}.log`.
   - Check if an automatic rollback occurred (`PLAY RECAP: failed=1 rescued=1`).
6. **End-to-End Verification Stage**:
   - Review `e2e-verification.txt` to identify which specific endpoint (Docker `:3001`, WSL `:8300`, or Nginx `:8095`) failed health assertions.
