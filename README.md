# OpenEMR Docker Setup

This repository provides a Docker Compose setup for [OpenEMR](https://www.open-emr.org/). It includes CouchDB, Redis, a PHP utility container and optional threat monitoring with CrowdSec. Nginx acts as a reverse proxy with Let's Encrypt support.

## Getting Started

1. Copy `.env.example` to `.env` and set strong passwords for the database, CouchDB and the initial OpenEMR user.
2. Start the services:
   ```bash
   docker-compose up -d
   ```
3. Generate the Let's Encrypt certificate (replace the email address if needed):
   ```bash
   docker-compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot \
       --email you@example.com --agree-tos --no-eff-email \
       -d emr.saraivavision.com.br
   docker-compose restart nginx
   ```
4. Access `https://emr.saraivavision.com.br` and complete the setup wizard.
5. To keep your installation up to date run:
   ```bash
   ./update.sh
   ```
   This pulls the latest images, creates a backup and restarts the services.

## Directory Structure

```
docker/
  nginx/          # Nginx configuration
  ssl/            # Optional self‑signed certificates
data/
  db/             # MariaDB data
  logs/
    openemr/      # OpenEMR logs
    nginx/        # Nginx logs monitored by CrowdSec
  openemr_sites/  # Persistent OpenEMR site data
  couchdb/        # CouchDB data for documents
  redis/          # Redis persistent data
  crowdsec/       # CrowdSec data and decisions
  certbot/
    certs/        # Let's Encrypt certificates
    www/          # ACME challenge files
```

The stack exposes CouchDB on port `5984` and Redis on `6379`. CrowdSec monitors
the Nginx access logs for suspicious activity. Credentials and tuning options
are configured via `.env`.

## Backup

Use the `backup.sh` script to create database dumps in the `./backups` directory.
It exports MySQL, CouchDB and Redis data in one step.

```bash
./backup.sh
```

Schedule this script with `cron` to run daily.

## Security Notes

- Passwords are stored in the `.env` file, which is ignored by Git.
- The Nginx configuration includes security headers and enforces HTTPS.
- Keep containers and images up to date.
- CrowdSec monitors Nginx logs and can block malicious IPs automatically.

## Useful Commands

- Start/update services: `docker-compose up -d`
- Stop services: `docker-compose down`
- View logs: `docker-compose logs -f`
- Access CouchDB: `http://localhost:5984` (credentials from `.env`)
- Access Redis CLI: `docker-compose exec redis redis-cli`
- View CrowdSec decisions: `docker-compose exec crowdsec cscli decisions list`

## CI/CD

A GitHub Actions workflow located at `.github/workflows/main.yml` checks the
Docker Compose configuration, lints shell scripts and performs a simple smoke
test. The smoke test spins up the services with the example environment file,
runs the `backup.sh` script and then shuts everything down. Use this workflow as
a starting point for automated deployments.

For more detailed instructions, see `README-Saraiva-Vision.md`.
