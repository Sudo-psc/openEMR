#!/bin/bash
# Configure basic firewall rules for the Docker containers
# Opens HTTP and HTTPS ports used by Nginx reverse proxy
set -e

# Require sudo for firewall commands
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root or with sudo" >&2
  exit 1
fi

# Allow SSH so we do not lock ourselves out
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP and HTTPS for the reverse proxy
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow established connections and localhost
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

# Drop everything else by default
iptables -P INPUT DROP

echo "Firewall rules applied: ports 80 and 443 open"
