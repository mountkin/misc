#!/bin/bash

cat <<-'EOF' >/etc/vpn.conf
VPN_SERVER_IP=''
VPN_IPSEC_PSK=''
VPN_USER=''
VPN_PASSWORD=''
GATEWAY='192.168.8.1'
EXTRA_ROUTES=( 192.168.1.0/24 192.168.2.0/24 $VPN_SERVER_IP )
EOF


. /etc/vpn.conf

yum install -y strongswan xl2tpd

cat > /etc/ipsec.conf <<EOF
# ipsec.conf - strongSwan IPsec configuration file

# basic configuration

config setup
  # strictcrlpolicy=yes
  # uniqueids = no

# Add connections here.

# Sample VPN connections

conn %default
  ikelifetime=60m
  keylife=20m
  rekeymargin=3m
  keyingtries=1
  keyexchange=ikev1
  authby=secret
  ike=aes128-sha1-modp1024,3des-sha1-modp1024!
  esp=aes128-sha1-modp1024,3des-sha1-modp1024!

conn myvpn
  keyexchange=ikev1
  left=%defaultroute
  auto=add
  authby=secret
  type=transport
  leftprotoport=17/1701
  rightprotoport=17/1701
  right=$VPN_SERVER_IP
EOF

cat > /etc/ipsec.secrets <<EOF
: PSK "$VPN_IPSEC_PSK"
EOF

chmod 600 /etc/ipsec.secrets

# For CentOS/RHEL & Fedora ONLY
mv /etc/strongswan/ipsec.conf /etc/strongswan/ipsec.conf.old 2>/dev/null
mv /etc/strongswan/ipsec.secrets /etc/strongswan/ipsec.secrets.old 2>/dev/null
ln -s /etc/ipsec.conf /etc/strongswan/ipsec.conf
ln -s /etc/ipsec.secrets /etc/strongswan/ipsec.secrets


cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[lac myvpn]
lns = $VPN_SERVER_IP
ppp debug = yes
pppoptfile = /etc/ppp/options.l2tpd.client
length bit = yes
EOF

cat > /etc/ppp/options.l2tpd.client <<EOF
ipcp-accept-local
ipcp-accept-remote
refuse-eap
require-chap
noccp
noauth
mtu 1280
mru 1280
noipdefault
defaultroute
usepeerdns
connect-delay 5000
name $VPN_USER
password $VPN_PASSWORD
EOF

chmod 600 /etc/ppp/options.l2tpd.client


mkdir -p /var/run/xl2tpd
touch /var/run/xl2tpd/l2tp-control

systemctl enable strongswan 
systemctl enable xl2tpd 

systemctl restart strongswan 
systemctl restart xl2tpd 

cat <<-EOF >/etc/systemd/system/vpn.service
[Unit]
Description=cSphere VPN
After=xl2tpd.service

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/etc/vpn.sh
Restart=no

[Install]
WantedBy=multi-user.target
EOF

cat <<-'EOF' >/etc/vpn.sh
#!/bin/bash
set -ex

. /etc/vpn.conf

touch /var/run/xl2tpd/l2tp-control
strongswan up myvpn
echo "c myvpn" > /var/run/xl2tpd/l2tp-control

for dst in "${EXTRA_ROUTES[@]}"; do
  ip r|grep -q $dst || ip r add $dst via $GATEWAY dev eth0
done

for((i=0;i<300;i++)); do
  if ip r|grep -q ppp0; then
    defroute=$(ip r |grep ppp0|awk '{print $1}')
    ip r del default
    ip r add default via $defroute dev ppp0
    exit 0
  fi
  sleep 1
done

echo "VPN connection failed"
exit 1
EOF

systemctl enable vpn.service
systemctl start vpn.service
