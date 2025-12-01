FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    iptables \
    iproute2 \
    iputils-ping \
    net-tools \
    tcpdump \
    && rm -rf /var/lib/apt/lists/*

RUN echo '#!/bin/bash\n\
echo 1 > /proc/sys/net/ipv4/ip_forward\n\
# Masquerade traffic leaving eth0 (WAN)\n\
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE\n\
# Accept forwarding\n\
iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT\n\
iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT\n\
echo "Router started with IP Forwarding enabled."\n\
tail -f /dev/null' > /start.sh && chmod +x /start.sh

CMD ["/start.sh"]