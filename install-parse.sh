#!/bin/bash -
#===============================================================================
#
#          FILE: install-parse.sh
#
#         USAGE: ./install-parse.sh
#
#   DESCRIPTION:
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (),
#  ORGANIZATION:
#       CREATED: 05/19/2016 15:55
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

# Must run as root

APP_ID=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;`
MASTER_KEY=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;`

n stable
npm -g install latest

npm -g install parse-server
parse-server --appId $APP_ID --masterKey $MASTER_KEY &

echo "
" | sudo tee -a /etc/rc.local

n 0.10.43
npm -g install 1.4.29
