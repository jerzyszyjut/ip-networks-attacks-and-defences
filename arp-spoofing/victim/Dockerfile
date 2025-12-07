FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    curl \
    iputils-ping \
    iproute2 \
    net-tools \
    traceroute \
    libpcap-dev \
    arpwatch \
    && rm -rf /var/lib/apt/lists/*

RUN echo '#!/bin/bash\n\
# Delete default docker gateway (usually .1)\n\
ip route del default\n\
touch /var/lib/arpwatch/arp.dat\n\
# Add our router container as the gateway\n\
ip route add default via 10.5.0.254\n\
echo "Victim configured. Gateway set to 10.5.0.254"\n\
tail -f /dev/null' > /start.sh && chmod +x /start.sh

CMD ["/start.sh"]