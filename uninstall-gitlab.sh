#!/bin/bash -
#===============================================================================
#
#          FILE: uninstall-gitlab.sh
#
#         USAGE: uninstall-gitlab.sh -h hostname [-a] [-v]
#                uninstall-gitlab.sh --host hostname [--all] [--verbose]
#
#   DESCRIPTION: This script will uninstall Gitlab and it's virutal host files.
#                 If the all flag is passed, all the data and users associated
#                 with the installation, including all the repositories, will
#                 also be removed.
#       OPTIONS:
#                -a | --all
#                   Also remove all data and users, including the repositories.
#                -h | --host
#                   The fully qualified domain name of the virtual host you wish
#                     to use to access GitLab.
#                -v | --verbose
#                   If passed, will show all commands executed.
#  REQUIREMENTS: Gitlab, Nginx, Passenger, Yum
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jason White (Jason@iDoAWS.com),
#  ORGANIZATION: @iDoAWS
#       CREATED: 05/17/2016 22:33
#      REVISION:  001
#===============================================================================

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Check for arguments or provide help
if [ $# -eq 0 ] ; then
  echo "Usage:"
  echo "  `basename $0` -h hostname [-a] [-v]"
  echo "  `basename $0` --host host name [--all] [--verbose]"
  echo "This remove Gitlab from your system."
  echo "Including the all flag will also remove related all data and users."
  exit 0
fi

# Confirm that the user really wants to do this
read -p "Are you sure you wish to remove Gitlab? [y/N] " -n 1 -r REPLY
if [[ ! $REPLY =~ ^[Yy]$ ]]
  exit 0
fi

# Parse command line arguments into variables
while :
do
    case ${1:-} in
      -a | --all)
    ALL=true
    shift 1
    ;;
      -h | --host)
    HOST="$2"
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

# Validate arguments
if [ ! -v HOST ] ; then
  echo 'Host name is required.'
  exit 1
fi

# Check verbosity
if [ -v VERBOSE ] ; then
  set -v
fi


# Do it
if [ -v ALL ] ; then
  sudo gitlab-ctl stop
  sudo gitlab-ctl remove-accounts
  sudo gitlab-ctl cleanse
else
  sudo gitlab-ctl stop
  sudo gitlab-ctl remove-accounts
  sudo gitlab-ctl uninstall
fi
sudo yum remove gitlab-ce -y
sudo rm -rf /etc/gitlab
sudo rm /etc/nginx/sites-enabled/$HOST.conf
sudo rm /etc/nginx/sites-available/$HOST.conf

# Finish
sudo service nginx restart
echo "Gitlab has been removed."
exit 0
