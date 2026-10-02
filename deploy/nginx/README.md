# Nginx Reverse Proxy Setup (Windows)

This document describes how to install Nginx on Windows and configure it as a reverse proxy for the Retail Inventory Alert Dashboard.

---

## 1. Environment and Port Architecture

| Environment | Application Port (Internal) | Nginx Reverse Proxy Port (Public) | Public Entrypoint URL |
| :--- | :--- | :--- | :--- |
| **Development (`dev`)** | `3001` | `8081` | `http://localhost:8081/items` |
| **Staging (`staging`)** | `3002` | `8082` | `http://localhost:8082/items` |

---

## 2. Installation Steps

1. **Download Nginx for Windows:**
   - Download the latest stable Windows zip archive from [https://nginx.org/en/download.html](https://nginx.org/en/download.html) (e.g. `nginx-1.26.x.zip`).

2. **Extract to `C:\nginx`:**
   - Extract the contents of the archive into `C:\nginx` so that `C:\nginx\nginx.exe` and `C:\nginx\conf\nginx.conf` exist.

---

## 3. Configuration

1. Open `C:\nginx\conf\nginx.conf` in an editor.
2. Inside the main `http { ... }` block, add an `include` directive pointing to `retail-inventory.conf` using **forward slashes**:

   ```nginx
   http {
       # ... existing configuration settings ...

       # Include Retail Inventory Alert Dashboard proxy configurations
       include C:/Projects/retail-inventory-alert-dashboard/deploy/nginx/retail-inventory.conf;
   }
   ```

   *(Alternatively, copy `retail-inventory.conf` directly into `C:\nginx\conf\` and use `include retail-inventory.conf;`)*

---

## 4. Operation & Management Commands

Open PowerShell or Command Prompt and run the following commands:

### Test Configuration Syntax
```powershell
cd C:\nginx
.\nginx.exe -t
```
*Expected output: `nginx: the configuration file C:\nginx\conf\nginx.conf syntax is ok` and `test is successful`.*

### Start Nginx
```powershell
cd C:\nginx
start nginx
```
*Note: `start nginx` launches Nginx in the background.*

### Reload Configuration (Zero-Downtime)
After modifying `retail-inventory.conf` or `nginx.conf`:
```powershell
cd C:\nginx
.\nginx.exe -s reload
```

### Stop Nginx
- **Graceful shutdown** (waits for active connections to finish):
  ```powershell
  cd C:\nginx
  .\nginx.exe -s quit
  ```
- **Fast shutdown** (immediate):
  ```powershell
  cd C:\nginx
  .\nginx.exe -s stop
  ```
- **Force kill if hanging**:
  ```powershell
  taskkill /F /IM nginx.exe
  ```

---

## 5. Verification

Once both the application (via `scripts/deploy.ps1`) and Nginx are running:

- Check Dev Health: `http://localhost:8081/health`
- Access Dev Dashboard: `http://localhost:8081/items`
- Check Staging Health: `http://localhost:8082/health`
- Access Staging Dashboard: `http://localhost:8082/items`
