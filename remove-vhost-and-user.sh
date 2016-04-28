#!/bin/bash -
#===============================================================================
#
#          FILE: remove-vhost-and-user.sh
#
#         USAGE: remove-vhost-and-user.sh -u user -h host [-v]
#                remove-vhost-and-user.sh --user user --host host [--verbose]
#
#   DESCRIPTION: This script will remove a virtual host file, it's symbolically
#                 linked vhost file, the given user, their directory from
#                 /var/www/ as well as their Mongo database.
#       OPTIONS:
#                -u | --user
#                   The name of the system account the host will be attributed to.
#                -h | --host
#                   The fully qualified domain name of the virtual host.
#                -v | --verbose
#                   If passed, will show all commands executed.
#  REQUIREMENTS: Nginx, Passenger, Node 0.10.40 managed by N, Mongo, ~/www/,
#                 /etc/nginx/sites-available/, /etc/nginx/sites-enabled/,
#                 /var/www/, sudo privileges.
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jason White (Jason@iDoAWS.com),
#  ORGANIZATION: @iDoAWS
#       CREATED: 04/15/2016 15:33
#      REVISION:  001
#          TODO: Add -s option to enable commented lines and do certificate work
#===============================================================================

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Check for arguments or provide help
if [ ! -n "$1" ] ; then
  echo "Usage:"
  echo "  $0 -u user -h host [-v]"
  echo "  $0 --user user --host host [--verbose]"
  exit 0
fi

# Parse command line arguments into variables
while :
do
    case "$1" in
      -h | --host)
    HOST="$2"
    shift 2
    ;;
      -s | --ssl)
    SSL=true
    shift 1
    ;;
      -u | --user)
    USERNAME="$2"
    shift 2
    ;;
      -v | --verbose)
    VERBOSE=true
    shift 1
    ;;
      -*)
    echo "Error: Unknown option: $1" >&2
    exit 1
    ;;
      *)  # No more options
    break
    ;;
    esac
done

# Validate required arguments
if [ ! $USERNAME ] ; then
  echo 'User name is required.'
  exit 1
fi
if [ ! $HOST ] ; then
  echo 'Host name is required.'
  exit 1
fi

# Check verbosity
if [ -n "$VERBOSE" ] ; then
  set -v
fi

# Confirm that the user really wants to do this
read -p "Are you sure you wish to remove $USERNAME, their web directory *and* database? [y/N] " -n 1 -r REPLY
if [[ $REPLY =~ ^[Yy]$ ]]
  echo "Say goodbye to $USERNAME!"
else
  exit 0
fi

# Add $USERNAME and setup home dir
# TODO: Skip things that exist
find /home/$USERNAME -exec sudo shred -fuz {} +
sudo userdel -rf $USERNAME
sudo shred -fuz /etc/nginx/sites-enabled/$HOST.conf
sudo shred -fuz /etc/nginx/sites-available/$HOST.conf
find /var/www/$USERNAME -exec sudo shred -fuz {} +
sudo rm -rf /var/www/$USERNAME

# End
echo "Tasks complete.  Nginx probably needs to be restarted in order to take effect."
read -p "Would you like me to restart Nginx for you? [y/N] " -n 1 -r REPLY
if [[ $REPLY =~ "^[Yy]$" ]] ; then
  sudo service nginx restart
fi
exit 0
