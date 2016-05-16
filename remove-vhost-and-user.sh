#!/bin/bash -
#===============================================================================
#
#          FILE: remove-vhost-and-user.sh
#
#         USAGE: remove-vhost-and-user.sh -u user -h host [-f] [-v]
#                remove-vhost-and-user.sh --user user --host host [--force] [--verbose]
#
#   DESCRIPTION: This script will remove a virtual host file, it's symbolically
#                 linked vhost file, the given user, their directory from
#                 /var/www/ as well as their Mongo database.
#       OPTIONS:
#                -u | --user
#                   The name of the system account to remove.
#                -h | --host
#                   The fully qualified domain name of the virtual host to remove.
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
if [ $# -eq 0 ] ; then
  echo "Usage:"
  echo "  `basename $0` -u user -h host [-f] [-v]"
  echo "  `basename $0` --user user --host host [--force] [--verbose]"
  echo "This should be run on your staging or production server."
  exit 0
fi

# FYI: User warning follows parameter assessment and validation

# Parse command line arguments into variables
while :
do
    case ${1:-} in
      -f | --force)
    FORCE=true
    shift 1
    ;;
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
if [ ! -v USERNAME ] ; then
  echo 'User name is required.'
  exit 1
fi
if [ ! -v HOST ] ; then
  echo 'Host name is required.'
  exit 1
fi

# Confirm that the user really wants to do this
echo "This script will *eradicate* all traces of this user and associated resources."
if [ -v FORCE ] ; then
    echo "Proceeding without confirmation."
else
  read -p "Are you sure you wish to remove $USERNAME, their web directory *and* database? [y/N] " -n 1 -r REPLY
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]] ; then
    echo "Exiting without action."
    exit 1
  fi
fi

# Check verbosity
if [ -v VERBOSE ] ; then
  set -v
fi

# Remove files & directories
if [ 0 -ne $(getent passwd $USERNAME | wc -l) ] ; then
  sudo userdel -rf $USERNAME
fi
if [ -d /home/$USERNAME ] ; then
  sudo rm -rf /home/$USERNAME
fi
if [ -L /etc/nginx/sites-enabled/$HOST\.conf ] ; then
  sudo rm -f /etc/nginx/sites-enabled/$HOST\.conf
fi
if [ -f /etc/nginx/sites-available/$HOST\.conf ] ; then
  sudo rm -f /etc/nginx/sites-available/$HOST\.conf
fi
if [ -d /var/www/$USERNAME ] ; then
  sudo rm -rf /var/www/$USERNAME
fi

# Drop database
sudo mongo $USERNAME --eval "db.dropDatabase()"

# End
echo "Tasks complete.  Nginx probably needs to be restarted in order to take effect."
if [ -v FORCE ] ; then
    sudo service nginx restart
else
  read -p "Would you like me to restart Nginx for you? [y/N] " -n 1 -r REPLY
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    sudo service nginx restart
  fi
fi
exit 0
