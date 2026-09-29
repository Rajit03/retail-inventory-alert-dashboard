# Backlog Issues to Create on GitHub

Use the list below to create issues manually in the repository issue tracker: [GitHub Issues](https://github.com/Rajit03/retail-inventory-alert-dashboard/issues).

---

## 1. US-01: Item Catalogue
- **Label**: `feature`
- **Title**: `US-01 Item catalogue`
- **Description**:
  ### User Story
  As a Store Manager / Inventory Clerk,
  I want to view and manage an item catalogue with SKU, item name, category, unit price, and reorder thresholds,
  So that all retail merchandise is catalogued consistently with standard metadata.

  ### Acceptance Criteria
  - [ ] View list of all inventory items in the catalogue.
  - [ ] Item fields include SKU, Name, Category, Price, and Reorder Level.
  - [ ] Support adding new catalog items with validation.

---

## 2. US-02: Create/Update Transaction
- **Label**: `feature`
- **Title**: `US-02 Create/update transaction`
- **Description**:
  ### User Story
  As an Inventory Operator,
  I want to record inventory transactions (stock receipts, sales adjustments, returns),
  So that inventory counts update in real-time accurately reflecting warehouse changes.

  ### Acceptance Criteria
  - [ ] Form to record stock in (receipt) and stock out (sales/adjustment).
  - [ ] Automatic adjustment of on-hand item stock quantities.
  - [ ] Transaction log maintaining timestamp, type, item SKU, and quantity changed.

---

## 3. US-03: Stock or Order Status
- **Label**: `feature`
- **Title**: `US-03 Stock or order status`
- **Description**:
  ### User Story
  As a Retail Operations Manager,
  I want to monitor current inventory levels and open order statuses across categories,
  So that I have clear operational visibility over stock availability.

  ### Acceptance Criteria
  - [ ] Dashboard view displaying current stock levels against safety stock thresholds.
  - [ ] Order status tracking (Pending, In-Transit, Received, Completed).
  - [ ] Real-time state indicators for stock health.

---

## 4. US-04: Search and Filter
- **Label**: `feature`
- **Title**: `US-04 Search and filter`
- **Description**:
  ### User Story
  As an Inventory User,
  I want to search and filter catalogue items by SKU, name, category, and stock level status,
  So that I can quickly locate items during daily store operations.

  ### Acceptance Criteria
  - [ ] Text search matching item name or SKU.
  - [ ] Dropdown filter for item categories.
  - [ ] Status filters for Out of Stock, Low Stock, and In Stock items.

---

## 5. US-05: Exception Alerts
- **Label**: `feature`
- **Title**: `US-05 Exception alerts`
- **Description**:
  ### User Story
  As a Store Supervisor,
  I want to receive visual alerts and notifications for low stock, stockouts, and order anomalies,
  So that immediate reorder actions can be taken before business impact occurs.

  ### Acceptance Criteria
  - [ ] Visual alert badges for items below minimum safety threshold.
  - [ ] Dedicated alert banner/section summarizing all active inventory exceptions.
  - [ ] High-priority warnings for zero-stock / depleted items.

---

## 6. US-06: Version Control Workflow
- **Label**: `devops`
- **Title**: `US-06 Version control workflow`
- **Description**:
  ### User Story
  As a DevOps Engineer,
  I want a formalized Git branching workflow (`main`, `develop`, `feature/*`, `bugfix/*`) with PR templates and conventional commits,
  So that all code contributions are tracked, reviewed, and integrated systematically.

  ### Acceptance Criteria
  - [ ] Standard branch protection policies documented.
  - [ ] Issue templates (bug report, feature request) configured.
  - [ ] Conventional commit guidelines enforced across PRs.

---

## 7. US-07: Continuous Integration with Jenkins
- **Label**: `devops`
- **Title**: `US-07 Continuous integration with Jenkins`
- **Description**:
  ### User Story
  As a DevOps Engineer,
  I want an automated Jenkins CI pipeline configured via Jenkinsfile,
  So that commits on `develop` and `main` automatically run linting, tests, and build checks.

  ### Acceptance Criteria
  - [ ] `Jenkinsfile` created with stages for Checkout, Dependency Install, Lint, and Unit Tests.
  - [ ] Automated build triggering on repository updates.
  - [ ] Pipeline status reports for build success or failure.

---

## 8. US-08: Automated Selenium Testing
- **Label**: `devops`
- **Title**: `US-08 Automated Selenium testing`
- **Description**:
  ### User Story
  As a QA / DevOps Engineer,
  I want automated Selenium WebDriver end-to-end test suites,
  So that UI interactions, health checks, and dashboard workflows are verified automatically in the CI pipeline.

  ### Acceptance Criteria
  - [ ] Automated Selenium test suite targeting dashboard and alert features.
  - [ ] Headless execution compatibility in CI environment.
  - [ ] Test report and screenshot capture on test failures.

---

## 9. US-09: Docker Containerized Deployment
- **Label**: `devops`
- **Title**: `US-09 Docker containerized deployment`
- **Description**:
  ### User Story
  As a DevOps Engineer,
  I want container definitions (`Dockerfile`, `docker-compose.yml`) for the application and database,
  So that the application runs consistently across development, staging, and production environments.

  ### Acceptance Criteria
  - [ ] Multi-stage or optimized production `Dockerfile`.
  - [ ] `docker-compose.yml` defining environment variables, port mappings, and persistent volumes.
  - [ ] Successful container build, startup, and health check pass.

---

## 10. US-10: Automated Provisioning with Ansible/Puppet
- **Label**: `devops`
- **Title**: `US-10 Automated provisioning with Ansible/Puppet`
- **Description**:
  ### User Story
  As an Infrastructure Engineer,
  I want configuration management playbooks/manifests (Ansible/Puppet),
  So that server environment setup, Docker installation, and application deployment are fully reproducible.

  ### Acceptance Criteria
  - [ ] Playbook/manifest to provision runtime dependencies and Docker on target host.
  - [ ] Automated deployment role/task to pull, configure, and launch the containerized application.
  - [ ] Idempotent execution verified on fresh target nodes.
