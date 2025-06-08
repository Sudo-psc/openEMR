# OpenEMR Env Installer

## Overview
The **OpenEMR Env Installer** helps set up the base tooling required for development or testing environments. It installs Git, Docker, docker-compose, `openemr-cmd`, minikube and `kubectl` so you can get started quickly on a clean system.

## Implementation
Download the installer and make it executable:

```bash
curl -L https://raw.githubusercontent.com/openemr/openemr-devops/master/utilities/openemr-env-installer/openemr-env-installer > openemr-env-installer
chmod +x openemr-env-installer
```

Run the installer:

```bash
./openemr-env-installer
```

Usage:

```bash
bash openemr-env-installer <code location> <github account>
```

Example:

```bash
bash openemr-env-installer /home/test/code testuser
```

### Notes
1. Make sure you have created forks of both OpenEMR and `openemr-devops` before running the installer.
2. If using minikube, confirm the host machine satisfies:
   * 2 CPUs or more
   * 2GB of free memory
   * 20GB of free disk space
   * Internet connection
    * A container or virtual machine manager such as Docker, Hyperkit, Hyper-V, KVM, Parallels, Podman, VirtualBox or VMWare.

## Optional: Install the OpenEMR Monitor

The [OpenEMR Monitor](https://github.com/openemr/openemr-devops/tree/master/utilities/openemr-monitor)
provides a Prometheus and Grafana based environment for monitoring your
containers. To download the monitor installer and set it up, run:

```bash
curl -L https://raw.githubusercontent.com/openemr/openemr-devops/master/utilities/openemr-monitor/monitor-installer > monitor-installer
chmod +x monitor-installer
./monitor-installer <install dir> <host ip> <smtp server:port> <sender email> <sender password> <receiver email>
```

Replace the arguments with the desired installation directory and your email
settings. The script will download the necessary Compose files and print
instructions to start the monitoring stack.
