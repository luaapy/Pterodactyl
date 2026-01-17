# Pterodactyl Zero-Touch Deployment for GitHub Codespaces

This repository contains a fully automated, production-grade deployment suite for Pterodactyl Panel and Wings, specifically optimized for GitHub Codespaces.

## 🚀 Quick Start

1.  Open this repository in a GitHub Codespace.
2.  Run the installation script:
    ```bash
    bash install.sh
    ```
3.  Wait for the script to finish (~90 seconds).
4.  Access the Panel via the URL provided in the output.

## ✨ Features

*   **Zero-Touch:** Single command installation. No manual configuration needed.
*   **Auto-Configuration:**
    *   Creates Admin User (`admin@panel.com` / `Password123` - **Change this immediately!**)
    *   Creates "Local" Location.
    *   Creates "Codespace-Node" fully connected via internal Docker network.
    *   Allocates ports 25565-25570.
*   **Keep-Alive:** Includes a background service to prevent Codespace hibernation while the tab is open (or being pinged).
*   **Codespace Optimized:** Handles dynamic URLs, HTTPS proxying, and port forwarding.

## 📂 Architecture

*   **Panel:** `ghcr.io/pterodactyl/panel:latest` (Port 80/443)
*   **Wings:** `ghcr.io/pterodactyl/wings:latest` (Port 8080/2022)
*   **Database:** `mariadb:10.11`
*   **Cache:** `redis:alpine`
*   **Network:** `ptero_net` (172.20.0.0/16)

## 🛠 Troubleshooting

*   **Logs:** Check `./logs/` directory.
*   **Service Status:** `docker-compose ps`
*   **Restart Services:** `docker-compose restart`
*   **Full Reset:**
    ```bash
    docker-compose down -v
    rm -rf lib/wings/* .env
    ```

## ⚠️ Security Note

The default admin password is set in `.env` (derived from `.env.example`).
**Please change your password and the `.env` file immediately after installation if you plan to keep this environment long-term.**

## 📝 License

MIT
