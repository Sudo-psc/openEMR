#!/bin/bash

# Health Monitor Script

# --- Configuration ---
# All configuration variables can be overridden by setting them as environment variables.

OPENEMR_URL="${OPENEMR_URL:-https://emr.saraivavision.com.br}" # Target URL for the OpenEMR application check. Default: https://emr.saraivavision.com.br
MYSQL_CONTAINER_NAME="${MYSQL_CONTAINER_NAME:-mysql}" # Name of the MySQL Docker container. Default: mysql
DB_USER="${DB_USER:-${MYSQL_USER:-openemr}}" # MySQL user for database check. Defaults to MYSQL_USER env var if set, otherwise 'openemr'.
DB_PASS="${DB_PASS:-${MYSQL_PASS}}" # MySQL password for DB_USER. MUST BE SET via environment variable (e.g., export DB_PASS="your_password"). Typically same as MYSQL_PASS for OpenEMR.
# Note: For mysqladmin ping, user/pass might not be strictly needed if run as root equivalent inside container,
# but it's good practice if we switch to a query later or if ping requires it.
# If using root, it would be:
# DB_USER_ROOT="${DB_USER_ROOT:-${MYSQL_ROOT_USER:-root}}" # MySQL root user, often 'root'.
# DB_PASS_ROOT="${DB_PASS_ROOT:-${MYSQL_ROOT_PASSWORD}}" # MySQL root password. MUST BE SET if root fallback is intended. (e.g., MYSQL_ROOT_PASSWORD)

NGINX_CONTAINER_NAME="${NGINX_CONTAINER_NAME:-nginx}" # Name of the Nginx Docker container. Default: nginx
NGINX_HEALTH_URL_INTERNAL="${NGINX_HEALTH_URL_INTERNAL:-http://localhost/health.html}" # URL for Nginx health endpoint. Assumes Nginx port 80 is mapped to host. Default: http://localhost/health.html
SSL_DOMAIN_TO_CHECK="${SSL_DOMAIN_TO_CHECK:-emr.saraivavision.com.br}" # Domain for SSL certificate expiry check. Default: emr.saraivavision.com.br
# Prerequisite for SSL check: 'openssl' command-line tool must be installed.
SSL_CERT_WARN_DAYS="${SSL_CERT_WARN_DAYS:-30}" # Days before SSL certificate expiry to issue a warning. Default: 30
CERTBOT_CONTAINER_NAME="${CERTBOT_CONTAINER_NAME:-certbot}" # Name of the Certbot Docker container. Default: certbot
CERTBOT_LOG_LINES_TO_CHECK="${CERTBOT_LOG_LINES_TO_CHECK:-50}" # Number of recent Certbot log lines to inspect. Default: 50

ALERT_EMAIL_RECIPIENT="${ALERT_EMAIL_RECIPIENT:-}" # Email address for sending alerts. MUST BE SET for email notifications to work.
ALERT_EMAIL_SUBJECT_PREFIX="${ALERT_EMAIL_SUBJECT_PREFIX:-[HealthMonitor Alert]}" # Subject prefix for alert emails. Default: [HealthMonitor Alert]
# Prerequisite for email alerts: 'mail' command (from mailutils or similar package) must be installed and configured on the system running this script.

FAILED_CHECKS=() # Array to store messages for failed checks. Used for accumulating failures for the alert email.
# TODO: Add configurable variables (URLs, email, etc.) here

# --- Helper Functions ---
# General prerequisite: The user running this script needs permissions to execute 'docker' commands (e.g., part of the 'docker' group or sudo access).
# General prerequisite: 'curl' command-line tool must be installed.
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] - $1"
}

record_failure() {
    local message="$1"
    log_message "FAILURE DETECTED: $message" # Log it using existing log_message
    FAILED_CHECKS+=("$message")
}
# TODO: Add helper functions (e.g., for logging, sending alerts) here

# --- Service Checks ---

# 1. OpenEMR Application Check
# Checks if the OpenEMR application is accessible and returns a 200 HTTP status code.
check_openemr() {
    log_message "Checking OpenEMR application at ${OPENEMR_URL}..."
    HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" -L "${OPENEMR_URL}") # -L follows redirects

    if [ "$HTTP_STATUS" -eq 200 ]; then
        log_message "OpenEMR application is UP. Status: ${HTTP_STATUS}"
        return 0 # Success
    else
        record_failure "OpenEMR application is DOWN or returned status ${HTTP_STATUS}."
        return 1 # Failure
    fi
}

# 2. MySQL Database Check
# Checks if the MySQL database server is running and accessible by attempting to ping it using 'mysqladmin ping'.
# Requires DB_PASS to be set. Can also try a fallback to root user if configured and initial ping fails.
check_mysql() {
    log_message "Checking MySQL database connection on container '${MYSQL_CONTAINER_NAME}'..."

    # Check if DB_PASS is set, otherwise we can't proceed
    if [ -z "${DB_PASS}" ]; then
        record_failure "MySQL check skipped: DB_PASS environment variable is not set."
        return 1 # Failure, as we can't perform the check
    fi

    # Attempt to ping the MySQL server
    # The --silent flag for mysqladmin ping suppresses output on success.
    # We check the exit code.
    if docker exec "${MYSQL_CONTAINER_NAME}" mysqladmin ping -u"${DB_USER}" -p"${DB_PASS}" --silent; then
        log_message "MySQL database is UP. Connection successful."
        return 0 # Success
    else
        # Try with root user as a fallback, as ping might be restricted for the application user
        # This assumes MYSQL_ROOT_PASSWORD is set in the environment.
        # If DB_USER is already root, this won't make a difference.
        if [ "${DB_USER}" != "root" ] && [ -n "${MYSQL_ROOT_PASSWORD}" ]; then
            log_message "MySQL ping with ${DB_USER} failed. Trying with root..."
            if docker exec "${MYSQL_CONTAINER_NAME}" mysqladmin ping -uroot -p"${MYSQL_ROOT_PASSWORD}" --silent; then
                log_message "MySQL database is UP (connected as root). Connection successful."
                return 0 # Success
            else
                        record_failure "MySQL database is DOWN or connection failed (even as root). User: ${DB_USER}. Exit code: $?"
                return 1 # Failure
            fi
        else
                    record_failure "MySQL database is DOWN or connection failed for user ${DB_USER}. Exit code: $?"
            return 1 # Failure
        fi
    fi
}

# 3. Nginx Reverse Proxy Checks

# 3a. Nginx Process Check
# Checks if the Nginx process is running inside its designated Docker container.
check_nginx_process() {
    log_message "Checking Nginx process on container '${NGINX_CONTAINER_NAME}'..."
    if docker exec "${NGINX_CONTAINER_NAME}" pgrep nginx > /dev/null; then
        log_message "Nginx process is RUNNING."
        return 0 # Success
    else
        record_failure "Nginx process is NOT RUNNING on container ${NGINX_CONTAINER_NAME}."
        return 1 # Failure
    fi
}

# 3b. Nginx Health Endpoint Check
# Checks a specific health endpoint on Nginx (e.g., /health.html) for a 200 status and "OK" content.
# Assumes Nginx is serving this endpoint, typically mapped from the host.
check_nginx_health_endpoint() {
    log_message "Checking Nginx health endpoint at '${NGINX_HEALTH_URL_INTERNAL}'..."
    # This assumes the script is run from the host and Nginx port 80 is mapped to host's port 80.
    # The server block for 'localhost' in Nginx should respond.
    HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" -L "${NGINX_HEALTH_URL_INTERNAL}")

    if [ "$HTTP_STATUS" -eq 200 ]; then
        # Optionally, check content:
        CONTENT=$(curl --silent -L "${NGINX_HEALTH_URL_INTERNAL}")
        if echo "${CONTENT}" | grep -q "OK"; then
            log_message "Nginx health endpoint is UP and content is valid. Status: ${HTTP_STATUS}"
            return 0 # Success
        else
                    record_failure "Nginx health endpoint at ${NGINX_HEALTH_URL_INTERNAL} is UP (Status: ${HTTP_STATUS}) but content 'OK' not found."
            return 1 # Failure due to content mismatch
        fi
    else
                record_failure "Nginx health endpoint at ${NGINX_HEALTH_URL_INTERNAL} is DOWN or returned status ${HTTP_STATUS}."
        return 1 # Failure
    fi
}

# 3c. Nginx SSL Certificate Check
# Checks the SSL certificate for the specified domain (SSL_DOMAIN_TO_CHECK).
# Verifies if the certificate is not expired and warns if it's expiring soon (SSL_CERT_WARN_DAYS).
# Prerequisite: 'openssl' command-line tool must be installed on the system running this script (already noted in config section).
check_nginx_ssl_cert() {
    log_message "Checking SSL certificate for '${SSL_DOMAIN_TO_CHECK}'..."
    if ! command -v openssl &> /dev/null; then
        record_failure "SSL check skipped for ${SSL_DOMAIN_TO_CHECK}: openssl command not found."
        return 1 # Failure, as check cannot be performed
    fi

    # Get expiry date using openssl
    # The s_client command might hang if the remote server doesn't respond quickly or if there's a network issue.
    # Adding a timeout to openssl s_client. -connect_timeout is not standard for s_client.
    # We can use the 'timeout' command if available to wrap openssl s_client.
    TIMEOUT_CMD=""
    if command -v timeout &> /dev/null; then
        TIMEOUT_CMD="timeout 10s" # 10 second timeout
    fi

    EXPIRY_DATE_STR=$($TIMEOUT_CMD openssl s_client -servername "${SSL_DOMAIN_TO_CHECK}" \
                -connect "${SSL_DOMAIN_TO_CHECK}:443" 2>/dev/null \
                | openssl x509 -noout -dates 2>/dev/null \
                | grep 'notAfter=' \
                | cut -d= -f2)

    if [ -z "${EXPIRY_DATE_STR}" ]; then
        record_failure "Could not retrieve SSL certificate expiry date for '${SSL_DOMAIN_TO_CHECK}'."
        return 1 # Failure
    fi

    # Convert expiry date to seconds since epoch
    EXPIRY_DATE_SECS=""
    # Try GNU date first
    if type date | grep -q 'GNU coreutils'; then
         EXPIRY_DATE_SECS=$(date --date="${EXPIRY_DATE_STR}" +%s 2>/dev/null)
    fi

    # If GNU date failed or not available, try BSD date (common on macOS)
    if [ -z "${EXPIRY_DATE_SECS}" ]; then
        # OpenSSL date format is like "Sep  7 12:48:52 2024 GMT"
        # BSD date -j -f <format> <date_string> +<output_format>
        # The format string needs to match the input "MMM DD HH:MM:SS YYYY GMT"
        # For example: date -j -f "%b %d %T %Y %Z" "Sep 07 12:48:52 2024 GMT" "+%s"
        EXPIRY_DATE_SECS=$(date -j -f "%b %d %H:%M:%S %Y %Z" "${EXPIRY_DATE_STR}" "+%s" 2>/dev/null)
    fi

    if [ -z "${EXPIRY_DATE_SECS}" ]; then
        record_failure "Could not parse SSL certificate expiry date for '${SSL_DOMAIN_TO_CHECK}': '${EXPIRY_DATE_STR}'."
        return 1 # Failure, as date parsing is critical for this check
    fi

    CURRENT_DATE_SECS=$(date +%s)
    WARN_SECONDS=$((SSL_CERT_WARN_DAYS * 24 * 60 * 60))

    if [ "${EXPIRY_DATE_SECS}" -lt "${CURRENT_DATE_SECS}" ]; then
        record_failure "SSL certificate for '${SSL_DOMAIN_TO_CHECK}' has EXPIRED on ${EXPIRY_DATE_STR}."
        return 1 # Failure
    elif [ "$((EXPIRY_DATE_SECS - CURRENT_DATE_SECS))" -lt "${WARN_SECONDS}" ]; then
        log_message "SSL certificate for '${SSL_DOMAIN_TO_CHECK}' is expiring soon: ${EXPIRY_DATE_STR}. Days left: $(((EXPIRY_DATE_SECS - CURRENT_DATE_SECS) / (24*60*60)))"
        # This is a warning, but the service is still "up" from an SSL validity perspective for now.
        # The main alerting logic can decide if this triggers a different level of alert.
        # For the function's return status, 0 means "SSL is currently valid".
        return 0 # Success (cert is valid, though warning logged)
    else
        log_message "SSL certificate for '${SSL_DOMAIN_TO_CHECK}' is valid. Expires: ${EXPIRY_DATE_STR}. Days left: $(((EXPIRY_DATE_SECS - CURRENT_DATE_SECS) / (24*60*60)))"
        return 0 # Success
    fi
}

# 4. Certbot Service Check
# Checks the logs of the Certbot container for recent successful renewals or errors.
# This is an operational check for Certbot's activity, complementing the direct SSL certificate check.
check_certbot_logs() {
    log_message "Checking Certbot logs on container '${CERTBOT_CONTAINER_NAME}' for recent activity..."

    if ! docker ps -q --filter "name=^/${CERTBOT_CONTAINER_NAME}$" | grep -q .; then
        record_failure "Certbot container '${CERTBOT_CONTAINER_NAME}' is not running."
        return 1 # Failure
    fi

    # Get recent logs
    RECENT_LOGS=$(docker logs --tail "${CERTBOT_LOG_LINES_TO_CHECK}" "${CERTBOT_CONTAINER_NAME}" 2>&1)

    if [ -z "${RECENT_LOGS}" ]; then
        log_message "No recent logs found for Certbot container '${CERTBOT_CONTAINER_NAME}'."
        # This might not be an error if the container just started and hasn't logged much,
        # but could indicate an issue if it's been running a while.
        # For now, consider it a warning/neutral, but the Nginx SSL check is more definitive for cert status.
        return 0 # Neutral, rely on SSL cert check for actual cert issues
    fi

    # Check for errors or specific success messages
    # Certbot's verbosity can vary. "success", "renewed", "Congratulations" are good signs.
    # "error", "fail", "unable" are bad signs.
    # The entrypoint script for certbot runs `certbot renew`.
    # Successful renewal often includes lines like "Certificates renewed successfully" or "Congratulations!"
    # Failures might include "Attempting to renew cert...An unexpected error occurred." or "Failed to renew certificate".

    # Look for positive indicators of recent renewal activity
    if echo "${RECENT_LOGS}" | grep -E -i "success|renewed|Congratulations! Certificate and key success"; then
        log_message "Certbot logs show recent successful activity."
        # Check for negative indicators within the same recent logs, as a renewal attempt might log both progress and then an error.
        if echo "${RECENT_LOGS}" | grep -E -i "error|fail|unable to renew|Traceback"; then
            log_message "WARNING: Certbot logs show recent success but ALSO potential errors/failures. Manual review of Certbot logs recommended."
            # This is a nuanced state. For now, let's say it's a warning (return 0 but log indicates issue).
            # The SSL cert check itself is the ultimate arbiter of whether the cert is valid.
            return 0 # Still, the primary function of checking cert validity is done by SSL check.
        else
            return 0 # Success
        fi
    elif echo "${RECENT_LOGS}" | grep -E -i "No renewals were due|no action taken"; then
        log_message "Certbot logs indicate no renewals were due. This is normal."
        return 0 # Success (normal state if no certs are near expiry)
    elif echo "${RECENT_LOGS}" | grep -E -i "error|fail|Traceback|problem|could not"; then
        log_message "Certbot logs show potential errors or failures. Review Certbot logs for details."
        # Example: Search for "The following certificates are not due for renewal yet" to ensure it's not just that.
        if echo "${RECENT_LOGS}" | grep -q "The following certificates are not due for renewal yet"; then
            log_message "Certbot logs indicate certs are not due for renewal (found 'not due for renewal yet'). This is likely normal."
            return 0 # Success
        else
            # log_message "ERROR: Certbot logs suggest a problem. Full log excerpt for review:"
            record_failure "Certbot logs for '${CERTBOT_CONTAINER_NAME}' suggest a problem. Review logs."
            echo "${RECENT_LOGS}" # Print the logs for easier debugging from monitor output
            return 1 # Failure
        fi
    else
        log_message "Certbot logs do not show clear success or failure regarding recent renewals. Manual check might be needed if SSL issues arise. Last log lines:"
        echo "${RECENT_LOGS}"
        # This is an ambiguous state. The SSL check is the primary indicator.
        return 0 # Neutral/Warning
    fi
}

# --- Reporting/Alerting ---
send_alert_email() {
    if [ ${#FAILED_CHECKS[@]} -eq 0 ]; then
        log_message "All checks passed. No alert necessary."
        return
    fi

    if [ -z "${ALERT_EMAIL_RECIPIENT}" ]; then
        log_message "Alerts detected but ALERT_EMAIL_RECIPIENT is not set. Cannot send email."
        log_message "Failed checks summary:"
        for failure in "${FAILED_CHECKS[@]}"; do
            log_message "  - $failure"
        done
        return
    fi

    if ! command -v mail &> /dev/null; then
        log_message "Alerts detected but 'mail' command not found. Cannot send email."
        log_message "Failed checks summary:"
        for failure in "${FAILED_CHECKS[@]}"; do
            log_message "  - $failure"
        done
        return
    fi

    local subject="${ALERT_EMAIL_SUBJECT_PREFIX} - System Alert - $(hostname)"
    local body="The following health checks failed on $(hostname) at $(date):

"
    for failure in "${FAILED_CHECKS[@]}"; do
        body+=" - ${failure}
"
    done
    body+="

Please investigate.
"

    log_message "Sending alert email to ${ALERT_EMAIL_RECIPIENT}..."
    echo -e "${body}" | mail -s "${subject}" "${ALERT_EMAIL_RECIPIENT}"

    if [ $? -eq 0 ]; then
        log_message "Alert email sent successfully."
    else
        log_message "Failed to send alert email. Exit code: $?"
    fi
}

check_openemr
OPENEMR_STATUS=$?
# TODO: Use OPENEMR_STATUS for alerting

check_mysql
MYSQL_STATUS=$?
# TODO: Use MYSQL_STATUS for alerting

check_nginx_process
NGINX_PROCESS_STATUS=$?
# TODO: Use NGINX_PROCESS_STATUS for alerting

check_nginx_health_endpoint
NGINX_HEALTH_STATUS=$?
# TODO: Use NGINX_HEALTH_STATUS for alerting

check_nginx_ssl_cert
NGINX_SSL_STATUS=$?
# TODO: Use NGINX_SSL_STATUS for alerting

check_certbot_logs
CERTBOT_STATUS=$?
# TODO: Use CERTBOT_STATUS for alerting

# --- Finalize and Report ---
send_alert_email

log_message "Health monitoring script execution finished."

# Exit with 0 if all checks passed, 1 if any check failed (for cron or other schedulers)
if [ ${#FAILED_CHECKS[@]} -eq 0 ]; then
    exit 0
else
    exit 1
fi
