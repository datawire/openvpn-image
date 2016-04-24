#!/usr/bin/env bash
set -e
set -u
set -o pipefail

config_bucket="${1:?Configuration bucket not specified!}"
secrets_bucket="${2:?Secrets bucket not specified!}"
eip_allocation_id="${3:?EC2 Elastic IP allocation ID not specified!}"
vpn_cidr="${4:?VPN CIDR block not specified!}"
region="${5:?EC2 Region not specified!}"

arw_msg() {
  printf "%s\n" "--> $1"
}

arw_msg "Querying EC2 instance ID"
ec2_id="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"

arw_msg "Disable network source/destination checking"
aws ec2 modify-instance-attribute --instance-id ${ec2_id} --no-source-dest-check --region ${region}

arw_msg "Associate Elastic IP address"
aws ec2 associate-address --instance-id ${ec2_id} --allocation-id ${eip_allocation_id} --region ${region}

arw_msg "Download VPN server key data from '${secrets_bucket}'"
mkdir -p /etc/openvpn/keys
aws s3 cp s3://${secrets_bucket}/openvpn /etc/openvpn/keys \
  --recursive \
  --include "ca.crt" \
  --include "server.crt" \
  --include "server.key" \
  --include "dh2048.pem"
chmod -R 0600 /etc/openvpn/keys

arw_msg "Download VPN server configuration from '${config_bucket}'"
aws s3 cp s3://${config_bucket}/openvpn/server.conf /etc/openvpn

iptables -t nat -A POSTROUTING -s ${vpn_cidr} -o eth0 -j MASQUERADE

service openvpn start

arw_msg "Done!"