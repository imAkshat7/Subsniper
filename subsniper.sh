#!/bin/bash

# Enable error checking and exit on pipe failures
set -eo pipefail

# Colors
green="\e[92m"
yellow="\e[93m"
cyan="\e[96m"
red="\e[91m"
reset="\e[0m"

# Current timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Display Banner
echo -e "${red}"
cat << "EOF"
░██████╗██╗░░░██╗██████╗░░██████╗███╗░░██╗██╗██████╗░███████╗██████╗░"
██╔════╝██║░░░██║██╔══██╗██╔════╝████╗░██║██║██╔══██╗██╔════╝██╔══██╗"
╚█████╗░██║░░░██║██████╦╝╚█████╗░██╔██╗██║██║██████╔╝█████╗░░██████╔╝"
░╚═══██╗██║░░░██║██╔══██╗░╚═══██╗██║╚████║██║██╔═══╝░██╔══╝░░██╔══██╗"
██████╔╝╚██████╔╝██████╦╝██████╔╝██║░╚███║██║██║░░░░░███████╗██║░░██║"
╚═════╝░░╚═════╝░╚═════╝░╚═════╝░╚═╝░░╚══╝╚═╝╚═╝░░░░░╚══════╝╚═╝░░╚═╝"
EOF
echo -e "${reset}"
echo -e "${yellow}Welcome to Subsniper - SubDomain Enumeration Toolkit${reset}"
echo -e "${yellow} Author - HunterAkki | Version 1.0 | $(date)${reset}\n"

# Check dependencies
check_dependency() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "${red}[ERROR] Required tool $1 not found. Please install it.${reset}"
        exit 1
    fi
}

# Check for required tools
REQUIRED_TOOLS=("subfinder" "assetfinder" "sublist3r" "httpx-toolkit" "curl")
for tool in "${REQUIRED_TOOLS[@]}"; do
    check_dependency "$tool"
done

# Initialize variables
declare -a DOMAINS
declare -a COUNTS
TEMP_FILES=()

# Cleanup function
cleanup() {
    rm -f "${TEMP_FILES[@]}" 2>/dev/null
}

# Domain input handling
read -p "Do you want to enter a single domain? [y/N]: " choice
choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

if [[ "$choice" =~ ^(y|yes)$ ]]; then
    while true; do
        read -p "Enter the domain: " domain
        domain=$(echo "$domain" | tr -d '[:space:]')
        if [ -z "$domain" ]; then
            echo -e "${red}[ERROR] Domain cannot be empty!${reset}"
        else
            DOMAINS=("$domain")
            break
        fi
    done
else
    # Check if domain.txt exists
    INPUT_FILE="domain.txt"
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo -e "${red}[ERROR] Input file $INPUT_FILE not found!${reset}"
        exit 1
    fi
    mapfile -t DOMAINS < "$INPUT_FILE"
    echo -e "${green}[+] Found ${#DOMAINS[@]} target(s) in $INPUT_FILE${reset}"
fi

# Main enumeration process
for domain in "${DOMAINS[@]}"; do
    echo -e "\n${yellow}[*] Processing: $domain${reset}"
    
    # Create temp files
    subfinder_temp=$(mktemp)
    assetfinder_temp=$(mktemp)
    sublist3r_temp=$(mktemp)
    combined_temp=$(mktemp)
    TEMP_FILES+=("$subfinder_temp" "$assetfinder_temp" "$sublist3r_temp" "$combined_temp")

    # Run tools
    echo -e "${cyan}[→] Running subfinder...${reset}"
    subfinder -d "$domain" -silent -o "$subfinder_temp" 2>/dev/null
    
    echo -e "${cyan}[→] Running assetfinder...${reset}"
    assetfinder --subs-only "$domain" > "$assetfinder_temp" 2>/dev/null
    
    echo -e "${cyan}[→] Running sublist3r...${reset}"
    sublist3r -d "$domain" -o "$sublist3r_temp" >/dev/null 2>&1

    # Combine results
    cat "$subfinder_temp" "$assetfinder_temp" "$sublist3r_temp" | sort -u > "$combined_temp"
    count=$(wc -l < "$combined_temp")
    COUNTS+=("$count")
    
    # Append to master file
    cat "$combined_temp" >> alldomain.txt
    echo -e "${green}[✓] Found $count unique subdomains for $domain${reset}"
done

# Cleanup temp files
cleanup

# Verify alive domains
if [ -s alldomain.txt ]; then
    echo -e "\n${yellow}[*] Verifying alive domains...${reset}"
    
    # Use exact specified command
    if ! cat alldomain.txt | httpx-toolkit -silent -o dt.txt ; then
        echo -e "${red}[ERROR] httpx-toolkit failed to execute properly${reset}"
        exit 1
    fi
    
    # Check if file was created even if empty
    if [ ! -f dt.txt ]; then
        echo -e "${red}[ERROR] dt.txt was not created${reset}"
        exit 1
    fi
    
    total_alive=$(wc -l < dt.txt)
else
    echo -e "${red}[!] No subdomains found to process!${reset}"
    exit 1
fi

# Generate final report
echo -e "\n${green}=== FINAL REPORT ===${reset}"
total_subdomains=$(wc -l < alldomain.txt)

for i in "${!DOMAINS[@]}"; do
    echo -e "${cyan}► ${DOMAINS[$i]}${reset}"
    echo -e "  Subdomains: ${COUNTS[$i]}"
done

echo -e "\n${green}[+] Total subdomains found: $total_subdomains${reset}"
echo -e "${green}[+] Alive domains: $total_alive${reset}"
echo -e "${green}[+] Results saved to current directory:"
echo -e "  - alldomain.txt (all subdomains)"
echo -e "  - dt.txt (verified alive domains)${reset}"
