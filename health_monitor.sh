#!/bin/bash

# Health Monitor for OpenEMR
# Monitors various health metrics and alerts when thresholds are exceeded

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly CONFIG_FILE="${SCRIPT_DIR}/config/health_monitor.conf"
readonly LOG_FILE="${SCRIPT_DIR}/logs/health_monitor.log"
readonly PID_FILE="${SCRIPT_DIR}/health_monitor.pid"

# Default thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=85
LOAD_THRESHOLD=2.0
CHECK_INTERVAL=300

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m' # No Color

# Load configuration if exists
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    local message="$1"
    log_message "ERROR" "$message"
    exit 1
}

# Cleanup function
cleanup() {
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
    fi
    log_message "INFO" "Health monitor stopped"
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Check if running as daemon
check_daemon() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            error_exit "Health monitor is already running with PID $pid"
        else
            rm -f "$PID_FILE"
        fi
    fi
}

# Write PID file
write_pid() {
    echo $$ > "$PID_FILE"
}

# CPU usage check
check_cpu_usage() {
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        log_message "WARNING" "High CPU usage: ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)"
        send_alert "High CPU Usage" "CPU usage is at ${cpu_usage}% which exceeds threshold of ${CPU_THRESHOLD}%"
        return 1
    else
        log_message "INFO" "CPU usage: ${cpu_usage}% (OK)"
        return 0
    fi
}

# Memory usage check
check_memory_usage() {
    local memory_info
    local total_mem
    local used_mem
    local memory_percent
    
    memory_info=$(free | grep Mem)
    total_mem=$(echo "$memory_info" | awk '{print $2}')
    used_mem=$(echo "$memory_info" | awk '{print $3}')
    memory_percent=$(echo "scale=2; $used_mem * 100 / $total_mem" | bc)
    
    if (( $(echo "$memory_percent > $MEMORY_THRESHOLD" | bc -l) )); then
        log_message "WARNING" "High memory usage: ${memory_percent}% (threshold: ${MEMORY_THRESHOLD}%)"
        send_alert "High Memory Usage" "Memory usage is at ${memory_percent}% which exceeds threshold of ${MEMORY_THRESHOLD}%"
        return 1
    else
        log_message "INFO" "Memory usage: ${memory_percent}% (OK)"
        return 0
    fi
}

# Disk usage check
check_disk_usage() {
    local mount_point
    local usage_percent
    local status=0
    
    while IFS= read -r line; do
        mount_point=$(echo "$line" | awk '{print $6}')
        usage_percent=$(echo "$line" | awk '{print $5}' | cut -d'%' -f1)
        
        if [[ "$usage_percent" =~ ^[0-9]+$ ]] && (( usage_percent > DISK_THRESHOLD )); then
            log_message "WARNING" "High disk usage on $mount_point: ${usage_percent}% (threshold: ${DISK_THRESHOLD}%)"
            send_alert "High Disk Usage" "Disk usage on $mount_point is at ${usage_percent}% which exceeds threshold of ${DISK_THRESHOLD}%"
            status=1
        else
            log_message "INFO" "Disk usage on $mount_point: ${usage_percent}% (OK)"
        fi
    done < <(df -h | grep -E '^/dev/')
    
    return $status
}

# Load average check
check_load_average() {
    local load_avg
    local load_1min
    
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | cut -d',' -f1)
    load_1min=$(echo "$load_avg" | xargs)
    
    if (( $(echo "$load_1min > $LOAD_THRESHOLD" | bc -l) )); then
        log_message "WARNING" "High load average: $load_1min (threshold: $LOAD_THRESHOLD)"
        send_alert "High Load Average" "Load average is at $load_1min which exceeds threshold of $LOAD_THRESHOLD"
        return 1
    else
        log_message "INFO" "Load average: $load_1min (OK)"
        return 0
    fi
}

# Docker container health check
check_docker_containers() {
    local failed_containers=()
    
    if ! command -v docker &> /dev/null; then
        log_message "WARNING" "Docker not found, skipping container health check"
        return 0
    fi
    
    while IFS= read -r container; do
        local container_name
        local health_status
        
        container_name=$(echo "$container" | awk '{print $1}')
        health_status=$(echo "$container" | awk '{print $2}')
        
        if [[ "$health_status" != "healthy" ]] && [[ "$health_status" != "Up" ]]; then
            failed_containers+=("$container_name")
            log_message "ERROR" "Container $container_name is unhealthy: $health_status"
        else
            log_message "INFO" "Container $container_name: $health_status (OK)"
        fi
    done < <(docker ps --format "table {{.Names}}\t{{.Status}}" | tail -n +2)
    
    if [[ ${#failed_containers[@]} -gt 0 ]]; then
        send_alert "Docker Container Issues" "The following containers are unhealthy: ${failed_containers[*]}"
        return 1
    fi
    
    return 0
}

# Database connectivity check
check_database_connection() {
    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-3306}"
    local db_user="${DB_USER:-root}"
    local db_pass="${DB_PASS:-}"
    local db_name="${DB_NAME:-openemr}"
    
    if command -v mysql &> /dev/null; then
        if mysql -h "$db_host" -P "$db_port" -u "$db_user" -p"$db_pass" -e "USE $db_name; SELECT 1;" &> /dev/null; then
            log_message "INFO" "Database connection: OK"
            return 0
        else
            log_message "ERROR" "Database connection failed"
            send_alert "Database Connection Failed" "Cannot connect to database $db_name on $db_host:$db_port"
            return 1
        fi
    else
        log_message "WARNING" "MySQL client not found, skipping database check"
        return 0
    fi
}

# Web service health check
check_web_service() {
    local web_url="${WEB_URL:-http://localhost}"
    local expected_status="${EXPECTED_STATUS:-200}"
    local actual_status
    
    if command -v curl &> /dev/null; then
        actual_status=$(curl -s -o /dev/null -w "%{http_code}" "$web_url" || echo "000")
        
        if [[ "$actual_status" == "$expected_status" ]]; then
            log_message "INFO" "Web service health: OK (HTTP $actual_status)"
            return 0
        else
            log_message "ERROR" "Web service health check failed: HTTP $actual_status (expected $expected_status)"
            send_alert "Web Service Down" "Web service at $web_url returned HTTP $actual_status instead of expected $expected_status"
            return 1
        fi
    else
        log_message "WARNING" "curl not found, skipping web service check"
        return 0
    fi
}

# SSL certificate expiry check
check_ssl_certificate() {
    local domain="${SSL_DOMAIN:-localhost}"
    local warning_days="${SSL_WARNING_DAYS:-30}"
    local cert_expiry
    local days_until_expiry
    
    if command -v openssl &> /dev/null; then
        cert_expiry=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
        
        if [[ -n "$cert_expiry" ]]; then
            local expiry_epoch
            local current_epoch
            
            expiry_epoch=$(date -d "$cert_expiry" +%s)
            current_epoch=$(date +%s)
            days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
            
            if (( days_until_expiry <= warning_days )); then
                log_message "WARNING" "SSL certificate for $domain expires in $days_until_expiry days"
                send_alert "SSL Certificate Expiring" "SSL certificate for $domain expires in $days_until_expiry days"
                return 1
            else
                log_message "INFO" "SSL certificate for $domain: OK ($days_until_expiry days remaining)"
                return 0
            fi
        else
            log_message "ERROR" "Could not retrieve SSL certificate information for $domain"
            return 1
        fi
    else
        log_message "WARNING" "openssl not found, skipping SSL certificate check"
        return 0
    fi
}

# Send alert function
send_alert() {
    local subject="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # TODO: Implement email alerting
    log_message "ALERT" "$subject: $message"
    
    # TODO: Implement Slack/Discord webhook notifications
    # TODO: Implement SMS alerting via Twilio
    # TODO: Implement PagerDuty integration
    
    # For now, just log the alert
    echo "ALERT [$timestamp]: $subject - $message" >> "${SCRIPT_DIR}/logs/alerts.log"
}

# Generate health report
generate_report() {
    local report_file
    local timestamp
    report_file="${SCRIPT_DIR}/reports/health_report_$(date +%Y%m%d_%H%M%S).html"
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>OpenEMR Health Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .ok { color: green; }
        .warning { color: orange; }
        .error { color: red; }
        .metric { margin: 10px 0; padding: 10px; border: 1px solid #ddd; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>OpenEMR Health Report</h1>
        <p>Generated: $timestamp</p>
    </div>
    
    <div class="metric">
        <h3>System Metrics</h3>
        <p>CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%</p>
        <p>Memory Usage: $(free | grep Mem | awk '{printf "%.2f", $3*100/$2}')%</p>
        <p>Load Average: $(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | cut -d',' -f1 | xargs)</p>
    </div>
    
    <div class="metric">
        <h3>Service Status</h3>
        <p>Database: $(check_database_connection &>/dev/null && echo "OK" || echo "ERROR")</p>
        <p>Web Service: $(check_web_service &>/dev/null && echo "OK" || echo "ERROR")</p>
    </div>
</body>
</html>
EOF
    
    log_message "INFO" "Health report generated: $report_file"
}

# Main monitoring loop
run_monitoring() {
    log_message "INFO" "Starting health monitoring (PID: $$)"
    write_pid
    
    while true; do
        local overall_status=0
        
        log_message "INFO" "Running health checks..."
        
        # Run all health checks
        check_cpu_usage || overall_status=1
        check_memory_usage || overall_status=1
        check_disk_usage || overall_status=1
        check_load_average || overall_status=1
        check_docker_containers || overall_status=1
        check_database_connection || overall_status=1
        check_web_service || overall_status=1
        check_ssl_certificate || overall_status=1
        
        if [[ $overall_status -eq 0 ]]; then
            log_message "INFO" "All health checks passed"
        else
            log_message "WARNING" "Some health checks failed"
        fi
        
        # Generate report every hour (12 cycles of 5 minutes)
        local cycle_count
        cycle_count=$((${cycle_count:-0} + 1))
        if (( cycle_count >= 12 )); then
            generate_report
            cycle_count=0
        fi
        
        log_message "INFO" "Sleeping for $CHECK_INTERVAL seconds..."
        sleep "$CHECK_INTERVAL"
    done
}

# Show help
show_help() {
    cat << EOF
OpenEMR Health Monitor

Usage: $0 [OPTION]

Options:
    start       Start the health monitor daemon
    stop        Stop the health monitor daemon
    status      Show daemon status
    check       Run health checks once
    report      Generate health report
    help        Show this help message

Configuration:
    Edit $CONFIG_FILE to customize thresholds and settings.

Logs:
    Monitor logs: $LOG_FILE
    Alert logs: ${SCRIPT_DIR}/logs/alerts.log

EOF
}

# Main function
main() {
    local action="${1:-help}"
    
    # Create necessary directories
    mkdir -p "$(dirname "$LOG_FILE")" "${SCRIPT_DIR}/reports" "${SCRIPT_DIR}/config"
    
    case "$action" in
        start)
            check_daemon
            run_monitoring
            ;;
        stop)
            if [[ -f "$PID_FILE" ]]; then
                local pid
                pid=$(cat "$PID_FILE")
                if kill "$pid" 2>/dev/null; then
                    log_message "INFO" "Health monitor stopped (PID: $pid)"
                    rm -f "$PID_FILE"
                else
                    error_exit "Failed to stop health monitor (PID: $pid)"
                fi
            else
                echo "Health monitor is not running"
                exit 1
            fi
            ;;
        status)
            if [[ -f "$PID_FILE" ]]; then
                local pid
                pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    echo "Health monitor is running (PID: $pid)"
                    exit 0
                else
                    echo "Health monitor is not running (stale PID file)"
                    rm -f "$PID_FILE"
                    exit 1
                fi
            else
                echo "Health monitor is not running"
                exit 1
            fi
            ;;
        check)
            log_message "INFO" "Running one-time health check"
            local overall_status=0
            
            check_cpu_usage || overall_status=1
            check_memory_usage || overall_status=1
            check_disk_usage || overall_status=1
            check_load_average || overall_status=1
            check_docker_containers || overall_status=1
            check_database_connection || overall_status=1
            check_web_service || overall_status=1
            check_ssl_certificate || overall_status=1
            
            if [[ $overall_status -eq 0 ]]; then
                echo -e "${GREEN}All health checks passed${NC}"
                exit 0
            else
                echo -e "${RED}Some health checks failed${NC}"
                exit 1
            fi
            ;;
        report)
            generate_report
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown action: $action"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
