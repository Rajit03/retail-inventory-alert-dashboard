# Containerized Retail Inventory Alert Dashboard

A lightweight, reliable, containerized web application designed to solve inventory visibility and replenishment challenges in retail operations. It provides store managers and warehouse staff with real-time stock tracking, automated low-stock and out-of-stock exception alerts, and seamless transaction management to prevent stockouts and overstocking.

---

## MVP Features

1. **Item Catalogue**: Maintain a structured product catalogue with SKU, item name, category, unit price, and baseline stock thresholds.
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

## Branching and Commits

We follow a structured branching model (`main`, `develop`, `feature/*`, `bugfix/*`) and conventional commit standards. For complete branching rules, pull request workflows, and commit message conventions, please refer to [CONTRIBUTING.md](CONTRIBUTING.md).
