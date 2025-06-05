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
