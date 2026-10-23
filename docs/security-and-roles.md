# Security and Role-Based Access Control (RBAC) Specification

## 1. Overview
The Retail Inventory Alert Dashboard implements application authentication and role-based access control (RBAC) across both web interface views and JSON REST API endpoints. Access is restricted using signed session cookies, cryptographic password hashing, synchronized CSRF tokens, and IP-based login rate limiting.

---

## 2. Role and Permissions Matrix

The application defines three built-in roles: `manager`, `staff`, and `purchasing`.

| Resource / Action | Method | Route / Endpoint | Manager | Staff | Purchasing | Unauthenticated |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: |
| **Health Check** | GET | `/health` | Allowed | Allowed | Allowed | Allowed (Public) |
| **Login Page** | GET | `/login` | Allowed | Allowed | Allowed | Allowed (Public) |
| **Login Submit** | POST | `/login` | Allowed | Allowed | Allowed | Allowed (Public) |
| **API Login** | POST | `/api/login` | Allowed | Allowed | Allowed | Allowed (Public) |
| **Static Assets** | GET | `/public/*` | Allowed | Allowed | Allowed | Allowed (Public) |
| **Logout** | POST | `/logout` | Allowed | Allowed | Allowed | 302 to `/login` |
| **User Profile / CSRF** | GET | `/api/me` | Allowed | Allowed | Allowed | 401 Unauthorized |
| **View Catalog** | GET | `/items`, `/` | Allowed | Allowed | Allowed | 302 to `/login` |
| **View Inventory JSON** | GET | `/api/items` | Allowed | Allowed | Allowed | 401 Unauthorized |
| **New Item Page** | GET | `/items/new` | Allowed | Allowed | 403 Forbidden | 302 to `/login` |
| **Create Item** | POST | `/items` | Allowed | Allowed | 403 Forbidden | 302 / 401 |
| **Edit Item Page** | GET | `/items/:id/edit` | Allowed | Allowed | 403 Forbidden | 302 to `/login` |
| **Update Item** | POST | `/items/:id` | Allowed | Allowed | 403 Forbidden | 302 / 401 |
| **Delete Item** | POST | `/items/:id/delete` | Allowed | 403 Forbidden | 403 Forbidden | 302 / 401 |
| **View Transactions** | GET | `/transactions` | Allowed | Allowed | Allowed | 302 to `/login` |
| **New Transaction Page**| GET | `/transactions/new` | Allowed | Allowed | 403 Forbidden | 302 to `/login` |
| **Record Transaction** | POST | `/transactions` | Allowed | Allowed | 403 Forbidden | 302 / 401 |
| **View Low Stock Alerts**| GET | `/alerts` | Allowed | Allowed | Allowed | 302 to `/login` |
| **View Alerts JSON** | GET | `/api/alerts` | Allowed | Allowed | Allowed | 401 Unauthorized |
| **Update Order Status** | POST | `/alerts/:id/order` | Allowed | Allowed | Allowed | 302 / 401 |

### Landing Page Routing
Upon successful authentication, users are redirected based on their role:
- **`manager`**: Redirected to `/items` (or requested `next` parameter if valid).
- **`staff`**: Redirected to `/items` (or requested `next` parameter if valid).
- **`purchasing`**: Redirected to `/alerts` (prioritized procurement workflow).

---

## 3. Session and Cookie Architecture
- **Session Library**: `cookie-session` (lightweight, stateless server-side signed cookie).
- **Cookie Name**: `session` (with signature cookie `session.sig`).
- **Signing**: Uses HMAC-SHA256 keyed by `SESSION_SECRET` (minimum 32 characters in production; startup terminates if missing in production).
- **Cookie Flags**:
  - `httpOnly: true` (prevents JavaScript access via `document.cookie`).
  - `sameSite: 'lax'` (protects against cross-site request forgery while permitting top-level navigation).
  - `secure: false` (supports local HTTP demo instances; set to `true` when TLS is terminated).
  - `maxAge: 28800000` (8 hours lifetime).
- **Reverse Proxy Trust**: `app.set('trust proxy', 1)` is enabled to accurately inspect client IPs and protocol headers through Nginx reverse proxies.

---

## 4. Password Security and Storage
- **Algorithm**: `bcryptjs` (pure JavaScript implementation, avoiding native compilation hurdles across Windows and Linux nodes).
- **Cost Factor**: Salt rounds set to **12**.
- **Database Schema**: Stored in table `users` with columns:
  - `id` (INTEGER PRIMARY KEY AUTOINCREMENT)
  - `username` (TEXT NOT NULL UNIQUE)
  - `password_hash` (TEXT NOT NULL)
  - `role` (TEXT NOT NULL CHECK in `manager`, `staff`, `purchasing`)
  - `created_at` (DATETIME DEFAULT CURRENT_TIMESTAMP)
- **Automatic Migration**: Database initialization executes `CREATE TABLE IF NOT EXISTS users ...` ensuring compatibility with pre-existing databases without dropping data.
- **Initial Seed**: If the `users` table is empty and `SEED_*_PASSWORD` environment variables are present and at least 10 characters long, accounts for `manager`, `staff`, and `purchasing` are automatically created on startup.

---

## 5. CSRF (Cross-Site Request Forgery) Protection
- **Token Generation**: Cryptographically secure random tokens generated via `crypto.randomBytes(24).toString('hex')` stored in the authenticated user's session.
- **Validation**: Every state-modifying HTTP request (`POST`, `PUT`, `DELETE`, `PATCH`) must supply a valid token matching `req.session.csrfToken`.
- **Submission Methods**:
  - HTML Form Field: `<input type="hidden" name="_csrf" value="<%= csrfToken %>">`
  - HTTP Request Header: `x-csrf-token: <token>`
- **Exemptions**: Public unauthenticated endpoint `POST /api/login` is exempt from CSRF checking since no active session exists prior to login.
- **Failure Behavior**: Missing or mismatched token responds with HTTP 403 Forbidden.

---

## 6. Rate Limiting and Brute Force Protection
- **Middleware**: `express-rate-limit`.
- **Policy**: Maximum of **5 failed login attempts per minute per client IP address**.
- **Response**: Responds with HTTP 429 (`Too many login attempts. Please try again in a minute.`).
- **Timing and Enumeration Prevention**: Login checks use uniform generic error messages (`Invalid username or password`) regardless of whether the username exists or the password is incorrect.

---

## 7. Security Headers
The application enforces standard protective HTTP response headers:
- `X-Content-Type-Options: nosniff` (mitigates MIME-sniffing exploits).
- `X-Frame-Options: DENY` (prevents clickjacking by forbidding embedding in iframes).
- `Referrer-Policy: same-origin` (restricts referrer leakage to third-party domains).

---

## 8. Secret Generation and Rotation

### Secret Initialization
Secrets are generated using the PowerShell utility `scripts/init-secrets.ps1`:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\init-secrets.ps1
```
This utility:
1. Generates a 48-character random hexadecimal `SESSION_SECRET`.
2. Generates secure 16-character alphanumeric passwords for `manager`, `staff`, and `purchasing`.
3. Writes container environment variables to `C:\deploy\retail-inventory\secrets.env`.
4. Writes Ansible deployment variables to `C:\deploy\retail-inventory\secrets.yml`.
5. Restricts file permissions using `icacls` to only the Administrator and current user.

### Secret Rotation Procedure
To rotate deployment secrets and user passwords:
1. Run secret regeneration with the `-Force` switch:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\init-secrets.ps1 -Force
   ```
2. Redeploy the Docker container to pick up updated `secrets.env`:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\deploy-container.ps1 -Environment dev -HostPort 3001 -ImageRef localhost:5000/retail-inventory-alert:2.1.0-0 -BuildNumber 1
   ```
3. Re-run Ansible provision and deploy to update `/etc/retail-inventory/retail-inventory.env` on Linux nodes:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\node-ops.ps1 -Action provision
   powershell -ExecutionPolicy Bypass -File scripts\node-ops.ps1 -Action deploy -ReleaseId <new-release-id>
   ```

---

## 9. Demo Login Instructions

For evaluation and demonstration purposes:
1. Open the application landing page at `http://localhost:3001/` (Docker) or `http://localhost:8300/` (Ansible/Linux).
2. The user is redirected to `/login?next=...`.
3. Retrieve current demo credentials from `C:\deploy\retail-inventory\secrets.env` (or run automated Selenium tests which use standard test credentials in CI mode).
4. Log in as:
   - **`manager`**: Notice full administrative privileges, "+ Add Item" button, "Edit" and "Delete" buttons on catalog items.
   - **`staff`**: Notice "+ Add Item" and "Edit" buttons are available, but "Delete" buttons are hidden. Direct access to delete returns 403.
   - **`purchasing`**: Automatically lands on `/alerts`. Catalog view displays items without management action buttons. Item creation/edit and transaction entry return 403. "Order Placed" / "Received" status buttons are fully functional.

---

## 10. Known Limitations & Future Enhancements
- **Rate Limit Storage**: Uses Express in-memory rate limiting. Multi-instance horizontal scaling would require a Redis or distributed cache backing.
- **Session Store**: Session payloads are stored within signed client-side cookies. For larger session payloads, an external database session store (e.g. SQLite session store or Redis) is recommended.
- **User Management UI**: Users and roles are seeded at initialization or provisioned via database migrations; an administrative user management view is scheduled for future minor releases.
