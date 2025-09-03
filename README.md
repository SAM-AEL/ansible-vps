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
```

## Setup
1. Install Ansible on VPS  
   SSH into your fresh VPS (as `sam`) and run:

    ```bash
    sudo apt update && sudo apt upgrade -y
    sudo apt install ansible git -y
    ```

2. Run Ansible-pull  
   Pull and apply this repo directly on your VPS:

    ```bash
    ansible-pull -U git@github.com:YOUR_USERNAME/ansible-medusa.git playbook.yml -i localhost
    ```

    - `-U` → your GitHub repo URL  
    - `-i localhost` → run locally on the VPS

    This will automatically:
    1. Harden your system  
    2. Install Docker, Docker Compose, and Git  
    3. Install Nginx and Certbot

3. Deploy MedusaJS  
   1. Create a folder for your MedusaJS app, e.g. `/home/sam/app`.  
   2. Add your `docker-compose.yml` for MedusaJS.  
   3. Run your app:

        ```bash
        cd /home/sam/app
        docker-compose up -d --build
        ```

   4. Optionally, set up:  
       - **GitHub webhook** to automatically pull the latest commit and rebuild Docker container.  
       - **Cron job** alternative (checks every 5 minutes):

            ```bash
            */5 * * * * cd /home/sam/app && git pull origin main && docker-compose down && docker-compose up -d --build >> /home/sam/app/log.txt 2>&1
            ```

