# Project Knowledge Base

## Overview

This project sets up OpenEMR for Clínica Saraiva Vision using Docker Compose. It includes a pre-configured Nginx reverse proxy for HTTPS, initially with self-signed certificates, and now with support for Let's Encrypt.

## Key Files

- `docker-compose.yml`: Defines the services (OpenEMR, MySQL, Nginx, Certbot). Uses variables from `.env`.
- `docker/nginx/nginx.conf`: Nginx configuration for reverse proxy, SSL, and Let's Encrypt challenges.
- `saraiva-vision-setup.sh`: Script to initialize the Docker containers (primarily for initial setup).
- `README-Saraiva-Vision.md`: Detailed setup and usage instructions.
- `data/`: Host directories mounted as Docker volumes for persistent data.

## SSL/HTTPS Setup (Let's Encrypt)

This project is configured to use Let's Encrypt for SSL certificates for the domain `emr.saraivavision.com.br`.

**Prerequisites:**
- The domain `emr.saraivavision.com.br` must have its DNS A record pointing to the public IP address of the server running this Docker setup.
- Port 80 and 443 must be open on the server.

**Initial Certificate Generation:**
1.  **Start Nginx and other services:**
    ```bash
    docker-compose up -d --remove-orphans
    ```
    (Nginx might show errors initially as certificates don't exist yet. This is expected.)

2.  **Run Certbot to Obtain the Certificate:**
    Replace `philipe_cruz@outlook.com` with your actual email if different.
    ```bash
    docker-compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot \
        --email philipe_cruz@outlook.com --agree-tos --no-eff-email \
        -d emr.saraivavision.com.br
    ```

3.  **Restart Nginx:**
    Once Certbot successfully obtains the certificates:
    ```bash
    docker-compose restart nginx
    ```

4.  **Ensure Certbot service is running for renewals:**
    The Certbot service defined in `docker-compose.yml` handles automatic renewals. If it's not already running from step 1:
    ```bash
    docker-compose up -d certbot
    ```
    Or simply ensure all services are up:
    ```bash
    docker-compose up -d
    ```

**Automated Renewal:**
The `certbot` service in `docker-compose.yml` is configured to attempt renewal every 12 hours.

**Accessing the Application:**
Access OpenEMR via `https://emr.saraivavision.com.br`. Accessing via `https://localhost` will result in certificate warnings as the Let's Encrypt certificate is issued for the specific domain.

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
-   **Database Migrations:** OpenEMR handles its own schema. Backups are crucial.
-   Use the `backup.sh` script or another backup tool to export the database regularly.
-   **SSL Certificates:** Now managed by Let's Encrypt. Ensure renewal process is monitored.
-   **Downtime:** `docker-compose up -d` can cause brief downtime. For zero-downtime, consider blue/green deployments or load balancing with multiple instances.
-   **Monitoring & Logging:** Implement robust monitoring and centralized logging for production.

## Development Environment
- For initial setup, you can still use `./saraiva-vision-setup.sh` but be aware it's now configured for Let's Encrypt.
- If developing locally without a public domain/IP, the Let's Encrypt setup will not work. You might need to temporarily revert to self-signed certificates or use a different Nginx configuration for local-only development.
- Access via `https://emr.saraivavision.com.br` (requires DNS and public IP).
- Default OpenEMR credentials: `admin`/`pass`.

## Production Deployment Notes
- Ensure the domain `emr.saraivavision.com.br` points to your server's public IP.
- Follow the Let's Encrypt initial certificate generation steps.
- Ensure `docker-compose.yml` environment variables for passwords are secure.
