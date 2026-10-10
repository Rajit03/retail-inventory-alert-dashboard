# Docker Containerization & Lifecycle Guide

This guide documents the containerization strategy, Dockerfile architecture, image metadata, lifecycle operations, health monitoring, and data persistence mechanisms for the **Retail Inventory Alert Dashboard**.

---

## 1. Dockerfile Architecture & Line-by-Line Breakdown

The application uses a secure, multi-stage Debian-based build (`node:22-bookworm-slim`) to compile native C++ SQLite bindings (`better-sqlite3`) while keeping the final runtime image minimal, fast, and executed under a non-root user.

| Line(s) | Directive / Code | Explanation & Purpose |
| :--- | :--- | :--- |
| `1` | `# syntax=docker/dockerfile:1` | Declares the BuildKit Dockerfile syntax parser version. |
| `2-3` | `FROM node:22-bookworm-slim AS build` | **Stage 1 (Build)**: Debian-based Node.js 22 slim image for compiling native extensions. |
| `5` | `WORKDIR /app` | Sets the build working directory to `/app`. |
| `7-12` | `RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ && rm -rf /var/lib/apt/lists/*` | Installs C++ compilation toolchain required by `node-gyp` to build `better-sqlite3`. Cleans package cache to reduce disk usage. |
| `14-15` | `COPY package.json package-lock.json ./` <br>`RUN npm ci --omit=dev` | Leverages Docker layer caching: copies package manifests and installs strictly production dependencies before copying application source. |
| `17-18` | `FROM node:22-bookworm-slim AS runtime` | **Stage 2 (Runtime)**: Clean, slim base image without the compiler toolchain for minimal image size and attack surface. |
| `20-25` | `LABEL org.opencontainers.image...` | OCI standard container metadata (title, description, source repository, and version). |
| `27` | `WORKDIR /app` | Sets application directory in runtime container. |
| `29` | `COPY --from=build /app/node_modules ./node_modules` | Copies compiled production dependencies from the build stage. |
| `30-32` | `COPY package.json package-lock.json ./` <br>`COPY src ./src` <br>`COPY public ./public` | Copies application configuration, backend route logic, database schemas, and static UI assets. |
| `34-37` | `ENV NODE_ENV=production PORT=3000 DB_PATH=/app/data/inventory.db` | Sets production environment variables, application port, and database storage location. |
| `39` | `RUN mkdir -p /app/data && chown -R node:node /app` | Creates data directory and grants ownership to the non-root `node` user (UID 1000). |
| `41` | `VOLUME ["/app/data"]` | Declares `/app/data` as a persistent volume mount point for SQLite database storage across container lifecycles. |
| `43` | `USER node` | Enforces least-privilege security by switching from `root` to non-root `node` user. |
| `45` | `EXPOSE 3000` | Documents that the container listens on port 3000. |
| `47-48` | `HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 ...` | Automated health check invoking `http://localhost:3000/health` using Node.js built-in `fetch()`. Returns healthy once status is UP. |
| `50` | `CMD ["node", "src/server.js"]` | Defines default runtime container entrypoint. |

---

## 2. Docker Image Specifications

| Property | Value | Description |
| :--- | :--- | :--- |
| **Image Name** | `retail-inventory-alert` | Repository image name |
| **Tags** | `1.0.0`, `latest` | Semantic version and latest pointer |
| **Base Image** | `node:22-bookworm-slim` | Debian Bookworm Slim with Node.js 22 runtime |
| **Image ID** | `sha256:fec21742ef550f126870a937443443136d43399618fa35a56fc7e9210be51772` | Content-addressable identifier |
| **Compressed Size** | `~105 MB` (`104,509,960 bytes`) | Highly optimized lightweight footprint |
| **Runtime User** | `node` (UID `1000`) | Non-root security user |
| **Exposed Ports** | `3000/tcp` | Default web interface and API port |
| **Layer Architecture** | Multi-stage (Build & Runtime) | Zero build artifacts or compilers in final image |

---

## 3. Container Lifecycle Operations

The following table summarizes the operational container lifecycle stages demonstrated and verified:

| Lifecycle Stage | Command | Action & Purpose | Observed Result in Demonstration |
| :--- | :--- | :--- | :--- |
| **Build & Tag** | `docker build -t retail-inventory-alert:1.0.0 -t retail-inventory-alert:latest .` | Multi-stage build compiling native modules and packaging runtime image | Successfully built and tagged `retail-inventory-alert:1.0.0` and `latest` |
| **Inspect Image** | `docker image inspect retail-inventory-alert:latest` | Verifies image metadata, size, non-root user, and exposed ports | Confirmed user `node`, port `3000/tcp`, size `104.5 MB` |
| **Run Container** | `docker run -d --name ria-dev -p 3200:3000 -v ria-data:/app/data retail-inventory-alert:latest` | Starts detached container with named volume and port mapping | Container starts with ID `e5236189d12c...`, binds to host port 3200 |
| **Health Check** | `docker ps` | Polls container health status | Transitions from `(health: starting)` to `Up (healthy)` in ~6 seconds |
| **Logs Inspection** | `docker logs --tail 5 ria-dev` | Inspects standard output / error streams | Outputs `Server is running on port 3000` |
| **Database Seeding**| `docker exec ria-dev npm run seed` | Seeds SQLite database inside the mounted volume | `7 items inserted, 0 items skipped.` |
| **HTTP Health API** | `Invoke-RestMethod http://localhost:3200/health` | Verifies application health endpoint | Returns `{"status":"UP"}` |
| **Metrics & Stats** | `docker stats --no-stream ria-dev` | Live CPU, memory, and I/O consumption | Consumes `< 20 MiB` RAM and `~1.5%` CPU |
| **Stop Container** | `docker stop ria-dev` | Gracefully sends SIGTERM to container process | Container stops; status becomes `Exited (137)` |
| **Start Container**| `docker start ria-dev` | Resumes stopped container preserving volume state | Container restarts and returns to `(healthy)` |
| **Restart** | `docker restart ria-dev` | Restarts active container | Container reboots seamlessly without downtime errors |
| **Data Persistence**| `docker rm -f ria-dev` ➔ `docker run ...` (new container) | Destroys container and spawns a brand new container on same volume | New container reads database from `ria-data`; "Docker Persistence Test" item persists |
| **Prune & Clean** | `docker rm ria-dev` | Removes container instance | Container removed; `ria-data` volume preserved |

---

## 4. Port Mapping & Networking

| Host Port | Container Port | Protocol | Usage | URL |
| :--- | :--- | :--- | :--- | :--- |
| `3200` | `3000` | `TCP` | Web Application & REST API | `http://localhost:3200/items` |

> [!NOTE]
> Ports `3001` (dev), `3002` (staging), `3100` (CI test runner), `8080` (Jenkins), `8095` (Nginx dev), and `8096` (Nginx staging) remain reserved on the host machine. The Docker container runs on isolated host port `3200`.

---

## 5. Storage & Volume Management (`ria-data`)

The container stores SQLite data at `/app/data/inventory.db`. Because containers are ephemeral by default, state is preserved using a dedicated Docker named volume:

- **Volume Name**: `ria-data`
- **Container Destination**: `/app/data`
- **Volume Driver**: `local` (`/var/lib/docker/volumes/ria-data/_data`)

### Why Docker Volumes are Used:
1. **Container Ephemerality**: When a container is upgraded, replaced, or deleted (`docker rm -f`), database records remain intact inside the Docker volume.
2. **Permission Isolation**: The volume is owned by the non-root `node` user (UID 1000), preventing permission denied errors during database writes.
3. **Cross-Container Continuity**: As demonstrated in step `o)` of the command log, deleting container `ria-dev` and launching a brand new container with `-v ria-data:/app/data` restores all inventory records, transactions, and alert states instantaneously.

---

## 6. Docker Health Check Configuration

The Dockerfile configures an automated container health probe:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r => { if (!r.ok) process.exit(1); }).catch(() => process.exit(1))"
```

- **Interval (`30s`)**: Probes the endpoint every 30 seconds during normal operation.
- **Timeout (`5s`)**: Fails a probe if the HTTP request takes longer than 5 seconds.
- **Start Period (`10s`)**: Grace period allowing Node.js and SQLite initialization before marking failure.
- **Retries (`3`)**: Marks the container `unhealthy` after 3 consecutive failed probes.
- **Mechanism**: Utilizes Node 22 native `fetch()`, removing the need for external tools like `curl` or `wget` in the slim runtime image.
