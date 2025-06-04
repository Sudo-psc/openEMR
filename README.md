# OpenEMR Docker Setup

This repository provides a simple Docker Compose configuration for [OpenEMR](https://www.open-emr.org/). Nginx acts as a reverse proxy with Let's Encrypt support.

## Getting Started

On Ubuntu systems you can run the helper script `ubuntu-setup.sh` to install
Docker dependencies, configure the firewall and start the containers:

```bash
sudo ./ubuntu-setup.sh
```

If you prefer to set things up manually:

1. Copy `.env.example` to `.env` and set strong passwords for the database and initial OpenEMR user.
2. Start the services:
   ```bash
   docker-compose up -d
   ```
3. Generate the Let's Encrypt certificate (replace the email address if needed):
   ```bash
   docker-compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot \
       --email you@example.com --agree-tos --no-eff-email \
       -d openemr.example.com
   docker-compose restart nginx
   ```
4. Access `https://openemr.example.com` and complete the setup wizard.
5. To keep your installation up to date run:
   ```bash
   ./update.sh
   ```
   This pulls the latest images, creates a backup and restarts the services.

## Backup

Use the `backup.sh` script to create database dumps in the `./backups` directory.

```bash
./backup.sh
```
Set the `RCLONE_REMOTE` environment variable to automatically upload the
generated file using [rclone](https://rclone.org). The value should be a
configured remote path such as `s3:mybucket/backups`.

Schedule this script with `cron` to run daily.

## Security Notes

- Passwords are stored in the `.env` file, which is ignored by Git.
- The Nginx configuration includes security headers and enforces HTTPS.
- Keep containers and images up to date.
## Firewall Setup

Run `./firewall-setup.sh` as root to open ports 80 and 443 for the Docker containers.


## Useful Commands

- Start/update services: `docker-compose up -d`
- Stop services: `docker-compose down`
- View logs: `docker-compose logs -f`

## Log Monitoring with OpenAI

Use `log-monitor-openai.sh` to summarize container logs with the OpenAI API.
This script uses the `gpt-4o` model for more accurate summaries.
Set `OPENAI_API_KEY` and run:
```bash
OPENAI_API_KEY=your_key ./log-monitor-openai.sh
```

## CI/CD

A GitHub Actions workflow located at `.github/workflows/main.yml` checks the
Docker Compose configuration, lints shell scripts and performs a simple smoke
test. The smoke test spins up the services with the example environment file,
runs the `backup.sh` script and then shuts everything down. Use this workflow as
a starting point for automated deployments.

For more detailed instructions, see `README-Ophthalmology.md`.
