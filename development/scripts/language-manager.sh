#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration
source ~/.dev-env-config

# Install Python environment
install_python() {
    echo -e "${BLUE}Installing Python environment...${NC}"
    
    # Install system Python
    sudo apt install -y python3 python3-pip python3-venv python3-dev
    
    # Install pipx for isolated tools
    python3 -m pip install --user pipx
    python3 -m pipx ensurepath
    
    # Install pyenv for Python version management
    curl https://pyenv.run | bash
    
    # Add pyenv to shell
    echo 'export PYENV_ROOT="$HOME/.pyenv"' > ~/.bashrc
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' > ~/.bashrc
    echo 'eval "$(pyenv init -)"' > ~/.bashrc
    
    echo -e "${GREEN}Python environment installed!${NC}"
    echo "Run 'source ~/.bashrc' to start using pyenv"
}

# Install Node.js environment
install_nodejs() {
    echo -e "${BLUE}Installing Node.js environment...${NC}"
    
    # Install NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
    
    # Install nvm for Node version management
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    
    # Load nvm immediately
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Install yarn
    npm install -g yarn
    
    echo -e "${GREEN}Node.js environment installed!${NC}"
}

# Install Go language
install_go() {
    echo -e "${BLUE}Installing Go language...${NC}"
    
    # Download and install Go
    GO_VERSION="1.21.0"
    ARCH="arm64"
    
    wget "https://golang.org/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz"
    sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-${ARCH}.tar.gz"
    rm "go${GO_VERSION}.linux-${ARCH}.tar.gz"
    
    # Add Go to PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' > ~/.bashrc
    echo 'export GOPATH=$HOME/go' > ~/.bashrc
    echo 'export PATH=$PATH:$GOPATH/bin' > ~/.bashrc
    
    echo -e "${GREEN}Go language installed!${NC}"
}

# Install Rust language
install_rust() {
    echo -e "${BLUE}Installing Rust language...${NC}"
    
    # Install rustup
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    
    # Add to PATH
    source "$HOME/.cargo/env"
    
    echo -e "${GREEN}Rust language installed!${NC}"
}

# Install Java environment
install_java() {
    echo -e "${BLUE}Installing Java environment...${NC}"
    
    # Install OpenJDK
    sudo apt install -y openjdk-17-jdk maven gradle
    
    echo -e "${GREEN}Java environment installed!${NC}"
}

# Install Ruby environment
install_ruby() {
    echo -e "${BLUE}Installing Ruby environment...${NC}"
    
    # Install system Ruby
    sudo apt install -y ruby ruby-dev
    
    # Install rbenv for Ruby version management
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    
    # Add rbenv to PATH
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    
    echo -e "${GREEN}Ruby environment installed!${NC}"
}

# Install PHP environment
install_php() {
    echo -e "${BLUE}Installing PHP environment...${NC}"
    
    # Install PHP and Composer
    sudo apt install -y php php-cli php-curl php-json php-mbstring php-xml php-zip
    
    # Install Composer
    curl -sS https://getcomposer.org/installer | php
    sudo mv composer.phar /usr/local/bin/composer
    sudo chmod +x /usr/local/bin/composer
    
    echo -e "${GREEN}PHP environment installed!${NC}"
}

# Install C/C++ tools
install_c_cpp() {
    echo -e "${BLUE}Installing C/C++ development tools...${NC}"
    
    # Already installed build-essential in main setup
    sudo apt install -y gdb cmake clang lldb
    
    echo -e "${GREEN}C/C++ tools installed!${NC}"
}

# Install .NET SDK
install_dotnet() {
    echo -e "${BLUE}Installing .NET SDK...${NC}"
    
    # Install .NET SDK
    wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
    chmod +x dotnet-install.sh
    ./dotnet-install.sh --channel LTS
    rm dotnet-install.sh
    
    # Add to PATH
    echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc
    echo 'export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools' >> ~/.bashrc
    
    echo -e "${GREEN}.NET SDK installed!${NC}"
}

# Show installed languages
show_installed_languages() {
    echo -e "${YELLOW}=== Installed Languages ===${NC}"
    
    # Check Python
    if command -v python3 &> /dev/null; then
        echo -e "Python: $(python3 --version | cut -d' ' -f2)"
    else
        echo -e "Python: ${RED}Not installed${NC}"
    fi
    
    # Check Node.js
    if command -v node &> /dev/null; then
        echo -e "Node.js: $(node --version)"
    else
        echo -e "Node.js: ${RED}Not installed${NC}"
    fi
    
    # Check Go
    if command -v go &> /dev/null; then
        echo -e "Go: $(go version | cut -d' ' -f3)"
    else
        echo -e "Go: ${RED}Not installed${NC}"
    fi
    
    # Check Java
    if command -v java &> /dev/null; then
        echo -e "Java: $(java -version 2>&1 | head -n1 | cut -d'"' -f2)"
    else
        echo -e "Java: ${RED}Not installed${NC}"
    fi
    
    echo -e "${YELLOW}===========================${NC}"
}

# Configure languages for specific project
configure_project_languages() {
    echo -e "${BLUE}Configuring languages for specific project...${NC}"
    
    # List projects
    if [ -d "$USER_HOME/projects/active" ]; then
        echo -e "${YELLOW}Available projects:${NC}"
        ls "$USER_HOME/projects/active"
    else
        echo -e "${RED}No projects found!${NC}"
        return
    fi
    
    read -p "Enter project name: " project_name
    project_dir="$USER_HOME/projects/active/$project_name"
    lang_file="$USER_HOME/projects/languages/${project_name}.lang"
    
    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}Project '$project_name' not found!${NC}"
        return
    fi
    
    echo -e "${YELLOW}Select languages used in this project:${NC}"
    echo "1. Python"
    echo "2. Node.js"
    echo "3. Go"
    echo "4. Rust"
    echo "5. Java"
    echo "6. Ruby"
    echo "7. PHP"
    echo "8. C/C++"
    echo "9. .NET"
    echo "10. Done"
    
    selected_languages=()
    while true; do
        read -p "Choose language (1-10): " lang_choice
        case $lang_choice in
            1) selected_languages+=("python") ;;
            2) selected_languages+=("nodejs") ;;
            3) selected_languages+=("go") ;;
            4) selected_languages+=("rust") ;;
            5) selected_languages+=("java") ;;
            6) selected_languages+=("ruby") ;;
            7) selected_languages+=("php") ;;
            8) selected_languages+=("c_cpp") ;;
            9) selected_languages+=("dotnet") ;;
            10) break ;;
            *) echo -e "${RED}Invalid choice!${NC}" ;;
        esac
    done
    
    # Save language configuration
    printf "%s\n" "${selected_languages[@]}" > "$lang_file"
    echo -e "${GREEN}Language configuration saved for project '$project_name'!${NC}"
}

# Main menu
show_menu() {
    while true; do
        echo -e "\n${YELLOW}=== Programming Language Setup ===${NC}"
        echo -e "1. Install Python environment"
        echo -e "2. Install Node.js environment"
        echo -e "3. Install Go language"
        echo -e "4. Install Rust language"
        echo -e "5. Install Java environment"
        echo -e "6. Install Ruby environment"
        echo -e "7. Install PHP environment"
        echo -e "8. Install C/C++ tools"
        echo -e "9. Install .NET SDK"
        echo -e "10. Install all languages (not recommended on Pi)"
        echo -e "11. Configure languages for specific project"
        echo -e "12. Show installed languages"
        echo -e "13. Back to main menu"
        echo -e "${YELLOW}====================================${NC}"
        
        read -p "Choose an option (1-13): " choice
        
        case $choice in
            1) install_python ;;
            2) install_nodejs ;;
            3) install_go ;;
            4) install_rust ;;
            5) install_java ;;
            6) install_ruby ;;
            7) install_php ;;
            8) install_c_cpp ;;
            9) install_dotnet ;;
            10) install_all_languages ;;
            11) configure_project_languages ;;
            12) show_installed_languages ;;
            13) echo -e "${GREEN}Returning to main menu...${NC}"; break ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
    done
}

# Install all languages (with warning)
install_all_languages() {
    echo -e "${RED}Warning: Installing all languages may require significant storage and memory!${NC}"
    echo -e "${YELLOW}This is not recommended on Raspberry Pi with limited resources.${NC}"
    read -p "Are you sure you want to continue? (y/N): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${GREEN}Cancelled.${NC}"
        return
    fi
    
    install_python
    install_nodejs
    install_go
    install_rust
    install_java
    install_ruby
    install_php
    install_c_cpp
    install_dotnet
    
    echo -e "${GREEN}All languages installed!${NC}"
    echo -e "${YELLOW}Please run 'source ~/.bashrc' to apply all changes.${NC}"
}

# Main execution
show_menu
