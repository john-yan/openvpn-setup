#!/bin/bash

CWD=$(pwd)
CA_DIR=$CWD/CA
SERVER_DIR=$CWD/server
CLIENT_DIR=$CWD/client
EASYRSA_DIR=$CWD/EasyRSA-v3.0.6

easyrsa=$EASYRSA_DIR/easyrsa

# make first arg as client name
CLIENT_NAME=${1}

# generate key and req
cd $CLIENT_DIR
$easyrsa --batch --req-cn="$CLIENT_NAME" gen-req $CLIENT_NAME nopass

# sign client key
cd $CA_DIR
$easyrsa import-req $CLIENT_DIR/pki/reqs/$CLIENT_NAME.req $CLIENT_NAME
$easyrsa --batch sign-req client $CLIENT_NAME


cat $CWD/client-base.conf  \
    <(echo -e '<ca>') \
    $CA_DIR/pki/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    $CA_DIR/pki/issued/$CLIENT_NAME.crt \
    <(echo -e '</cert>\n<key>') \
    $CLIENT_DIR/pki/private/$CLIENT_NAME.key \
    <(echo -e '</key>\n<tls-auth>') \
    $CWD/ta.key \
    <(echo -e '</tls-auth>') \
    > $CLIENT_DIR/$CLIENT_NAME.ovpn
