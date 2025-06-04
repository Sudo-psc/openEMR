# OpenEMR Docker Setup

This repository provides a simple Docker Compose configuration for [OpenEMR](https://www.open-emr.org/). Nginx acts as a reverse proxy with Let's Encrypt support and Redis is used for PHP session storage.

## Getting Started

1. Copy `.env.example` to `.env` and set strong passwords for the database and initial OpenEMR user.
2. Start the services:
   ```bash
   docker-compose up -d
   ```
   The Redis service will automatically be used by PHP to store sessions.
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
  php/            # Additional PHP configuration (Redis sessions)
data/
  db/             # MariaDB data
  logs/           # OpenEMR logs
  openemr_sites/  # Persistent OpenEMR site data
  certbot/
    certs/        # Let's Encrypt certificates
    www/          # ACME challenge files
```

## Backup

Use the `backup.sh` script to create database dumps in the `./backups` directory.

```bash
./backup.sh
```

Schedule this script with `cron` to run daily.

## Security Notes

- Passwords are stored in the `.env` file, which is ignored by Git.
- The Nginx configuration includes security headers and enforces HTTPS.
- Keep containers and images up to date.

## Useful Commands

- Start/update services: `docker-compose up -d`
- Stop services: `docker-compose down`
- View logs: `docker-compose logs -f`

## CI/CD

A GitHub Actions workflow located at `.github/workflows/main.yml` checks the
Docker Compose configuration, lints shell scripts and performs a simple smoke
test. The smoke test spins up the services with the example environment file,
runs the `backup.sh` script and then shuts everything down. Use this workflow as
a starting point for automated deployments.

For more detailed instructions, see `README-Saraiva-Vision.md`.
