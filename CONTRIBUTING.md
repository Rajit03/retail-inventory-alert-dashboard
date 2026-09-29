# Contributing Guidelines

Thank you for contributing to the **Containerized Retail Inventory Alert Dashboard** project. To maintain a clean and reliable codebase, please follow the branching strategy and commit conventions outlined below.

---

## Branching Policy & Workflow

We utilize a Git branching workflow to ensure stability and seamless integration:

- **`main`**: The production branch containing stable, release-ready code. Direct commits to `main` are strictly prohibited.
- **`develop`**: The primary integration branch where ongoing features and fixes are merged and tested before release. Direct commits to `develop` are strictly prohibited.
- **`feature/<short-name>`**: Dedicated branch for new features (e.g., `feature/item-catalogue`, `feature/exception-alerts`). Branches are cut from `develop` and merged back into `develop` via Pull Request.
- **`bugfix/<short-name>`**: Dedicated branch for bug fixes (e.g., `bugfix/fix-stock-calculation`). Branches are cut from `develop` and merged back into `develop` via Pull Request.

### Pull Request (PR) Process

1. Create a feature or bugfix branch from `develop`.
2. Make modular, well-tested commits following our commit conventions.
3. Open a Pull Request targeting the `develop` branch.
4. Ensure all CI checks and automated tests pass before requesting review and merging.
5. Once thoroughly tested on `develop`, releases are merged into `main`.

---

## Commit Message Conventions

All commit messages must adhere to conventional commit standards using standard prefixes:

- **`feat:`** Introduces a new user-facing feature or enhancement.
- **`fix:`** Patches a bug or resolves an issue in existing code.
- **`docs:`** Adds, updates, or corrects documentation (README, guides, templates, comments).
- **`chore:`** Routine maintenance, build configuration, dependency updates, or project setup changes.
- **`test:`** Adds missing tests, refactors existing test suites, or updates test configurations.

### Examples

- `feat: implement search and filter for inventory catalogue`
- `fix: correct stock threshold alert calculation`
- `docs: update deployment instructions in README`
- `chore: update express and better-sqlite3 dependencies`
- `test: add Selenium E2E tests for item creation flow`
