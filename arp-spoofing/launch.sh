#!/bin/bash
set -e

DOCKER_COMPOSE="docker compose"

cd "$(dirname "$0")"

$DOCKER_COMPOSE up -d --build

sleep 3

docker exec attacker bash -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
docker exec attacker bash -c "iptables -t nat -A POSTROUTING -s 10.5.0.20 -j MASQUERADE"

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

open_terminal "Attacker: ARP Spoof" \
    "echo 'arpspoof -i eth0 -t 10.5.0.254 -r 10.5.0.20'; \
     docker exec -it attacker bash"

open_terminal "Attacker: Network Monitor" \
    "echo 'tcpdump -i eth0 -XX -s 0 -l \"tcp or icmp\"'; \
     docker exec -it attacker bash"

open_terminal "Victim: Traffic Generator" \
    "echo 'arp -s 10.5.0.254 02:42:0a:05:00:fe'; \
     echo 'ping 8.8.8.8'; \
     echo 'curl example.com'; \
     docker exec -it victim bash"


open_terminal "Gateway: Traffic Generator" \
    "echo 'arp -s 10.5.0.20 02:42:0a:05:00:14'; \
     docker exec -it gateway bash"
