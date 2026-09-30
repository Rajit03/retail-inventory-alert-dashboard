# Containerized Retail Inventory Alert Dashboard

A lightweight, reliable, containerized web application designed to solve inventory visibility and replenishment challenges in retail operations. It provides store managers and warehouse staff with real-time stock tracking, automated low-stock and out-of-stock exception alerts, and seamless transaction management to prevent stockouts and overstocking.

---

## MVP Features

1. **Item Catalogue (US-01)**: Maintain a structured product catalogue with item name, category, unit price, stock quantity, and baseline reorder threshold.
2. **Stock Transactions (US-02)**: Record inventory movements (`IN` to add stock, `OUT` to remove stock with deficit prevention, and `ADJUST` to set baseline stock) within single ACID database transactions.
3. **Stock & Order Status (US-03)**: Dynamic, calculated stock health badges (`IN_STOCK`, `LOW_STOCK`, `OUT_OF_STOCK`) and supplier replenishment tracking (`NONE`, `ORDERED`, `RECEIVED`) with expected delivery dates.
4. **Search & Filter (US-04)**: Real-time SQL-based filtering by partial/case-insensitive name search, category dropdown, and stock health status.
5. **Exception Alerts (US-05)**: Automated exception alerts dashboard highlighting critical items requiring attention (`OUT_OF_STOCK`, `LOW_STOCK`, and `DELAYED_ORDER`).

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

3. **Seed sample data**:
   ```bash
   npm run seed
   ```

4. **Start the application**:
   ```bash
   npm start
   ```

5. **Access the dashboard**:
   Open your browser and navigate to [http://localhost:3000](http://localhost:3000).
   You can verify service health at [http://localhost:3000/health](http://localhost:3000/health).

---

## Environment Variables

The application can be configured using the following environment variables:

| Variable | Description | Default |
| --- | --- | --- |
| `PORT` | Port number on which the HTTP server listens | `3000` |
| `DB_PATH` | File path to the SQLite database file (supports Docker volume mounting) | `data/inventory.db` |

---

## Application Routes & Endpoints

### Web Pages

| Route | Method | Description |
| --- | --- | --- |
| `/` | `GET` | Redirects to `/items` catalogue |
| `/items` | `GET` | Catalogue table with search, category/status filters, stock badges, and order status |
| `/items/new` | `GET` | Form to create a new catalogue item |
| `/items` | `POST` | Process submission for creating a new item |
| `/items/:id/edit` | `GET` | Form to edit item details and supplier order status |
| `/items/:id` | `POST` | Process submission for updating an item |
| `/transactions` | `GET` | Log of all stock transaction movements with item details and timestamps |
| `/transactions/new` | `GET` | Form to record a new stock transaction (`IN`, `OUT`, `ADJUST`) |
| `/transactions` | `POST` | Process submission for recording a new transaction |
| `/alerts` | `GET` | Exception alerts dashboard displaying low stock, out of stock, and delayed orders |
| `/health` | `GET` | Application health check endpoint returning `{ status: "UP" }` |

### REST API Endpoints

| Endpoint | Method | Description | Status Codes |
| --- | --- | --- | --- |
| `/api/items` | `GET` | Retrieve list of items (supports `search`, `category`, and `status` query params) | `200`, `500` |
| `/api/items/:id` | `GET` | Retrieve a single item by ID including calculated `stock_status` | `200`, `404`, `500` |
| `/api/items` | `POST` | Create a new item (validates fields and duplicate names) | `201`, `400`, `409`, `500` |
| `/api/items/:id` | `PUT` | Update item details and inventory thresholds | `200`, `400`, `404`, `409`, `500` |
| `/api/items/:id/order-status` | `PATCH` | Update replenishment order status and expected date | `200`, `400`, `404`, `500` |
| `/api/transactions` | `GET` | List stock transactions (optionally filter by `itemId` query param) | `200`, `500` |
| `/api/transactions` | `POST` | Record a stock transaction and atomically update item stock quantity | `201`, `400`, `404`, `500` |
| `/api/alerts` | `GET` | Retrieve all active computed exception alerts | `200`, `500` |

---

## Project Structure

```text
retail-inventory-alert-dashboard/
├── .github/
│   └── ISSUE_TEMPLATE/       # GitHub issue templates for bug reports & feature requests
├── data/                     # SQLite database files (runtime, git-ignored)
├── docs/                     # Project documentation, backlog, and architecture records
├── public/                   # Static assets
│   └── css/
│       └── style.css         # Modern, responsive stylesheet
├── src/
│   ├── db/                   # Database schemas, connections, and seeders
│   │   ├── database.js       # SQLite connection manager with DB_PATH support
│   │   ├── schema.sql        # Database schema definitions (items, transactions)
│   │   └── seed.js           # Sample inventory seed script
│   ├── routes/               # Express route handlers
│   │   ├── alerts.js         # Exception alerts routes & computation
│   │   ├── catalogue.js      # Web catalogue pages and form handlers
│   │   ├── items.js          # REST API for items and order status
│   │   └── transactions.js   # Stock transactions API and web views
│   ├── utils/                # Utility helpers
│   │   └── stockStatus.js    # Calculated stock status helper
│   ├── validators/           # Request input validators
│   │   ├── itemValidator.js  # Item input and length constraint validator
│   │   └── transactionValidator.js # Transaction type and quantity validator
│   ├── views/                # EJS server-rendered templates
│   │   ├── alerts/           # Alerts view templates
│   │   ├── items/            # Catalogue view templates (index, new, edit)
│   │   ├── partials/         # Reusable UI partials (header, footer)
│   │   └── transactions/     # Transaction view templates (index, new)
│   └── server.js             # Express application entry point
├── tests/                    # Automated test suites
├── .gitignore                # Git ignore rules
├── CONTRIBUTING.md           # Contribution guidelines, branching model, and commit conventions
├── package.json              # Project metadata, scripts, and dependencies
└── README.md                 # Project overview and setup instructions
```

---

## Branching and Commits

We follow a structured branching model (`main`, `develop`, `feature/*`, `bugfix/*`, `docs/*`, `release/*`) and conventional commit standards. For complete branching rules, pull request workflows, and commit message conventions, please refer to [CONTRIBUTING.md](CONTRIBUTING.md).
