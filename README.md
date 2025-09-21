Raspberry Pi Headless Development Environment

A comprehensive setup for turning a headless Raspberry Pi into a powerful SSH-accessible development environment with efficient GitHub repository management, programming language support, and minimal storage/memory usage.
📋 Prerequisites

These scripts have been tested with a RaspberryPi 3

Before using these scripts, you need to set up your Raspberry Pi with a headless OS:
Step 1: Download Raspberry Pi Imager

Downlaod from [raspberrypi.com/software/operating-systems/](https://www.raspberrypi.com/software/operating-systems/)

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
Install Git then Download the setup scripts

sudo apt-get install git

git clone https://github.com/RetroMaximus/devenv.git
cd devenv
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

    Install programming languages (optional)


🛠 Supported Programming Languages

The environment supports installation of:

    Python (pyenv, pip, pipx)

    Node.js (nvm, npm, yarn)

    Go (latest version)

    Rust (rustup, cargo)

    Java (OpenJDK)

    Ruby (rbenv, gem)

    PHP (with Composer)

    C/C++ (build-essential, gcc, g++)

    .NET (dotnet SDK)

🔧 Configuration

After running the quick setup, you can customize your environment:

```bash
Access the main configuration menu

dev
Or use specific managers

projects # Manage your projects
config-dev # Configure environment settings
lang-setup # Install programming languages
```
📂 Directory Structure

The scripts create this organized structure:

```

~/ projects/
├── active/ # Currently working projects
├── archived/ # Completed or inactive projects
└── languages/ # Project-language configuration files
~/development/
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
1. Install required languages

lang-setup
Choose languages needed for your projects
2. Start a new project

projects
Choose option to clone a repository
3. Configure project languages

projects
Choose option to set up languages for specific project
4. Work on your project

projects
Choose option to open a project
5. When done, archive it

projects
Choose option to archive a project

```

💾 Storage Management

```
For limited storage Raspberry Pi models, these strategies help:

    Selective language installation: Only install languages you actually use

    Clone selectively: Only clone repos you're actively working on

    Archive projects: Move inactive projects to archived section

    Clean regularly: Use the temp directory for short-term files

    Use .git shallow clones: ```git clone --depth 1``` for large repos

    Remove unused languages: Use the language manager to clean up
```
🔒 Security Notes
```
    Change the default SSH password immediately

    Use SSH keys instead of password authentication

    Keep your system updated regularly

    Consider setting up a firewall (ufw)

    Be cautious with language packages from third-party repositories
```
🤝 Contributing

Feel free to submit issues and enhancement requests!
📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
🆘 Troubleshooting

Common issues:

    SSH connection refused: Check if SSH is enabled and Pi is on network

    Script permission denied: Run ```chmod +x *.sh```

    Git clone fails: Check internet connection and repository URL

    Language installation fails: Check available memory and storage space

    Compilation errors: Some languages may need additional dependencies

Memory considerations:

    Raspberry Pi models with less than 2GB RAM may struggle with some language compilations

    Use swap space for memory-intensive operations

    Consider installing pre-compiled binaries when available

Need help?

    Check Raspberry Pi documentation

    Search existing GitHub issues

    Create a new issue with details about your problem

Note: This setup is designed for Raspberry Pi OS Lite (64-bit) but should work on other Debian-based distributions with minimal adjustments. Language availability may vary based on architecture.








