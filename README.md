# OpenEMR Docker Setup

This repository provides a simple Docker Compose configuration for [OpenEMR](https://www.open-emr.org/). Nginx acts as a reverse proxy with Let's Encrypt support.

## Getting Started

On Ubuntu systems you can run the helper script `ubuntu-setup.sh` to install
Docker dependencies and start the containers. The script will ask for the
domain name and the main environment variables before generating the `.env`
file and optionally configuring the firewall:

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
6. The compose file also includes a `php-fpm` service. Place your PHP files in
   the `./php` directory to have them served by this container.
7. A `couchdb` service is provided for modules that require CouchDB. Set
   `COUCHDB_USER` and `COUCHDB_PASSWORD` in your `.env` file to enable it. The
   database is exposed on port `5984`.

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

### Suppressing Apache ServerName Warning

If you see a message like:

```
AH00558: httpd: Could not reliably determine the server's fully qualified domain name
```

Apache needs a `ServerName` directive. The compose file mounts
`apache/servername.conf` into the OpenEMR container to set this to `localhost`.
Edit that file if you want to use a different domain name.

## Troubleshooting 502 Bad Gateway
A 502 response from Nginx usually means it cannot reach the OpenEMR container or the application failed to start.
Check the following:

1. Verify all containers are running:
   ```bash
   docker-compose ps
   ```
   The `openemr`, `mysql` and `nginx` services should be listed as `Up`.
2. Ensure the `.env` file has valid database credentials. If these values are missing or wrong, the OpenEMR container may exit.
3. Review container logs for errors:
   ```bash
   docker-compose logs openemr
   docker-compose logs nginx
   ```
4. After fixing any issues, restart the services:
   ```bash
   docker-compose restart openemr nginx
   ```

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

## Health Monitoring

### Overview
The `health_monitor.sh` script is designed to perform regular checks on the vital components of the OpenEMR Docker deployment, including the OpenEMR application itself, the MySQL database, Nginx reverse proxy, and Certbot certificate renewal status. It can log its findings and send email alerts if any checks fail.

### Prerequisites
The following tools and conditions are required on the system where `health_monitor.sh` is executed:

*   **`bash`**: The script is written in bash.
*   **`curl`**: Used for HTTP checks (OpenEMR application, Nginx health endpoint).
*   **`docker`**: Required to interact with the Docker daemon to check container statuses (Nginx process, MySQL, Certbot logs) and execute commands within containers. The user running the script must have permissions to use Docker (e.g., be part of the `docker` group).
*   **`openssl`**: Needed for checking SSL certificate validity and expiry dates.
*   **`mailutils`** (or an equivalent package providing the `mail` command): Required if email alerts are desired.
*   **Running Containers**: The OpenEMR, MySQL, Nginx, and Certbot Docker containers, as defined in `docker-compose.yml`, should be running.

### Configuration
The `health_monitor.sh` script is configured primarily through environment variables. Default values are provided for most settings, but critical items like passwords and email recipients must be set.

Key environment variables:

*   `OPENEMR_URL`: URL of the OpenEMR login page. (Default: `https://emr.saraivavision.com.br`)
*   `MYSQL_CONTAINER_NAME`: Name of the MySQL Docker container. (Default: `mysql`)
*   `DB_USER`: MySQL user for the database connectivity check. (Default: `openemr` or the value of `MYSQL_USER` if set)
*   `DB_PASS`: MySQL password for `DB_USER`. **Must be set in the environment.** (This is typically the same as `MYSQL_PASS` from your `.env` file).
*   `MYSQL_ROOT_PASSWORD`: Root password for MySQL. Used as a fallback for the MySQL ping check if the `DB_USER` check fails and `DB_USER` is not 'root'.
*   `NGINX_CONTAINER_NAME`: Name of the Nginx Docker container. (Default: `nginx`)
*   `NGINX_HEALTH_URL_INTERNAL`: URL to check the Nginx health endpoint. (Default: `http://localhost/health.html` - this assumes Nginx's port 80 is mapped to the host's port 80 and the `health.html` endpoint is configured).
*   `SSL_DOMAIN_TO_CHECK`: The domain for which the SSL certificate's validity is checked. (Default: `emr.saraivavision.com.br`)
*   `SSL_CERT_WARN_DAYS`: Number of days before SSL certificate expiry to trigger a warning. (Default: `30`)
*   `CERTBOT_CONTAINER_NAME`: Name of the Certbot Docker container. (Default: `certbot`)
*   `CERTBOT_LOG_LINES_TO_CHECK`: Number of recent Certbot log lines to inspect for errors or success. (Default: `50`)
*   `ALERT_EMAIL_RECIPIENT`: Email address to which alert notifications will be sent. **Must be set in the environment for email alerts to function.**
*   `ALERT_EMAIL_SUBJECT_PREFIX`: Prefix for the subject line of alert emails. (Default: `[HealthMonitor Alert]`)

Example of running the script with environment variables:
```bash
export DB_PASS="your_mysql_openemr_user_password"
export MYSQL_ROOT_PASSWORD="your_mysql_root_password"
export ALERT_EMAIL_RECIPIENT="sysadmin@example.com"
./health_monitor.sh
```

### Manual Execution
1.  Make the script executable:
    ```bash
    chmod +x health_monitor.sh
    ```
2.  Run the script (ensure required environment variables are set as shown above):
    ```bash
    ./health_monitor.sh
    ```

### Automated Scheduling with Cron
To run the health monitor automatically, you can schedule it using `cron`.

1.  **Create a wrapper script** (recommended for managing environment variables):
    Save the following as `/path/to/your_project/run_health_monitor_cron.sh`:
    ```bash
    #!/bin/bash

    # Load environment variables if you use a .env file (optional, ensure it's secure)
    # if [ -f /path/to/your_project/.env ]; then
    #   export $(cat /path/to/your_project/.env | sed 's/#.*//g' | xargs)
    # fi

    # Explicitly set required variables for the health monitor
    export DB_PASS="your_mysql_openemr_user_password" # Or source from a secure location
    export MYSQL_ROOT_PASSWORD="your_mysql_root_password" # Or source
    export ALERT_EMAIL_RECIPIENT="sysadmin@example.com"
    # Add any other environment variables your health_monitor.sh script might need
    # export OPENEMR_URL="https://your.emr.domain"
    # export SSL_DOMAIN_TO_CHECK="your.emr.domain"

    # Navigate to the script's directory (optional, but good practice if script uses relative paths)
    # cd /path/to/your_project/

    # Execute the health monitor script, appending output to a log file
    /path/to/your_project/health_monitor.sh >> /var/log/health_monitor.log 2>&1
    ```
    Make the wrapper script executable: `chmod +x /path/to/your_project/run_health_monitor_cron.sh`

2.  **Edit your crontab**:
    Open your crontab for editing: `crontab -e`
    Add a line to schedule the wrapper script (e.g., to run every 15 minutes):
    ```cron
    */15 * * * * /path/to/your_project/run_health_monitor_cron.sh
    ```
    *Explanation of the cron entry:*
    *   `*/15 * * * *`: Runs the command every 15 minutes.
    *   `/path/to/your_project/run_health_monitor_cron.sh`: The command to execute.

    **Important Considerations for Cron:**
    *   **PATH Variable**: Cron jobs often have a minimal `PATH`. Ensure all commands used by your script (`docker`, `curl`, `mail`, `openssl`, `date`, `grep`, etc.) are either called with their full paths within `health_monitor.sh` or that the `PATH` is correctly set in the wrapper script or crontab. The `health_monitor.sh` generally calls commands without full paths, assuming they are in the standard system PATH.
    *   **Environment Variables**: Cron jobs do not inherit the environment of your interactive shell. They *must* be set explicitly in the crontab line or within the script being called (the wrapper script approach is cleaner for this).
    *   **Logging**: Redirecting standard output (`>>`) and standard error (`2>&1`) to a log file (e.g., `/var/log/health_monitor.log`) is crucial for debugging and auditing.

### Interpreting Output
*   The script logs its actions and check results to standard output. If run via cron, this output will be directed to the specified log file.
*   Each check performed will have a log message indicating its status (e.g., "OpenEMR application is UP", "MySQL database is DOWN").
*   If any check fails, a "FAILURE DETECTED" message is logged, and details of the failure are added to a list.
*   At the end of its execution:
    *   If all checks passed, it logs "All checks passed. No alert necessary."
    *   If any checks failed and `ALERT_EMAIL_RECIPIENT` is set (and `mail` command is available), an email alert summarizing the failures is sent.
    *   If alerts are detected but email cannot be sent (due to missing configuration or `mail` command), a summary of failures is logged to standard output.
*   The script exits with a status code:
    *   `0`: All checks passed successfully.
    *   `1`: One or more checks failed. This allows cron or other automation tools to detect script failure.
