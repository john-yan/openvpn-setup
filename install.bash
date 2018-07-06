#!/bin/bash -x

CWD=$(pwd)
CA_DIR=$CWD/CA
SERVER_DIR=$CWD/server
EASYRSA_DIR=$CWD/EasyRSA-3.0.4

easyrsa=$EASYRSA_DIR/easyrsa

SERVER_CONF_FILES="\
  $SERVER_DIR/pki/private/server.key \
  $SERVER_DIR/ta.key \
  $SERVER_DIR/pki/dh.pem \
  $CA_DIR/pki/issued/server.crt \
  $CA_DIR/pki/ca.crt \
  $CWD/server.conf"

# disable prompt when install updates
export DEBIAN_FRONTEND=noninteractive

# install all updates
apt update -y && apt dist-upgrade -y

# install openvpn
apt install -y openvpn wget git vim

# download EasyRSA and untar
wget -O - https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.4/EasyRSA-3.0.4.tgz | tar xzv

# create ROOT dirs
mkdir -p $CA_DIR
mkdir -p $SERVER_DIR

# generate server key and Diffie-Hellman key
cd $SERVER_DIR
cp $CWD/vars ./vars
$easyrsa --batch init-pki
$easyrsa --batch gen-req server nopass
$easyrsa --batch gen-dh
openvpn --genkey --secret ta.key

# generate CA and sign server key
cd $CA_DIR
cp $CWD/vars ./vars
$easyrsa --batch init-pki
$easyrsa --batch build-ca nopass
$easyrsa import-req $SERVER_DIR/pki/reqs/server.req server
$easyrsa --batch sign-req server server

# install keys, certificates and configuration files
cp $SERVER_CONF_FILES /etc/openvpn/

# enable ip forwarding
cp $CWD/sysctl.conf /etc/sysctl.conf
sysctl -p

INTERFACE=$(ip route | grep default | awk '{print $5}')

# enable nat
echo "
# START OPENVPN RULES
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]
# Allow traffic from OpenVPN client to $INTERFACE
-A POSTROUTING -s 10.8.0.0/8 -o $INTERFACE -j MASQUERADE
COMMIT
# END OPENVPN RULES
" | cat - /etc/ufw/before.rules > $CWD/before.rules.tmp
mv $CWD/before.rules.tmp /etc/ufw/before.rules

# configure ufw firewall
sed -i 's/^DEFAULT_FORWARD_POLICY.\+/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw  # accept forwarding
ufw allow 1194/udp
ufw allow OpenSSH
ufw disable
ufw --force enable

systemctl start openvpn@server
systemctl enable openvpn@server
sleep 3
ip addr show tun0
systemctl --no-pager status openvpn@server



