# Project Knowledge Base

## Overview

This project sets up OpenEMR for Clínica Saraiva Vision using Docker Compose. It includes a pre-configured Nginx reverse proxy that supports both HTTP and HTTPS access, with self-signed certificates as fallback and optional Let's Encrypt support.

## Key Files

- `docker-compose.yml`: Defines the services (OpenEMR, MySQL, Nginx, Certbot) with fallback SSL configuration.
- `nginx/nginx-fallback.conf`: Nginx configuration using self-signed certificates for immediate HTTPS access.
- `nginx/nginx.conf`: Original configuration for Let's Encrypt (not currently in use).
- `saraiva-vision-setup.sh`: Script to initialize the Docker containers.
- `README-Saraiva-Vision.md`: Detailed setup and usage instructions.

## Current SSL/HTTPS Setup

The system is currently configured to use **self-signed certificates** for immediate HTTPS access. This allows both HTTP and HTTPS to work without requiring Let's Encrypt setup.

**Current Access URLs:**
- **HTTP**: `http://localhost` (Local) or `http://emr.saraivavision.com.br` (Production)
- **HTTPS**: `https://localhost` or `https://emr.saraivavision.com.br` (Uses self-signed certificates - browsers will show security warnings)

**Configuration Details:**
- Uses `nginx-fallback.conf` which includes self-signed certificates
- Self-signed certificates are mapped from `./ssl/` directory
- Both HTTP and HTTPS work immediately without additional setup
- HTTPS will show browser warnings due to self-signed certificates

## Optional Let's Encrypt Upgrade

To upgrade to Let's Encrypt certificates (for production without browser warnings):

**Prerequisites:**
- The domain `emr.saraivavision.com.br` must have its DNS A record pointing to the public IP address of the server.
- Port 80 and 443 must be open on the server.

**Steps to Enable Let's Encrypt:**
1. Switch nginx configuration back to the original:
   ```bash
   # In docker-compose.yml, change:
   # - ./nginx/nginx-fallback.conf:/etc/nginx/nginx.conf:ro
   # to:
   # - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
   ```

2. **Run Certbot to Obtain the Certificate:**
   ```bash
   docker-compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot \
       --email philipe_cruz@outlook.com --agree-tos --no-eff-email \
       -d emr.saraivavision.com.br
   ```

3. **Restart Nginx:**
   ```bash
   docker-compose restart nginx
   ```

## CI/CD Strategy (Proposed)

This section outlines a potential CI/CD strategy for this project.

### 1. Version Control
- All project configuration files (Dockerfile if custom images are used, `docker-compose.yml`, Nginx configs, setup scripts) should be versioned in a Git repository.

### 2. Continuous Integration (CI)

**Trigger:** Push or merge to the main branch.

**Pipeline Steps:**
1.  **Checkout Code:** Get the latest version of the repository.
2.  **Linting/Static Analysis (Optional but Recommended):**
    *   Lint `docker-compose.yml` (e.g., using `docker-compose config`).
    *   Lint shell scripts (e.g., using `shellcheck`).
3.  **Build Docker Images:**
    *   If using custom Dockerfiles for OpenEMR or other services, build them here.
    *   Currently, the project uses pre-built images from Docker Hub (`openemr/openemr:7.0.3`, `mariadb:11.4`, `nginx:alpine`). If these are sufficient, this step might just involve pulling them to ensure they are accessible.
4.  **Test (Placeholder - to be defined):**
    *   **Smoke Tests:** After `docker-compose up -d`, perform basic health checks (e.g., can Nginx be reached? Does OpenEMR respond?).
    *   **Integration Tests:** (More complex) Test interactions between services.
5.  **Tagging (if building custom images):**
    *   Tag successfully built images (e.g., with Git commit SHA, version number).
6.  **Push Images (if building custom images):**
    *   Push tagged images to a Docker registry (e.g., Docker Hub, AWS ECR, GitLab Container Registry).

### 3. Continuous Deployment (CD)

**Trigger:** Successful CI pipeline completion on the main branch (or a specific release branch/tag).

**Deployment Strategy (Example for a single server):**

1.  **SSH to Server:** Securely connect to the deployment server.
2.  **Checkout/Pull Latest Config:**
    *   If `docker-compose.yml` and other configs are managed on the server via Git, pull the latest changes.
3.  **Pull Latest Images:**
    *   `docker-compose pull` (pulls images defined in `docker-compose.yml`, including newly pushed custom images if the `docker-compose.yml` references the new tags).
4.  **Restart Services:**
    *   `docker-compose up -d --remove-orphans` (recreates containers if their configuration or image has changed).
5.  **Post-Deployment Checks:**
    *   Verify services are running and accessible.
    *   Run basic health checks.

### Tools for CI/CD:
-   **GitHub Actions:** Good for projects hosted on GitHub.
-   **GitLab CI/CD:** Integrated solution if using GitLab.
-   **Jenkins:** Powerful, self-hosted option.
-   **AWS CodePipeline/CodeDeploy, Google Cloud Build, Azure DevOps:** Cloud-specific solutions.

### Considerations for Production:
-   **Secrets Management:** Securely manage passwords (e.g., `MYSQL_ROOT_PASSWORD`, `OE_PASS`) using CI/CD environment variables or a secrets manager, rather than hardcoding in `docker-compose.yml` for production.
-   **Database Migrations e Backup de Dados:** OpenEMR lida com seu próprio esquema. Consulte a seção "Backup e Restauração de Dados" no `README-Saraiva-Vision.md` para instruções detalhadas e boas práticas de backup, com timestamp, compactação e restauração segura.
-   **SSL Certificates:** Currently using self-signed certificates. For production, consider upgrading to Let's Encrypt.
-   **Downtime:** `docker-compose up -d` can cause brief downtime. For zero-downtime, consider blue/green deployments or load balancing with multiple instances.
-   **Monitoring & Logging:** Implement robust monitoring and centralized logging for production.

## Development Environment
- For immediate setup, use `./saraiva-vision-setup.sh` which now works with self-signed certificates.
- Access via `http://localhost` for HTTP or `https://localhost` for HTTPS (with browser warnings).
- Default OpenEMR credentials: `admin`/`pass`.

## Production Deployment Notes
- Current setup works immediately with self-signed certificates
- For production without browser warnings, upgrade to Let's Encrypt following the steps above
- Ensure `docker-compose.yml` environment variables for passwords are secure.
