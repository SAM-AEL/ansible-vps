# Ansible Medusa VPS Setup

This Ansible repository provides a **setup for a fresh VPS**, including system hardening, Docker installation, and preparation for deploying a MedusaJS application. The setup ensures your VPS is **secure, maintainable, and ready for modern Node.js applications**.

---

## Features

### 1. Security Hardening
- Full system package updates and upgrades.
- Automatic security updates via `unattended-upgrades`.
- Firewall setup with **UFW**:
  - SSH allowed (port 22)
  - HTTP allowed (port 80)
  - HTTPS allowed (port 443)
  - All other ports blocked
- **Fail2ban** installed and running to prevent brute-force attacks.
- Disables root SSH login for enhanced security.
- Installs essential utilities: `vim`, `htop`, `curl`, `wget`, and `software-properties-common`.

### 2. Docker & Git Setup
- Installs **Docker CE** and **Docker Compose plugin**.
- Ensures Docker service is running and enabled at boot.
- Adds your admin user (`sam`) to the Docker group for non-root Docker usage.
- Installs Git for code management and deployment.

### 3. HTTPS Support
- Installs **Nginx** for reverse proxying.
- Installs **Certbot** for Let’s Encrypt SSL certificate management.
- Nginx is running by default; certificates can be issued for your domain:
```bash
sudo certbot --nginx -d yourdomain.com
