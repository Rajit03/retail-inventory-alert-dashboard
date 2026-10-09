# Task 14 Validation & Demonstration Summary

This document summarizes the automated clean node provisioning, release deployments, idempotency verification, failure recovery with automated rollback, manual rollback, and health checking executed on the **Ubuntu-Retail** WSL target node.

---

## 1. Execution Log & Verification Matrix

| Step | Action & Command | Release ID | Play Recap (ok/chg/fail/res) | Exit Code | Key Evidence Line | Log File |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **01** | **Teardown & Clean State Check**<br>`node-ops.ps1 -Action teardown` | — | `ok=21 changed=12 failed=0 res=0` | `0` | `nginx=not_installed node=not_installed retailapp=removed` | [`01-teardown.log`](01-teardown.log)<br>[`01-before-state.log`](01-before-state.log) |
| **02** | **Initial Node Provisioning**<br>`node-ops.ps1 -Action provision` | — | `ok=26 changed=13 failed=0 res=0` | `0` | `user=retailapp ports app=3300 nginx=8300 nginx_health=200` | [`02-provision.log`](02-provision.log) |
| **03** | **Provisioning Idempotency Verification**<br>`node-ops.ps1 -Action provision` | — | `ok=24 changed=0 failed=0 res=0` | `0` | `PLAY RECAP: ok=24 changed=0 failed=0` (0 changes on rerun) | [`03-provision-rerun.log`](03-provision-rerun.log) |
| **04** | **Initial Application Deployment (r1)**<br>`node-ops.ps1 -Action deploy -ReleaseId r1` | `r1` | `ok=29 changed=7 failed=0 res=0` | `0` | `Target Release: r1 \| Stable: r1 \| Current: r1` | [`04-deploy-r1.log`](04-deploy-r1.log) |
| **05** | **Post-Deploy Health Check (r1)**<br>`node-ops.ps1 -Action healthcheck` | `r1` | `ok=16 changed=0 failed=0 res=0` | `0` | `GET :3300/health: PASS \| GET :8300/health: PASS \| OVERALL: PASS` | [`05-healthcheck-r1.log`](05-healthcheck-r1.log) |
| **06** | **Deploy Idempotency Verification (r1)**<br>`node-ops.ps1 -Action deploy -ReleaseId r1` | `r1` | `ok=26 changed=0 failed=0 res=0` | `0` | `PLAY RECAP: ok=26 changed=0 failed=0` (0 changes on rerun) | [`06-deploy-r1-rerun.log`](06-deploy-r1-rerun.log) |
| **07** | **Second Release Deployment (r2)**<br>`node-ops.ps1 -Action deploy -ReleaseId r2` | `r2` | `ok=29 changed=4 failed=0 res=0` | `0` | `Target Release: r2 \| Previous: r1 \| Stable: r2 \| Current: r2` | [`07-deploy-r2.log`](07-deploy-r2.log) |
| **08** | **Post-Deploy Health Check (r2)**<br>`node-ops.ps1 -Action healthcheck` | `r2` | `ok=16 changed=0 failed=0 res=0` | `0` | `Active Release Symlinks: previous=r1 \| stable=r2 \| current=r2` | [`08-healthcheck-r2.log`](08-healthcheck-r2.log) |
| **09** | **Fault Injection & Automated Rollback**<br>`node-ops.ps1 -Action deploy -ReleaseId r3-bad` | `r3-bad` | `ok=25 changed=8 failed=1 res=1` | `1` | `AUTOMATIC ROLLBACK SUCCESS: Successfully rolled back current to /opt/retail-inventory/releases/r2` | [`09-deploy-r3-bad.log`](09-deploy-r3-bad.log) |
| **10** | **Health Check After Auto-Rollback**<br>`node-ops.ps1 -Action healthcheck` | `r2` | `ok=16 changed=0 failed=0 res=0` | `0` | `Active Release Symlinks: previous=r1 \| stable=r2 \| current=r2` | [`10-healthcheck-after-rollback.log`](10-healthcheck-after-rollback.log) |
| **11** | **Manual Rollback to Previous Release**<br>`node-ops.ps1 -Action rollback` | `r1` | `ok=15 changed=3 failed=0 res=0` | `0` | `MANUAL ROLLBACK COMPLETED: Rolled back to r1` | [`11-manual-rollback.log`](11-manual-rollback.log) |
| **12** | **Health Check After Manual Rollback**<br>`node-ops.ps1 -Action healthcheck` | `r1` | `ok=16 changed=0 failed=0 res=0` | `0` | `Active Release Symlinks: previous=r1 \| stable=r1 \| current=r1` | [`12-healthcheck-after-manual-rollback.log`](12-healthcheck-after-manual-rollback.log) |
| **13** | **Final Target Release Deployment (r2)**<br>`node-ops.ps1 -Action deploy -ReleaseId r2` | `r2` | `ok=28 changed=3 failed=0 res=0` | `0` | `Target Release: r2 \| Previous: r1 \| Stable: r2 \| Current: r2` | [`13-deploy-r2-final.log`](13-deploy-r2-final.log) |
| **14** | **Final System Health Check**<br>`node-ops.ps1 -Action healthcheck` | `r2` | `ok=16 changed=0 failed=0 res=0` | `0` | `OVERALL RESULT: PASS (current=r2, stable=r2, previous=r1)` | [`14-healthcheck-final.log`](14-healthcheck-final.log) |
| **15** | **Windows Cross-Subsystem Verification**<br>`Invoke-WebRequest` to port 8300 | `r2` | — | `0` | `GET :8300/health -> 200, GET :8300/items -> 200 (Dashboard Title OK)` | [`15-windows-access.log`](15-windows-access.log) |

---

## 2. Final Release Layout

```text
/opt/retail-inventory/
├── .npm/
├── current -> /opt/retail-inventory/releases/r2
├── previous -> /opt/retail-inventory/releases/r1
├── releases/
│   ├── r1/
│   ├── r2/
│   └── r3-bad/ (contains .failed flag)
├── shared/
│   └── data/
│       └── inventory.db
└── stable -> /opt/retail-inventory/releases/r2
```

### Filesystem Verification Output

```text
$ ls -la /opt/retail-inventory
drwxr-xr-x 5 retailapp retailapp 4096 Oct  9 07:07 .
drwxr-xr-x 3 root      root      4096 Oct  9 06:41 ..
drwxr-xr-x 4 retailapp retailapp 4096 Oct  9 06:45 .npm
lrwxrwxrwx 1 root      root        33 Oct  9 07:07 current -> /opt/retail-inventory/releases/r2
lrwxrwxrwx 1 root      root        33 Oct  9 06:48 previous -> /opt/retail-inventory/releases/r1
drwxr-xr-x 5 retailapp retailapp 4096 Oct  9 06:51 releases
drwxr-x--- 3 retailapp retailapp 4096 Oct  9 06:41 shared
lrwxrwxrwx 1 root      root        33 Oct  9 07:07 stable -> /opt/retail-inventory/releases/r2

$ ls -la /opt/retail-inventory/releases
drwxr-xr-x 5 retailapp retailapp 4096 Oct  9 06:51 .
drwxr-xr-x 5 retailapp retailapp 4096 Oct  9 07:07 ..
drwxr-xr-x 5 retailapp retailapp 4096 Oct  9 06:45 r1
drwxr-xr-x 5 retailapp retailapp 4096 Oct  9 06:48 r2
drwxr-xr-x 5 retailapp retailapp 4096 Oct  9 06:52 r3-bad
```

---

## 3. Final Health Check Report

```text
========================= HEALTH CHECK REPORT =========================
User 'retailapp'           : PASS
Required Directories      : PASS
Nginx Service (active)    : PASS
App Service (active)      : PASS
Port 3300 (Node.js)         : PASS
Port 8300 (Nginx)           : PASS
GET :3300/health (direct)   : PASS (status=200)
GET :8300/health (proxy)    : PASS (status=200)
GET :8300/api/items         : PASS (status=200)
-----------------------------------------------------------------------
Active Release Symlinks   : previous=r1 | stable=r2 | current=r2
OVERALL RESULT            : PASS
=======================================================================
```
