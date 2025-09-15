Raspberry Pi Headless Development Environment

A comprehensive setup for turning a headless Raspberry Pi into a powerful SSH-accessible development environment with efficient GitHub repository management and minimal storage/memory usage.
📋 Prerequisites

Before using these scripts, you need to set up your Raspberry Pi with a headless OS:
Step 1: Download Raspberry Pi Imager

    Download from raspberrypi.com/software

    Available for Windows, macOS, and Ubuntu

Step 2: Write OS to SD Card

    Insert your SD card into your computer

    Open Raspberry Pi Imager

    Click "Choose OS" and select:

        Raspberry Pi OS (other)

        Raspberry Pi OS Lite (64-bit) - No desktop environment

Step 3: Configure Headless Setup

    Click the gear icon (⚙) to open advanced options

    Enable SSH and set a password

    Configure Wi-Fi (if using wireless)

    Set locale settings (timezone, keyboard layout)

    Click "Save" then "Write" to burn the image

Step 4: Boot Your Raspberry Pi

    Insert the SD card into your Raspberry Pi

    Power on the device

    Find your Pi's IP address (check your router admin panel)

    Connect via SSH: ssh pi@[your-pi-ip]

🚀 Quick Start

Once you've SSH'd into your Raspberry Pi:
bash

# Download the setup scripts
git clone https://github.com/yourusername/pi-dev-env.git
cd pi-dev-env

# Make scripts executable
chmod +x *.sh

# Run the quick setup
./quick-setup.sh

The quick setup will:

    Update your system packages

    Install development tools (git, editors, etc.)

    Configure your development environment

    Set up helpful aliases

📁 Script Overview
setup-dev-env.sh

The main menu-driven script for setting up and managing your development environment.

Features:

    Package installation (Git, Neovim, Emacs, Nano, Tmux, etc.)

    Git configuration setup

    Development directory structure creation

    Editor configuration

    Project

Sorry i forgot to mention whereever ``` is needed use ``` I will replace them later this will allow me to copy and paste the md file correctly.
Raspberry Pi Headless Development Environment

A comprehensive setup for turning a headless Raspberry Pi into a powerful SSH-accessible development environment with efficient GitHub repository management and minimal storage/memory usage.
📋 Prerequisites

Before using these scripts, you need to set up your Raspberry Pi with a headless OS:
Step 1: Download Raspberry Pi Imager

    Download from ```raspberrypi.com/software```

    Available for Windows, macOS, and Ubuntu

Step 2: Write OS to SD Card

    Insert your SD card into your computer

    Open Raspberry Pi Imager

    Click "Choose OS" and select:

        Raspberry Pi OS (other)

        Raspberry Pi OS Lite (64-bit) - No desktop environment

Step 3: Configure Headless Setup

    Click the gear icon (⚙) to open advanced options

    Enable SSH and set a password

    Configure Wi-Fi (if using wireless)

    Set locale settings (timezone, keyboard layout)

    Click "Save" then "Write" to burn the image

Step 4: Boot Your Raspberry Pi

    Insert the SD card into your Raspberry Pi

    Power on the device

    Find your Pi's IP address (check your router admin panel)

    Connect via SSH: ```ssh pi@[your-pi-ip]```

🚀 Quick Start

Once you've SSH'd into your Raspberry Pi:

```bash
Download the setup scripts

git clone https://github.com/yourusername/pi-dev-env.git
cd pi-dev-env
Make scripts executable

chmod +x *.sh
Run the quick setup

./quick-setup.sh
```

The quick setup will:

    Update your system packages

    Install development tools (git, editors, etc.)

    Configure your development environment

    Set up helpful aliases

📁 Script Overview
setup-dev-env.sh

The main menu-driven script for setting up and managing your development environment.

Features:

    Package installation (Git, Neovim, Emacs, Nano, Tmux, etc.)

    Git configuration setup

    Development directory structure creation

    Editor configuration

    Project management interface

project-manager.sh

Handles GitHub repository cloning and project organization.

Features:

    Clone repositories from GitHub

    Organize projects into active/archived categories

    Quick navigation between projects

    Project archiving and restoration

config-manager.sh

Manages environment configuration and settings.

Features:

    View current configuration

    Change editor preference (Neovim, Emacs, or Nano)

    Modify development directory location

    Edit configuration files directly

quick-setup.sh

Automates the initial setup process for a new environment.
🔧 Configuration

After running the quick setup, you can customize your environment:

```bash
Access the main configuration menu

dev
Or use specific managers

projects # Manage your projects
config-dev # Configure environment settings
```
📂 Directory Structure

The scripts create this organized structure:

```
~/development/
├── projects/
│ ├── active/ # Currently working projects
│ └── archived/ # Completed or inactive projects
├── temp/ # Temporary files
├── backups/ # Project backups
├── scripts/ # Your custom scripts
└── configs/ # Environment configurations
```
🛠 Supported Editors

Choose your preferred code editor:

    Neovim - Modern Vim with Lua support

    Emacs - Extensible, customizable editor

    Nano - Simple, easy-to-use terminal editor

🔄 Workflow Example

```bash
1. Start a new project

projects
Choose option 6 to clone a repository
2. Work on your project

projects
Choose option 8 to open a project
3. When done, archive it

projects
Choose option to archive a project

```
💾 Storage Management

For limited storage Raspberry Pi models, these strategies help:

    Clone selectively: Only clone repos you're actively working on

    Archive projects: Move inactive projects to archived section

    Clean regularly: Use the temp directory for short-term files

    Use .git shallow clones: ```git clone --depth 1``` for large repos

🔒 Security Notes

    Change the default SSH password immediately

    Use SSH keys instead of password authentication

    Keep your system updated regularly

    Consider setting up a firewall (ufw)

🤝 Contributing

Feel free to submit issues and enhancement requests!
📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
🆘 Troubleshooting

Common issues:

    SSH connection refused: Check if SSH is enabled and Pi is on network

    Script permission denied: Run ```chmod +x *.sh```

    Git clone fails: Check internet connection and repository URL

Need help?

    Check Raspberry Pi documentation

    Search existing GitHub issues

    Create a new issue with details about your problem

Note: This setup is designed for Raspberry Pi OS Lite (64-bit) but should work on other Debian-based distributions with minimal adjustments.
