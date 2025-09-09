# Ansible VPS — README

This repository contains a small Ansible playbook and roles to bootstrap a fresh Ubuntu VPS for running containerized web applications (example: MedusaJS). It performs basic system hardening, installs Docker and supporting tools, and provides a simple webhook service skeleton for automated deploys.

This README documents what the repo does, assumptions, how to run it, and important notes and troubleshooting tips.

---

## Supported target OS
 - Ubuntu (tested on Ubuntu LTS). The tasks use Ubuntu-specific package repositories (Docker) and packages. Other Debian-derived distributions may work but are not guaranteed.

## Quick summary of what the playbook does
 - System updates and security tooling (ufw, fail2ban, unattended-upgrades).
 - Installs Docker Engine and the Docker Compose plugin.
 - Installs and enables Nginx + Certbot (for TLS) and an optional Cloudflare DNS plugin.
 - Installs a small webhook listener (systemd unit + /etc/webhook/hooks.json) to trigger deploy scripts.

## Prerequisites and assumptions
 - You have SSH access to the VPS and can run commands with sudo.
 - The repository is intended to be executed on the target host (see examples below using `ansible-pull` or running from a control machine with `ansible-playbook`).
 - The playbook currently hardcodes a few items (notably the example user `sam` in some files). Review and change those values before running in production.

## Inventory / hosts
 - By default `playbook.yml` targets `localhost` and expects to run on the VPS itself (good for `ansible-pull`). If you want to run from a control host, change `hosts` and ensure SSH connectivity and privilege escalation is configured.

## How to run (two common ways)

1) Run locally on the VPS using ansible-pull (recommended for simple setups)

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ansible git
ansible-pull -U https://github.com/SAM-AEL/ansible-vps.git playbook.yml -i localhost
```

2) Run from a control machine using ansible-playbook

 - Ensure you have an inventory that points to the VPS and that Ansible can connect as a user with sudo privileges.

```bash
# from a control machine
ansible-playbook -i inventory playbook.yml --ask-become-pass
```

## Roles and purpose
 - `roles/security` — package updates, UFW, fail2ban, unattended-upgrades, and SSH hardening.
 - `roles/server` — installs Nginx, Certbot, and related packages.
 - `roles/docker` — installs Docker Engine, Docker Compose plugin, and configures Docker service.
 - `roles/webhook` — installs `webhook`, writes a hooks.json, and registers a systemd service that runs the listener.

## Important issues found in the current role implementations (actionable)
1. Hardcoded user `sam`
   - Several files (example: `roles/webhook/tasks/main.yml` systemd unit uses `User=sam`, `roles/docker` adds `ansible_env.USER` which may be `root`) use a hardcoded username or depend on `ansible_env.USER`. This is brittle. Use an explicit variable (eg. `vps_admin_user`) with a default and document it.

2. UFW default policy not set
   - The role allows SSH/HTTP/HTTPS and enables UFW but does not explicitly set `ufw default deny incoming` and `ufw default allow outgoing`. This can leave unexpected ports open. Recommendation: set defaults before enabling.

3. SSH PermitRootLogin replacement may not match commented option
   - The `lineinfile` uses `regexp: '^PermitRootLogin'` which won't match a commented line like `#PermitRootLogin prohibit-password`. Use a more tolerant regexp such as `'^#?\s*PermitRootLogin'`.

4. Docker hello-world test is not idempotent
   - The `command: docker run hello-world` will run on every playbook execution (and may download images). Prefer using `community.docker.docker_image` or guard the command with a `creates:` file or `when` condition.

5. Distribution assumptions
   - The Docker repository uses `download.docker.com/linux/ubuntu` and `{{ ansible_lsb.codename }}` — this assumes Ubuntu and that `ansible_facts` are available. Running with `gather_facts: no` or on non-Ubuntu hosts will fail. Document this and/or add checks.

6. Certbot DNS plugin requires credentials
   - `python3-certbot-dns-cloudflare` is installed but requires an API token/credentials file and config. Document how to supply those secrets securely.

7. Webhook deploy script assumptions
   - `roles/webhook/tasks/main.yml` writes a `hooks.json` that executes `/home/sam/app/deploy.sh`. Ensure that the script exists and is executable and that the working directory and user are correct.

8. Service names vary by distro
   - The handler restarts `ssh` service. On some distros the daemon is `sshd`. Consider using both or document target OS.

## Suggested quick fixes (I can apply them if you want)
 - Replace strict `PermitRootLogin` regexp with a tolerant one.
 - Use a variable `vps_admin_user` (default `sam`) and update webhook systemd unit and docker user addition to use that variable.
 - Set explicit UFW defaults: deny incoming / allow outgoing before enabling.
 - Make Docker hello-world check conditional or use the `community.docker` collection to check images.

## Security notes
 - Do not store API keys, certbot/cloudflare credentials, or other secrets in plaintext in this repo. Use Ansible Vault or an external secret manager.
 - Review `hooks.json` and deploy scripts carefully: running remote commands as root can be dangerous.

## Variables and how they are loaded

This repository now centralizes configuration in `group_vars/all.yml`. That file loads values from environment variables when available, so you can control behavior by editing the repository `.env` (and sourcing it) or by exporting environment variables before running the playbook.

Key variables
 - `vps_admin_user` — username to add to the `docker` group and the user used by the webhook service. Default is read from `VPS_ADMIN_USER` env or `sam`.
 - `vps_domain` — domain for Certbot (from `DOMAIN` env).
 - `vps_email` — email used for Let's Encrypt registration (from `EMAIL` env).
 - `webhook_port` / `webhook_user` — webhook listener port and user (from `WEBHOOK_PORT` / `WEBHOOK_USER`).
 - `ufw_allow_ports` — comma-separated list of ports allowed by UFW (from `UFW_ALLOW_PORTS`).

What I changed in the code
 - Added `group_vars/all.yml` to centralize variables and load from environment variables.
 - Replaced hardcoded `sam`/`ansible_env.USER` usage with `vps_admin_user`/`webhook_user` variables.
 - UFW now explicitly sets default policies (deny incoming / allow outgoing) before enabling.
 - The SSH `PermitRootLogin` replacement uses a tolerant regexp and the SSH handler attempts to restart both `ssh` and `sshd` service names for compatibility.
 - Docker hello-world test is now idempotent: it runs only if the image is not present.
 - Webhook systemd unit now uses `{{ webhook_port }}` and `{{ webhook_user }}` and hooks.json uses the `vps_admin_user` home path.

How to override variables
 - Edit the `.env` file in the repository root and set values (already added). The `group_vars/all.yml` file reads these env vars when present.
 - Alternatively, for Ansible-native overrides, add `group_vars/all.yml` entries or a `vars/main.yml` in a role.

Security reminder
 - Avoid putting secrets in `.env`. Use Ansible Vault for API tokens (Cloudflare) and other sensitive data.

## Troubleshooting
 - If the Docker apt repository fails: verify `lsb_release -cs` on the target matches `ansible_lsb.codename` and that the OS is Ubuntu.
 - If UFW blocks you: ensure `Allow OpenSSH` runs before enabling UFW. When testing, keep an open separate root session so you can recover.
 - If certbot fails to obtain a certificate: check DNS records, ports 80/443 reachable, and Cloudflare API keys if using the DNS plugin.

## Next steps I can take (pick any)
 - Apply the non-breaking fixes listed above automatically (update the regexp for PermitRootLogin, add UFW default rules, convert `sam` to `vps_admin_user` variable in roles) — low risk.
 - Add a small `vars/defaults/main.yml` to document/centralize `vps_admin_user` and other settings.
 - Implement idempotent Docker check.

If you want, I can apply the safe fixes now and run quick checks. Tell me which you want me to apply, or say `apply all recommended fixes` and I'll proceed.

### Using a root .env to configure the playbook

You can set runtime values in the repository root by editing the `.env` file. A template `.env` has been added to the repository; it contains common values you may want to change such as `VPS_ADMIN_USER`, `DOMAIN`, `EMAIL`, and `WEBHOOK_PORT`.

Best practices
 - Do NOT store secrets (API tokens, private keys) directly in `.env` for production; instead use Ansible Vault or an external secret manager.
 - For one-off testing, copy `.env` to a file like `.env.local` and edit it, then source it or use the helper script below.

Helper script
 - `run-ansible.sh` is included to load `.env` and run the playbook. Make it executable and run it from the repo root:

```bash
chmod +x run-ansible.sh
./run-ansible.sh
```

This script prefers `ansible-pull` (recommended when running on the VPS itself). If `ansible-pull` is not available it will fall back to `ansible-playbook`.

## License / attribution
 - This repo is a personal project. If you copy or reuse parts, follow standard licensing practices and do not include secrets.

---

## Completion status
 - I inspected the playbook and role tasks and collected a list of issues and improvements above. I can implement the low-risk fixes on request.

