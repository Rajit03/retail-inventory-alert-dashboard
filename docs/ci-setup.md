# Continuous Integration (CI) Setup Guide

This guide details the automated build and CI pipeline configuration for the **Containerized Retail Inventory Alert Dashboard** using Jenkins Freestyle jobs.

---

## 1. Runtime Environment

- **Node.js**: v18.0.0+ (Tested with Node.js v22.x LTS)
- **npm**: v9.0.0+ (Included with Node.js)
- **Host OS**: Windows (Powershell / Windows Batch compatible)

---

## 2. NPM Lifecycle Scripts

The project defines standardized npm scripts in `package.json` for CI automation:

| Script | Command | Purpose |
| --- | --- | --- |
| `npm run build` | `node scripts/build.js` | Validates required project files, runs `node --check` syntax validation on all `src/` files, and generates `build-info.json`. |
| `npm test` | `node --test tests/unit/` | Executes automated unit tests (stock status, item validator) and API smoke tests using Node's built-in test runner. |
| `npm run package` | `npm pack` | Packages the application source files, views, assets, and `build-info.json` into a compressed `.tgz` distribution tarball. |
| `npm run ci` | `npm ci && npm run build && npm test && npm pack` | Complete end-to-end clean install, build, test, and package pipeline. |

---

## 3. Build Artifacts

The build pipeline outputs two primary artifacts:

1. **Distribution Tarball (`*.tgz`)**: `retail-inventory-alert-dashboard-<version>.tgz` containing production code (`src/`, `public/`, `build-info.json`, `package.json`, `package-lock.json`, `README.md`).
2. **Build Metadata (`build-info.json`)**: Contains build number, git commit hash, package version, and ISO timestamp.

---

## 4. Jenkins Freestyle Job Configuration

To configure an automated Jenkins Freestyle CI job:

### General & Source Code Management (SCM)
- **Project Type**: Freestyle project
- **Source Code Management**: Git
- **Repository URL**: `https://github.com/Rajit03/retail-inventory-alert-dashboard.git`
- **Branch Specifier**: `*/develop`

### Build Triggers
- **Poll SCM**: Enabled
- **Schedule**: `H/2 * * * *` (Polls every 2 minutes for changes on `develop`)

### Build Steps (Windows Environment)
Add a **Execute Windows batch command** build step:
```bat
call npm ci
call npm run build
call npm test
call npm run package
```
*(Note: `call` ensures that batch execution continues after each npm command)*

### Post-build Actions
- **Archive the artifacts**:
  - Files to archive: `*.tgz, build-info.json`
  - Fingerprint all archived artifacts: Enabled
