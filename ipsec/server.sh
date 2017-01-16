#!/bin/bash

cat <<-EOF >/etc/vpn.env
VPN_SERVER_IP=
VPN_IPSEC_PSK=
VPN_USER=
VPN_PASSWORD=
EOF

docker run \
  --name ipsec-vpn-server \
  --env-file /etc/vpn.env \
  --restart=always \
  -p 500:500/udp \
  -p 4500:4500/udp \
  -v /lib/modules:/lib/modules:ro \
  -d --privileged \
  hwdsl2/ipsec-vpn-server
