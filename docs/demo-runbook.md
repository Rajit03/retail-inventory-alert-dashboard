# Live Demonstration Runbook

This runbook provides a structured, timed, step-by-step procedure for delivering a live ~12-minute technical demonstration of the **Retail Inventory Alert Dashboard** end-to-end CI/CD and Configuration Management pipeline.

---

## 1. Pre-Demo Environment Checklist

Execute these checks **5-10 minutes prior to the demonstration** to ensure all background daemons and targets are operational:

1. **Run Automated Preflight Verification**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\preflight.ps1
   ```
   *Assert that all mandatory checks report `PASS` with zero `FAIL` statuses.*

2. **Prepare Browser Tabs**:
   - **Tab 1**: GitHub Repository: `https://github.com/Rajit03/retail-inventory-alert-dashboard`
   - **Tab 2**: Jenkins Pipeline Stage View: `http://localhost:8080/job/retail-inventory-alert-dashboard/`
   - **Tab 3**: Docker Container Application: `http://localhost:3001/items`
   - **Tab 4**: Ansible WSL Node Application: `http://localhost:8300/items`
   - **Tab 5**: Docker Registry Catalog: `http://localhost:5000/v2/_catalog`

3. **Verify Open Ports & WSL State**:
   ```powershell
   # Confirm Docker Dev container port binding
   docker port retail-inventory-dev
   # Confirm WSL distribution is awake
   wsl -d Ubuntu-Retail -- echo ok
   ```

---

## 2. Timed Live Demonstration Script (~12 Minutes)

| Timeline | Phase | Actions & Demonstration Steps | Expected Result |
| :---: | :--- | :--- | :--- |
| **00:00 - 01:30** | **1. Architecture & Git Model** | - Present `docs/architecture.md` Mermaid diagram.<br/>- Show branches via terminal (`git branch -a`).<br/>- Explain branch hierarchy: `main` (production), `develop` (integration), and feature branches. | Audience understands the unified dual-target delivery pipeline (Docker + Ansible). |
| **01:30 - 03:00** | **2. Code Change & Pull Request** | - Checkout a demo branch: `git checkout -b demo/banner-update`<br/>- Open `src/views/partials/header.ejs` and update navigation brand text or badge label (e.g., adding `v1.0 Live Demo`).<br/>- Commit and push:<br/>  `git commit -am "chore: update navigation header for live demo"`<br/>  `git push -u origin demo/banner-update`<br/>- Open Pull Request into `develop` on GitHub. | Code change is isolated, reviewed, and ready for integration. |
| **03:00 - 04:00** | **3. PR Merge & SCM Polling** | - Merge the Pull Request into `develop` on GitHub.<br/>- Navigate to Jenkins Dashboard (`http://localhost:8080/job/retail-inventory-alert-dashboard/`).<br/>- Explain SCM Polling (`pollSCM 'H/2 * * * *'`): Jenkins polls GitHub every 2 minutes due to local NAT isolation. | Jenkins automatically triggers build within 120 seconds. |
| **04:00 - 07:00** | **4. Live Pipeline Execution** | - Watch the Jenkins Stage View execute sequentially:<br/>  1. **Checkout**: clones Git revision.<br/>  2. **Build**: executes `npm ci`, verifies Express, runs unit tests.<br/>  3. **UI Tests (Selenium)**: spawns ephemeral app on `:3100`, executes headless Chrome test suite.<br/>  4. **Package**: generates `.tgz` tarball and `build-info.json`.<br/>  5. **Docker Build & Push**: multi-stage Docker build, pushes image to `localhost:5000`.<br/>  6. **Deploy Container**: removes old container, checks port 3001, starts container, verifies health.<br/>  7. **Provision Node (Ansible)**: runs `site.yml` inside WSL `Ubuntu-Retail`.<br/>  8. **Deploy Release (Ansible)**: unpacks `.tgz`, creates atomic symlink `/opt/retail-inventory/current`, restarts systemd service.<br/>  9. **End-to-End Verification**: validates `:3001`, `:8300`, and proxy status. | All 10 pipeline stages transition to GREEN (Success). |
| **07:00 - 08:30** | **5. Quality Gate & Selenium Gate** | - In Jenkins, click the latest build number -> **Test Result**.<br/>- Show the JUnit Surefire report displaying 100% passing tests.<br/>- Explain the Selenium architecture: Page Object Model, explicit waits (`ExpectedConditions`), and automatic screenshot capture on assertion failure. | Demonstrates automated regression prevention before deployment. |
| **08:30 - 09:30** | **6. Docker Environment Verification** | - Query Docker registry tags:<br/>  `curl.exe -s http://localhost:5000/v2/retail-inventory-alert/tags/list`<br/>- Inspect running container:<br/>  `docker ps --filter name=retail-inventory-dev`<br/>  `docker port retail-inventory-dev`<br/>- Refresh browser at `http://localhost:3001/items` showing the updated UI change. | Demonstrates automated containerized release with verified port publication. |
| **09:30 - 10:30** | **7. Ansible WSL Node Verification** | - Inspect WSL release directory structure:<br/>  `wsl -d Ubuntu-Retail -- ls -la /opt/retail-inventory`<br/>  `wsl -d Ubuntu-Retail -- ls -la /opt/retail-inventory/releases`<br/>- Highlight symlinks: `current -> releases/b<N>`, `stable -> releases/b<N>`, and `previous`.<br/>- Refresh browser at `http://localhost:8300/items` showing identical updated UI served by Linux Nginx -> systemd service. | Demonstrates atomic configuration management and release deployment on Linux. |
| **10:30 - 12:00** | **8. Rehearsed Rollback Demonstration** | - Explain the automated self-healing rollback design.<br/>- Open PowerShell and execute a rehearsed rollback test:<br/>  `powershell -ExecutionPolicy Bypass -File scripts\node-ops.ps1 -Action rollback -LogFile logs\demo-rollback.log`<br/>- Inspect output showing playbook redirecting `current` symlink back to `previous`/`stable` and restarting `retail-inventory.service`.<br/>- Confirm health: `http://localhost:8300/health` answers `{"status":"UP"}` without human downtime. | Validates resilience and zero-downtime rollback capabilities. |

---

## 3. "If Something Goes Wrong" Triage Table

| Incident / Symptom | Likely Cause | Rapid Triage & Fix |
| :--- | :--- | :--- |
| **Jenkins doesn't trigger build after PR merge** | SCM polling window has not elapsed yet (up to 2 minutes). | Click **"Build with Parameters"** -> **"Build"** manually in Jenkins UI to immediately start the run. |
| **Port 3001 already in use error** | Leftover Node.js process from earlier manual test. | `scripts/deploy-container.ps1` automatically stops leftover Task 8 Node processes. If another process holds the port, run: `Get-NetTCPConnection -LocalPort 3001` and terminate the offending PID. |
| **WSL commands hang or return connection error** | WSL 2 distribution timed out or was suspended by Windows. | Run `wsl -d Ubuntu-Retail -- systemctl status retail-inventory` in PowerShell to wake up the WSL VM. |
| **Selenium UI tests fail on port 3100** | ChromeDriver was blocked or background test app port collided. | Check `tests/selenium/target/ci-app.log` and captured failure screenshots under `tests/selenium/target/screenshots/`. |
| **Docker pull fails during Deploy Container** | Registry container stopped. | Run `docker start registry` and verify with `curl.exe -s http://localhost:5000/v2/`. |
| **Windows Nginx returns 502 or Connection Refused** | Nginx for Windows is not active. | Windows Nginx is marked `WARN only` in verification. Start it via `Start-Process "C:\nginx\nginx.exe" -WorkingDirectory "C:\nginx"` if required. |
