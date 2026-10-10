# Selenium Automated UI Test Plan

## 1. Scope & Objective

This test plan defines the automated End-to-End (E2E) UI testing strategy for the **Retail Inventory Alert Dashboard**. The objective is to validate critical user journeys across catalog management, input validation, stock transactions, search/filter functionality, and exception alerting through browser automation.

The test suite is built in `tests/selenium` as a modular Maven project, capable of executing locally against development test servers as well as in automated CI/CD pipeline stages (such as Jenkins).

---

## 2. Tools & Versions

| Tool / Library | Version | Purpose |
| :--- | :--- | :--- |
| **Java** | `17+` (LTS) | Language runtime |
| **Selenium Java** | `4.28.1` | Browser automation framework |
| **Selenium Manager** | Built-in (Selenium 4.x) | Automated Chrome binary & driver resolution |
| **JUnit Jupiter (JUnit 5)** | `5.11.4` | Test execution, assertions, lifecycle management |
| **Maven Surefire Plugin** | `3.5.2` | Test execution & system property propagation |
| **Maven Surefire Report Plugin** | `3.5.2` | HTML test report generation |
| **Google Chrome (Headless)** | Latest Stable | Target browser execution environment |

---

## 3. Environment & Execution

The test suite connects to the application via configurable system properties:
- `base.url` (Default: `http://localhost:3100`): Base URL of the target web application.
- `headless` (Default: `true`): Runs Chrome in headless mode (`--headless=new`). Set to `false` for visual debugging.

### Commands

```powershell
# Run the complete test suite (headless by default)
mvn -f tests/selenium/pom.xml test

# Run against a specific URL (e.g. deployed Dev environment or custom port)
mvn -f tests/selenium/pom.xml test -Dbase.url=http://localhost:8095

# Run in headed mode (opens visible browser window)
mvn -f tests/selenium/pom.xml test -Dheadless=false

# Generate HTML Surefire Report
mvn -f tests/selenium/pom.xml surefire-report:report
```

---

## 4. Critical User Journeys (Test Cases)

| ID | Journey Name | Linked Story | Preconditions | Steps | Test Data | Expected Result |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **J1** | **Add New Item** | *US-01: Item Catalog Management* | App running; catalog reachable | 1. Open `/items/new`<br>2. Fill unique item form<br>3. Click "Save Item" | Name: `SEL-<ts>-Item`<br>Category: `Selenium`<br>Price: `$49.99`<br>Qty: `25`, Thresh: `10` | Browser redirects to `/items`; newly created item row exists in table with matching category and quantity. |
| **J2** | **Invalid Item Validation** | *US-02: Input Validation & Duplicate Protection* | App running | 1. Open `/items/new`, leave Name empty, submit.<br>2. Create item via API.<br>3. Open `/items/new`, enter duplicate name, submit. | Empty name;<br>Duplicate Name: `SEL-<ts>-Dup` | Form stays on `/items/new` with `validity.valueMissing = true`. Duplicate submission displays visible error alert. |
| **J3** | **Stock Transactions** | *US-03: Stock Adjustments & Overdraft Prevention* | Item created via API with initial quantity = 20 | 1. Open `/transactions/new`<br>2. Record `OUT` of 5<br>3. Verify catalog stock = 15 & check history<br>4. Record `OUT` of 100 | Item: `SEL-<ts>-TxItem`<br>Valid OUT: `5`<br>Invalid OUT: `100` | Stock decreases to 15; transaction appears on `/transactions`. Overdraft OUT of 100 fails with error alert and stock remains 15. |
| **J4** | **Search & Filter** | *US-04: Catalog Search & Status Filtering* | 3 items created via API (In Stock, Low Stock, Out of Stock) with unique prefix | 1. Search by unique prefix<br>2. Filter by status `LOW_STOCK`<br>3. Search non-existing item name | Prefix: `SF-<ts>`<br>InStock (qty 20, th 5)<br>LowStock (qty 3, th 5)<br>OutOfStock (qty 0, th 5) | Prefix search returns all 3 items; Low Stock filter displays only the low-stock item; non-existing search displays "No items found.". |
| **J5** | **Exception Alerts** | *US-05: Low-Stock Exception Detection & Recovery* | Item created via API with quantity = 3 and threshold = 10 (Low Stock) | 1. Open `/alerts`<br>2. Verify item has "LOW STOCK" alert<br>3. Open `/transactions/new`<br>4. Record `IN` transaction of 15<br>5. Open `/alerts` | Item: `SEL-<ts>-AlertItem`<br>Restock: `IN` of `15` | Low-stock alert appears on `/alerts` initially. After restocking quantity above threshold (18 > 10), the alert is automatically cleared. |

---

## 5. Failure Screenshot Mechanism

Automatic failure diagnostics are implemented using JUnit 5's `TestExecutionExceptionHandler`:
- **Class**: `com.retail.base.ScreenshotOnFailureExtension`
- **Trigger**: Intercepts any assertion error or unhandled exception during test execution *before* `@AfterEach` teardown closes the WebDriver instance.
- **Output Destination**: `tests/selenium/target/screenshots/<ClassName>_<methodName>_<yyyyMMdd-HHmmss>.png`
- **Console Log**: Prints the absolute screenshot file path to `System.out` for immediate developer or CI inspection.

---

## 6. Test Reporting

1. **Surefire XML Output**:
   XML test results for CI ingestion are stored in:
   ```text
   tests/selenium/target/surefire-reports/TEST-<TestClassName>.xml
   ```
2. **Surefire HTML Report**:
   A comprehensive HTML report containing test status, execution time, and failure stack traces is generated via:
   ```powershell
   mvn -f tests/selenium/pom.xml surefire-report:report
   ```
   Report location:
   ```text
   tests/selenium/target/site/surefire-report.html
   ```
