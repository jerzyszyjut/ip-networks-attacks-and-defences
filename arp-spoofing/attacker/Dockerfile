FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    dsniff \
    tcpdump \
    net-tools \
    iproute2 \
    iputils-ping \
    iptables \
    && rm -rf /var/lib/apt/lists/*

RUN echo '#!/bin/bash\n\
echo 1 > /proc/sys/net/ipv4/ip_forward\n\
# SNAT: Rewrite source IP of packets from victim going out\n\
# This makes responses come back through us\n\
# iptables -t nat -A POSTROUTING -s 10.5.0.20 -j MASQUERADE\n\
echo "Attacker started with IP Forwarding and MASQUERADE enabled."\n\
tail -f /dev/null' > /start.sh && chmod +x /start.sh

CMD ["/start.sh"]
