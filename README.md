# Containerized Retail Inventory Alert Dashboard

A lightweight, reliable, containerized web application designed to solve inventory visibility and replenishment challenges in retail operations. It provides store managers and warehouse staff with real-time stock tracking, automated low-stock and out-of-stock exception alerts, and seamless transaction management to prevent stockouts and overstocking.

---

## MVP Features

1. **Item Catalogue**: Maintain a structured product catalogue with SKU, item name, category, unit price, and baseline stock thresholds.
- Stock transactions and stock/order status
- Search, filter and exception alerts
2. **Create / Update Transaction**: Record stock receipts, sales deductions, and inventory adjustments with instantaneous quantity updates.
3. **Stock & Order Status**: Real-time visibility into inventory levels, current order statuses, and reorder triggers.
4. **Search & Filter**: Fast querying and filtering of catalogue items by SKU, name, category, and stock availability status.
5. **Exception Alerts**: Automatic visual alerts and notifications for low-stock thresholds, critical depletion, and order discrepancies.

---

## Tech Stack

- **Runtime & Backend**: Node.js, Express.js
- **Templating Engine**: EJS
- **Database**: SQLite (`better-sqlite3`)
- **Containerization**: Docker
- **Continuous Integration**: Jenkins
- **Automated Testing**: Selenium WebDriver (E2E)
- **Configuration Management & Provisioning**: Ansible / Puppet

---

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (v18+ recommended)
- [npm](https://www.npmjs.com/)

### Local Installation & Running

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Rajit03/retail-inventory-alert-dashboard.git
   cd retail-inventory-alert-dashboard
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Start the application**:
   ```bash
   npm start
   ```

4. **Access the dashboard**:
   Open your browser and navigate to [http://localhost:3000](http://localhost:3000).
   You can verify service health at [http://localhost:3000/health](http://localhost:3000/health).

### Environment Variables

The application supports configuration via environment variables:

| Variable | Description | Default |
| --- | --- | --- |
| `PORT` | Port number on which the server listens | `3000` |
| `DB_PATH` | File path to the SQLite database file | `data/inventory.db` |

---

## Item Catalogue (US-01)

The Item Catalogue feature provides full management for retail inventory items.

### Web Pages
- `GET /` — Redirects to `/items`
- `GET /items` — Catalogue table listing all items with name, category, price, quantity, reorder threshold, and edit link
- `GET /items/new` — Form to create a new item
- `POST /items` — Submit new item creation
- `GET /items/:id/edit` — Form to edit an existing item
- `POST /items/:id` — Submit item update

### API Endpoints
- `GET /api/items` — Retrieve all items (JSON)
- `GET /api/items/:id` — Retrieve a specific item by ID (JSON, 404 if not found)
- `POST /api/items` — Create an item (JSON, 201 on success, 400 on invalid input, 409 on duplicate name)
- `PUT /api/items/:id` — Update an item (JSON, 200 on success, 400 on invalid input, 404 if not found, 409 on duplicate name)

### Seeding Sample Data
Populate the database with initial sample inventory items:
```bash
npm run seed
```

---

## Project Structure

```text
retail-inventory-alert-dashboard/
├── .github/
│   └── ISSUE_TEMPLATE/       # GitHub issue templates for bug reports & feature requests
├── docs/                     # Project documentation and architectural records
├── public/                   # Static assets (CSS, client JS, images)
├── src/
│   ├── db/                   # SQLite database initialization, schemas, and migrations
│   ├── routes/               # Express route handlers and endpoints
│   ├── views/                # EJS view templates and UI partials
│   └── server.js             # Express application entry point
├── tests/                    # Automated unit, integration, and Selenium E2E test suites
├── .gitignore                # Git ignore rules
├── CONTRIBUTING.md           # Contribution guidelines, branching model, and commit conventions
├── package.json              # Project metadata, scripts, and dependencies
└── README.md                 # Project overview and setup instructions
```

---

## Continuous Integration

The repository includes automated build, syntax verification, testing, and packaging scripts (`npm run build`, `npm test`, `npm run package`, `npm run ci`) designed for CI pipelines. For detailed instructions on the CI lifecycle and Jenkins freestyle job setup, please see the [CI Setup Guide](docs/ci-setup.md).

---

## Pipeline and Deployment

The repository includes a declarative Jenkins pipeline (`Jenkinsfile`) supporting automated Checkout, Build, Selenium UI Quality Gate, Packaging, and Deployment to `dev` (port 3001, Nginx port 8095) and `staging` (port 3002, Nginx port 8096) environments with atomic release junctions, shared database persistence, and automated health checks. The Selenium E2E suite serves as a strict quality gate in the pipeline, automatically halting deployment if any UI test fails.

For complete documentation on pipeline stages, parameters, directory layout, and Nginx reverse proxy configuration, refer to the [Pipeline & Deployment Guide](docs/pipeline-setup.md).

---

## Automated UI Tests

The repository includes a comprehensive Selenium WebDriver test suite in `tests/selenium` built with Java 17 and JUnit 5. It executes 5 critical end-to-end user journeys (item creation, input validation, stock transactions, search/filter, and exception alerts) against configurable environments with automatic screenshot capture on failure and HTML report generation. The suite runs in CI as an automated quality gate before packaging and deployment.

For complete details on test architecture, journeys, execution parameters, and reporting, see the [Selenium Test Plan](docs/selenium-test-plan.md).

---

## Docker Containerization

The application is containerized with a production-ready, multi-stage Debian-based Docker image (`node:22-bookworm-slim`), non-root execution (`USER node`), persistent named volume storage (`ria-data`), and automated health checking.

### Build Image
```bash
docker build -t retail-inventory-alert:1.0.0 -t retail-inventory-alert:latest .
```

### Run Container
```bash
docker run -d --name ria-dev -p 3200:3000 -v ria-data:/app/data retail-inventory-alert:latest
```

### Seed & Access Container
- **Web Dashboard**: [http://localhost:3200/items](http://localhost:3200/items)
- **Health Check**: [http://localhost:3200/health](http://localhost:3200/health)
- **Seed Initial Data**:
  ```bash
  docker exec ria-dev npm run seed
  ```

For full details on image specifications, line-by-line Dockerfile explanations, volume persistence, and container lifecycle commands, see the [Docker Lifecycle Guide](docs/docker-lifecycle.md).

---

## Ansible configuration

Linux node preparation (packages, `retailapp` user, folders, systemd unit, Nginx on port 8300) is managed with Ansible against the local Ubuntu-Retail WSL instance. See the [Configuration Specification](docs/configuration-specification.md). Application release deployment, idempotency demonstration, health check, and rollback come in Task 14.

---

## Branching and Commits

We follow a structured branching model (`main`, `develop`, `feature/*`, `bugfix/*`) and conventional commit standards. For complete branching rules, pull request workflows, and commit message conventions, please refer to [CONTRIBUTING.md](CONTRIBUTING.md).

## CI Verification

Jenkins CI pipeline verified successfully.