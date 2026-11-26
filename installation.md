# Self-Hosted Git Server Using Gitea on Ubuntu Server

A step-by-step guide to building a private, self-hosted Git server using Gitea, Ubuntu Server, SQLite3, and OpenSSH.

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Prerequisites](#2-prerequisites)
3. [Create Ubuntu Server VM](#3-create-ubuntu-server-vm)
4. [Configure Network](#4-configure-network)
5. [Install OpenSSH and Git](#5-install-openssh-and-git)
6. [Configure SSH Key Authentication](#6-configure-ssh-key-authentication)
7. [Install Gitea](#7-install-gitea)
8. [Configure Gitea Systemd Service](#8-configure-gitea-systemd-service)
9. [Initial Gitea Configuration](#9-initial-gitea-configuration)
10. [Configure Gitea SSH Keys](#10-configure-gitea-ssh-keys)
11. [Create and Push a Repository](#11-create-and-push-a-repository)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Project Overview

This project demonstrates how to build and configure a self-hosted Git server using Gitea.

Gitea is a lightweight, open-source Git hosting platform that provides a web interface for managing Git repositories, users, SSH keys, and other repository-related activities.

Instead of depending on GitHub's hosting infrastructure, this implementation hosts Git repositories on a privately managed Ubuntu Server.

### Architecture

- **Virtualization:** Oracle VM VirtualBox
- **Operating System:** Ubuntu Server (64-bit)
- **Git Platform:** Gitea v1.23.4
- **Database:** SQLite3
- **Version Control:** Git
- **Remote Access:** OpenSSH
- **Authentication:** Ed25519 SSH key-based authentication
- **Service Management:** systemd

### Workflow

Client Machine 1 / Client Machine 2  
↓  
SSH Key-Based Authentication  
↓  
Ubuntu Server  
↓  
Gitea  
↓  
SQLite3 Database  
↓  
Git Repository Storage

---

## 2. Prerequisites

### Hardware Requirements

- A computer capable of running Oracle VM VirtualBox.
- Sufficient RAM and disk space for an Ubuntu Server virtual machine.
- A local network connection.

### Software Requirements

- Oracle VM VirtualBox.
- Ubuntu Server ISO (64-bit x86_64).
- Git.
- OpenSSH.
- Gitea v1.23.4.

### Network Requirements

The server and client machines must have network connectivity.

The server's IP address will be used to access the Gitea web interface and Git repositories.

---

## 3. Create Ubuntu Server VM

1. Open Oracle VM VirtualBox.
2. Create a new virtual machine.
3. Select the Ubuntu Server ISO file.
4. Choose the appropriate Linux 64-bit architecture.
5. Allocate suitable RAM, CPU cores, and virtual disk space.
6. Complete the Ubuntu Server installation.
7. Boot into Ubuntu and log in.

Verify the architecture:

```bash
uname -m
```

Expected output:

```text
x86_64
```

---

## 4. Configure Network

The Ubuntu Server VM needs network connectivity with the client machines.

### 4.1 Configure VirtualBox Network Adapter

Open:

VirtualBox → VM Settings → Network

Choose the appropriate network mode:

- **Bridged Adapter:** Use when the server needs to be accessible by other physical machines on the same LAN.
- **NAT:** Suitable for certain host-to-VM or VM-to-VM setups. Port forwarding may be required for access from other physical machines.

### 4.2 Find the Server IP Address

Run:

```bash
hostname -I
```

Alternatively:

```bash
ip -4 addr show
```

Identify the active IPv4 address.

For example:

```text
192.168.1.100
```

In this guide, replace `<UBUNTU_IP>` with your actual server IP address.

---

## 5. Install OpenSSH and Git

Update the Ubuntu package repository:

```bash
sudo apt update
```

Install OpenSSH Server, Git, and wget:

```bash
sudo apt install -y openssh-server git wget
```

Enable and start the SSH service:

```bash
sudo systemctl enable --now ssh
```

Verify the service:

```bash
sudo systemctl status ssh
```

### Configure Firewall

If UFW is enabled, allow SSH and Gitea's web interface:

```bash
sudo ufw allow ssh
sudo ufw allow 3000/tcp
```

Gitea uses port 3000 by default for its web interface in this setup.

---

## 6. Configure SSH Key Authentication

SSH key-based authentication allows clients to authenticate without entering their Ubuntu account password every time.

Repeat these steps on both client machines.

### 6.1 Generate an Ed25519 SSH Key

On Client Machine 1:

```bash
ssh-keygen -t ed25519 -C "client-machine-1"
```

On Client Machine 2:

```bash
ssh-keygen -t ed25519 -C "client-machine-2"
```

Press Enter to accept the default key location:

```text
~/.ssh/id_ed25519
```

A public key and a private key will be generated.

- `id_ed25519`: Private key. Keep it secure.
- `id_ed25519.pub`: Public key. This can be shared with the server.

### 6.2 Copy the Public Key to Ubuntu Server

On Linux or macOS clients:

```bash
ssh-copy-id <ubuntu_user>@<UBUNTU_IP>
```

On Windows PowerShell:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh <ubuntu_user>@<UBUNTU_IP> "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

### 6.3 Verify SSH Authentication

Connect to the server:

```bash
ssh <ubuntu_user>@<UBUNTU_IP>
```

If configured correctly, you should be able to connect using your SSH key.

Note: This step configures SSH access to the Ubuntu operating system account. Registering keys with Gitea for Git repository operations is covered later.

---

## 7. Install Gitea

This project uses Gitea v1.23.4 for Linux AMD64.

### 7.1 Download Gitea Binary

Download the binary:

```bash
wget -O gitea https://dl.gitea.com/gitea/1.23.4/gitea-1.23.4-linux-amd64
```

Make it executable:

```bash
chmod +x gitea
```

Move it to the system binary directory:

```bash
sudo mv gitea /usr/local/bin/gitea
```

### 7.2 Create a Dedicated Git System User

Create a dedicated system user for running Gitea:

```bash
sudo adduser --system --group --disabled-password --shell /bin/bash --home /home/git git
```

### 7.3 Create Gitea Directories

```bash
sudo mkdir -p /var/lib/gitea/{custom,data,log} /etc/gitea
```

Assign ownership to the Gitea user:

```bash
sudo chown -R git:git /var/lib/gitea /etc/gitea
```

The directories are used for application data, custom files, logs, and configuration.

---

## 8. Configure Gitea Systemd Service

Create a systemd service file:

```bash
sudo nano /etc/systemd/system/gitea.service
```

Add the following configuration:

```ini
[Unit]
Description=Gitea (Git with a cup of tea)
After=syslog.target
After=network.target

[Service]
RestartSec=2s
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea

[Install]
WantedBy=multi-user.target
```

Save and exit.

### 8.1 Enable and Start Gitea

Reload systemd:

```bash
sudo systemctl daemon-reload
```

Enable and start Gitea:

```bash
sudo systemctl enable --now gitea
```

Check the service status:

```bash
sudo systemctl status gitea
```

Expected status:

```text
Active: active (running)
```

---

## 9. Initial Gitea Configuration

### 9.1 Open the Web Interface

Open a browser on a client machine and navigate to:

```text
http://<UBUNTU_IP>:3000
```

### 9.2 Configure Database

Select:

- Database Type: SQLite3

SQLite3 is used as the embedded database, avoiding the need to configure a separate database server.

### 9.3 Configure Server Settings

Update the following fields:

- Server Domain: `<UBUNTU_IP>`
- Gitea Base URL: `http://<UBUNTU_IP>:3000/`

These settings help Gitea generate repository URLs that are accessible across your network.

### 9.4 Create Administrator Account

Expand the Administrator Account Settings section.

Enter:

- Administrator Username
- Administrator Password
- Email Address

Click **Install Gitea**.

### 9.5 Secure Configuration Permissions

After installation, execute:

```bash
sudo chmod 750 /etc/gitea
sudo chmod 640 /etc/gitea/app.ini
```

These commands restrict access to the Gitea configuration directory and file.

---

## 10. Configure Gitea SSH Keys

The SSH keys used for Git operations must also be registered in Gitea.

On each client machine, display the public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

On Windows PowerShell:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub
```

Copy the public key.

In Gitea:

1. Log in to your Gitea account.
2. Open Settings.
3. Navigate to SSH / GPG Keys.
4. Select Add Key.
5. Enter a descriptive title.
6. Paste the public key.
7. Save the key.

Repeat for both client machines.

Never upload or share your private key (`id_ed25519`).

---

## 11. Create and Push a Repository

### 11.1 Create a Repository in Gitea

1. Log in to Gitea.
2. Click the + icon.
3. Select New Repository.
4. Enter a repository name.
5. Select the visibility (Private or Public).
6. Create the repository.

For this example, the repository name is `test`.

### 11.2 Create a Local Project Directory

On the client machine:

```bash
mkdir test-gitea
cd test-gitea
```

Initialize Git:

```bash
git init
```

### 11.3 Create a README File

```bash
nano README.md
```

Add project information and save the file.

### 11.4 Stage and Commit Changes

```bash
git add .
```

Create the initial commit:

```bash
git commit -m "Initial commit"
```

### 11.5 Configure the Remote Repository

```bash
git remote add origin git@<UBUNTU_IP>:<gitea_username>/test.git
```

Verify the remote:

```bash
git remote -v
```

### 11.6 Set the Main Branch

```bash
git branch -M main
```

### 11.7 Push to Gitea

```bash
git push -u origin main
```

If the SSH keys and repository permissions are configured correctly, Git should successfully push the local repository to your Gitea server.

### 11.8 Verify

Open the repository in the Gitea web interface.

Confirm that:

- The README file appears.
- The latest commit is visible.
- The repository contains the expected files.

---

## 12. Troubleshooting

### 12.1 Administrator Account Was Not Created During Installation

If Gitea was installed without creating an administrator account, use the built-in Gitea CLI.

First, list existing users:

```bash
sudo -u git /usr/local/bin/gitea --config /etc/gitea/app.ini admin user list
```

Create an administrator account:

```bash
sudo -u git /usr/local/bin/gitea --config /etc/gitea/app.ini admin user create \
  --username <username> \
  --password '<password>' \
  --email <email> \
  --admin
```

Use a strong password and avoid sharing this command with a real password in screenshots or public documentation.

Verify the account:

```bash
sudo -u git /usr/local/bin/gitea --config /etc/gitea/app.ini admin user list
```

Check that `IsAdmin` is `true`.

### 12.2 Ubuntu Server IP Address Changed

If the server IP changes after restarting the virtual machine, find the current IP:

```bash
hostname -I
```

Open Gitea using the new address:

```text
http://<NEW_UBUNTU_IP>:3000
```

If the configured Gitea Base URL is outdated, back up the configuration:

```bash
sudo cp /etc/gitea/app.ini /etc/gitea/app.ini.backup
```

Edit the configuration:

```bash
sudo nano /etc/gitea/app.ini
```

Update the relevant values under `[server]`:

```ini
DOMAIN = <NEW_UBUNTU_IP>
ROOT_URL = http://<NEW_UBUNTU_IP>:3000/
SSH_DOMAIN = <NEW_UBUNTU_IP>
```

Preserve other existing configuration settings.

Restart Gitea:

```bash
sudo systemctl restart gitea
```

For a long-term solution, configure a static IP or DHCP reservation.

### 12.3 Git Error: src refspec main does not match any

Example:

```text
error: src refspec main does not match any
```

This can happen when the local repository has no commits or the requested branch does not exist.

Check the repository:

```bash
git status
git branch
```

If you have not committed any files:

```bash
git add .
git commit -m "Initial commit"
```

Rename the branch:

```bash
git branch -M main
```

Push again:

```bash
git push -u origin main
```

---

## Conclusion

This project demonstrates the deployment of a self-hosted Git platform using Gitea on Ubuntu Server.

Through this implementation, I gained practical experience with:

- Linux server administration.
- Virtual machine configuration.
- Git repository management.
- SSH key-based authentication.
- Gitea installation and configuration.
- SQLite3 database integration.
- systemd service management.
- Local network connectivity and troubleshooting.

The project provided practical exposure to hosting and managing version control infrastructure independently of third-party Git hosting services.

**Project:** Self-Hosted Git Server Using Gitea  
**Platform:** Oracle VM VirtualBox  
**Operating System:** Ubuntu Server  
**Git Platform:** Gitea v1.23.4
