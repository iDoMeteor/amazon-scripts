#!/bin/bash -
#===============================================================================
#
#          FILE: update-amazon-tools.sh
#
#         USAGE: update-amazon-tools.sh
#
#   DESCRIPTION: This script updates the Amazon EC2 AMI tools as well as my
#                 scripts for creating virtual host and handling Meteor
#                 deployments.
#       OPTIONS: ---
#  REQUIREMENTS: Git, Yum, aws-amitools-ec2
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jason White (Jason@iDoAWS.com),
#  ORGANIZATION: @iDoAWS
#       CREATED: 04/28/2016 23:59
#      REVISION:  001
#===============================================================================

# Strict mode
set -euo pipefail
IFS=$'\n\t'

echo " + Updating amazon-scripts by @iDoAWS/@iDoMeteor"
cd /usr/local/bin
sudo git pull
cd $OLDPWD
echo " + Updated amazon-scripts"

