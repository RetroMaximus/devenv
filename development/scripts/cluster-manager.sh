#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
else
    USER_HOME=$HOME
fi

# Cluster configuration
CLUSTER_CONFIG_DIR="$USER_HOME/.cluster"
CLUSTER_CONFIG_FILE="$CLUSTER_CONFIG_DIR/cluster.conf"
MASTER_CONFIG_FILE="$CLUSTER_CONFIG_DIR/master.conf"
NODES_CONFIG_FILE="$CLUSTER_CONFIG_DIR/nodes.conf"

# Load configuration
load_cluster_config() {
    mkdir -p "$CLUSTER_CONFIG_DIR"
    
    if [ ! -f "$CLUSTER_CONFIG_FILE" ]; then
        # Default cluster configuration
        echo "CLUSTER_NAME=pi-cluster" > "$CLUSTER_CONFIG_FILE"
        echo "CLUSTER_NETWORK=192.168.1.0/24" >> "$CLUSTER_CONFIG_FILE"
        echo "MEMORY_THRESHOLD=80" >> "$CLUSTER_CONFIG_FILE"  # Percentage
        echo "CPU_THRESHOLD=70" >> "$CLUSTER_CONFIG_FILE"     # Percentage
        echo "AUTO_DISTRIBUTE=true" >> "$CLUSTER_CONFIG_FILE"
        echo "CHECK_INTERVAL=300" >> "$CLUSTER_CONFIG_FILE"   # Seconds
    fi
    
    if [ ! -f "$MASTER_CONFIG_FILE" ]; then
        echo "MASTER_IP=192.168.1.1" > "$MASTER_CONFIG_FILE"
        echo "MASTER_USER=pi" >> "$MASTER_CONFIG_FILE"
        echo "MASTER_PORT=22" >> "$MASTER_CONFIG_FILE"
    fi
    
    if [ ! -f "$NODES_CONFIG_FILE" ]; then
        touch "$NODES_CONFIG_FILE"
    fi
    
    source "$CLUSTER_CONFIG_FILE"
    source "$MASTER_CONFIG_FILE"
}

# Save cluster configuration
save_cluster_config() {
    echo "CLUSTER_NAME=$CLUSTER_NAME" > "$CLUSTER_CONFIG_FILE"
    echo "CLUSTER_NETWORK=$CLUSTER_NETWORK" >> "$CLUSTER_CONFIG_FILE"
    echo "MEMORY_THRESHOLD=$MEMORY_THRESHOLD" >> "$CLUSTER_CONFIG_FILE"
    echo "CPU_THRESHOLD=$CPU_THRESHOLD" >> "$CLUSTER_CONFIG_FILE"
    echo "AUTO_DISTRIBUTE=$AUTO_DISTRIBUTE" >> "$CLUSTER_CONFIG_FILE"
    echo "CHECK_INTERVAL=$CHECK_INTERVAL" >> "$CLUSTER_CONFIG_FILE"
}

# Add a node to the cluster
add_node() {
    echo -e "${YELLOW}=== Add Node to Cluster ===${NC}"
    
    read -p "Node IP address: " node_ip
    read -p "SSH username (default: pi): " node_user
    node_user=${node_user:-pi}
    read -p "SSH port (default: 22): " node_port
    node_port=${node_port:-22}
    read -p "Node name/hostname: " node_name
    read -p "Node role (compute/storage/both): " node_role
    read -p "SSH key path (optional): " ssh_key
    
    # Test SSH connection
    echo -e "${BLUE}Testing SSH connection to $node_ip...${NC}"
    
    local ssh_cmd="ssh"
    if [ -n "$ssh_key" ]; then
        ssh_cmd+=" -i $ssh_key"
    fi
    ssh_cmd+=" -p $node_port $node_user@$node_ip 'hostname'"
    
    if eval "$ssh_cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}SSH connection successful!${NC}"
        
        # Add node to configuration
        echo "$node_ip:$node_port:$node_user:$node_name:$node_role:${ssh_key:-none}" >> "$NODES_CONFIG_FILE"
        echo -e "${GREEN}Node $node_name ($node_ip) added to cluster!${NC}"
    else
        echo -e "${RED}SSH connection failed! Check credentials and network.${NC}"
    fi
}

# Remove a node from the cluster
remove_node() {
    echo -e "${YELLOW}=== Remove Node from Cluster ===${NC}"
    list_nodes
    
    read -p "Enter node IP to remove: " node_ip
    
    if grep -q "^$node_ip:" "$NODES_CONFIG_FILE"; then
        # Create backup and remove node
        cp "$NODES_CONFIG_FILE" "$NODES_CONFIG_FILE.bak"
        grep -v "^$node_ip:" "$NODES_CONFIG_FILE.bak" > "$NODES_CONFIG_FILE"
        echo -e "${GREEN}Node $node_ip removed from cluster!${NC}"
    else
        echo -e "${RED}Node $node_ip not found in cluster!${NC}"
    fi
}

# List all nodes in the cluster
list_nodes() {
    echo -e "${YELLOW}=== Cluster Nodes ===${NC}"
    
    if [ ! -s "$NODES_CONFIG_FILE" ]; then
        echo -e "${RED}No nodes configured in cluster!${NC}"
        return
    fi
    
    local count=1
    while IFS=: read -r ip port user name role ssh_key; do
        echo -e "$count. $name ($ip) - Role: $role - User: $user"
        ((count++))
    done < "$NODES_CONFIG_FILE"
}

# Monitor cluster status
monitor_cluster() {
    echo -e "${YELLOW}=== Cluster Status ===${NC}"
    echo -e "Master: $MASTER_USER@$MASTER_IP:$MASTER_PORT"
    echo -e "Thresholds - Memory: ${MEMORY_THRESHOLD}%, CPU: ${CPU_THRESHOLD}%"
    echo -e "Auto-distribute: $AUTO_DISTRIBUTE"
    echo -e ""
    
    # Check master node
    check_node_status "$MASTER_IP" "$MASTER_PORT" "$MASTER_USER" "Master"
    
    # Check slave nodes
    while IFS=: read -r ip port user name role ssh_key; do
        check_node_status "$ip" "$port" "$user" "$name" "$ssh_key"
    done < "$NODES_CONFIG_FILE"
}

# Check status of a single node
check_node_status() {
    local ip=$1
    local port=$2
    local user=$3
    local name=$4
    local ssh_key=$5
    
    local ssh_cmd="ssh"
    if [ "$ssh_key" != "none" ] && [ -n "$ssh_key" ]; then
        ssh_cmd+=" -i $ssh_key"
    fi
    ssh_cmd+=" -p $port $user@$ip"
    
    echo -e "${BLUE}Checking $name ($ip)...${NC}"
    
    # Get system info
    local info_cmd="echo 'Memory:'; free -h | grep Mem | awk '{print \$3\"/\"\$2}';"
    info_cmd+=" echo 'CPU:'; top -bn1 | grep 'Cpu(s)' | awk '{print \$2}';"
    info_cmd+=" echo 'Disk:'; df -h / | awk 'NR==2{print \$5}';"
    info_cmd+=" echo 'Uptime:'; uptime -p"
    
    if result=$($ssh_cmd "$info_cmd" 2>/dev/null); then
        local memory_usage=$(echo "$result" | grep "Memory:" -A1 | tail -n1)
        local cpu_usage=$(echo "$result" | grep "CPU:" -A1 | tail -n1 | cut -d'%' -f1)
        local disk_usage=$(echo "$result" | grep "Disk:" -A1 | tail -n1 | cut -d'%' -f1)
        local uptime=$(echo "$result" | grep "Uptime:" -A1 | tail -n1)
        
        echo -e "  Memory: $memory_usage"
        echo -e "  CPU: ${cpu_usage}%"
        echo -e "  Disk: ${disk_usage}% used"
        echo -e "  Uptime: $uptime"
        
        # Check if above thresholds
        if [ "${cpu_usage%.*}" -ge "$CPU_THRESHOLD" ] || [ "${disk_usage%.*}" -ge "$MEMORY_THRESHOLD" ]; then
            echo -e "  ${RED}Status: OVERLOADED${NC}"
        else
            echo -e "  ${GREEN}Status: OK${NC}"
        fi
    else
        echo -e "  ${RED}Status: OFFLINE${NC}"
    fi
    echo ""
}

# Distribute workload across cluster
distribute_workload() {
    echo -e "${YELLOW}=== Distribute Workload ===${NC}"
    
    read -p "Enter command to distribute: " command
    read -p "Run on all nodes? (y/n): " run_all
    
    if [ "$run_all" = "y" ]; then
        # Run on master
        echo -e "${BLUE}Running on Master...${NC}"
        ssh -p $MASTER_PORT $MASTER_USER@$MASTER_IP "$command"
        
        # Run on all nodes
        while IFS=: read -r ip port user name role ssh_key; do
            echo -e "${BLUE}Running on $name...${NC}"
            local ssh_cmd="ssh"
            if [ "$ssh_key" != "none" ]; then
                ssh_cmd+=" -i $ssh_key"
            fi
            $ssh_cmd -p $port $user@$ip "$command"
        done < "$NODES_CONFIG_FILE"
    else
        # Run on least loaded node
        echo -e "${BLUE}Finding least loaded node...${NC}"
        # Implementation would find node with most available resources
        # For now, just run on first available node
        if read -r first_node < "$NODES_CONFIG_FILE"; then
            IFS=: read -r ip port user name role ssh_key <<< "$first_node"
            echo -e "${BLUE}Running on $name...${NC}"
            local ssh_cmd="ssh"
            if [ "$ssh_key" != "none" ]; then
                ssh_cmd+=" -i $ssh_key"
            fi
            $ssh_cmd -p $port $user@$ip "$command"
        else
            echo -e "${RED}No nodes available!${NC}"
        fi
    fi
}

# Configure cluster settings
configure_cluster() {
    echo -e "${YELLOW}=== Cluster Configuration ===${NC}"
    
    load_cluster_config
    
    echo "1. Cluster Name: $CLUSTER_NAME"
    echo "2. Network: $CLUSTER_NETWORK"
    echo "3. Memory Threshold: ${MEMORY_THRESHOLD}%"
    echo "4. CPU Threshold: ${CPU_THRESHOLD}%"
    echo "5. Auto-distribute: $AUTO_DISTRIBUTE"
    echo "6. Check Interval: ${CHECK_INTERVAL}s"
    echo "7. Master Node Configuration"
    
    read -p "Choose option to configure (1-7): " choice
    
    case $choice in
        1) read -p "New cluster name: " CLUSTER_NAME ;;
        2) read -p "Network CIDR: " CLUSTER_NETWORK ;;
        3) read -p "Memory threshold (%): " MEMORY_THRESHOLD ;;
        4) read -p "CPU threshold (%): " CPU_THRESHOLD ;;
        5) 
            if [ "$AUTO_DISTRIBUTE" = "true" ]; then
                AUTO_DISTRIBUTE="false"
            else
                AUTO_DISTRIBUTE="true"
            fi
            ;;
        6) read -p "Check interval (seconds): " CHECK_INTERVAL ;;
        7) configure_master ;;
        *) echo -e "${RED}Invalid option!${NC}"; return ;;
    esac
    
    save_cluster_config
    echo -e "${GREEN}Cluster configuration updated!${NC}"
}

# Configure master node
configure_master() {
    echo -e "${YELLOW}=== Master Node Configuration ===${NC}"
    
    source "$MASTER_CONFIG_FILE"
    
    echo "1. Master IP: $MASTER_IP"
    echo "2. Master User: $MASTER_USER"
    echo "3. SSH Port: $MASTER_PORT"
    
    read -p "Choose option to configure (1-3): " choice
    
    case $choice in
        1) read -p "New master IP: " MASTER_IP ;;
        2) read -p "New master user: " MASTER_USER ;;
        3) read -p "New SSH port: " MASTER_PORT ;;
        *) echo -e "${RED}Invalid option!${NC}"; return ;;
    esac
    
    echo "MASTER_IP=$MASTER_IP" > "$MASTER_CONFIG_FILE"
    echo "MASTER_USER=$MASTER_USER" >> "$MASTER_CONFIG_FILE"
    echo "MASTER_PORT=$MASTER_PORT" >> "$MASTER_CONFIG_FILE"
    
    echo -e "${GREEN}Master configuration updated!${NC}"
}

# Setup SSH keys for password-less access
setup_ssh_keys() {
    echo -e "${YELLOW}=== SSH Key Setup ===${NC}"
    
    # Generate SSH key if it doesn't exist
    if [ ! -f ~/.ssh/id_rsa.pub ]; then
        echo -e "${BLUE}Generating SSH key...${NC}"
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    fi
    
    # Copy key to master
    echo -e "${BLUE}Copying key to master node...${NC}"
    ssh-copy-id -p $MASTER_PORT $MASTER_USER@$MASTER_IP
    
    # Copy key to all nodes
    while IFS=: read -r ip port user name role ssh_key; do
        if [ "$ssh_key" = "none" ]; then
            echo -e "${BLUE}Copying key to $name...${NC}"
            ssh-copy-id -p $port $user@$ip
        fi
    done < "$NODES_CONFIG_FILE"
    
    echo -e "${GREEN}SSH keys configured!${NC}"
}

# Main cluster menu
cluster_menu() {
    load_cluster_config
    
    while true; do
        echo -e "\n${YELLOW}=== Raspberry Pi Cluster Manager ===${NC}"
        echo -e "1. Add Node to Cluster"
        echo -e "2. Remove Node from Cluster"
        echo -e "3. List Cluster Nodes"
        echo -e "4. Monitor Cluster Status"
        echo -e "5. Distribute Workload"
        echo -e "6. Configure Cluster Settings"
        echo -e "7. Setup SSH Keys"
        echo -e "8. Back to Main Menu"
        echo -e "${YELLOW}=============================================${NC}"
        
        read -p "Choose an option (1-8): " choice
        
        case $choice in
            1) add_node ;;
            2) remove_node ;;
            3) list_nodes ;;
            4) monitor_cluster ;;
            5) distribute_workload ;;
            6) configure_cluster ;;
            7) setup_ssh_keys ;;
            8) break ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
    done
}


# Function to check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    cluster_menu
else
    # Script is being sourced
    echo -e "${GREEN}Cluster manager functions loaded${NC}"
    # You can add any initialization code here for when the script is sourced
fi