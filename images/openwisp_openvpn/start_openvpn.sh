#!/bin/bash

set -e
. /utils.sh

/usr/sbin/openvpn --config ${VPN_NAME}.conf