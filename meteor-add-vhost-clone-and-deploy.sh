#!/bin/bash
#===============================================================================
#
#          FILE: meteor-add-vhost-clone-and-deploy.sh
#
#         USAGE: meteor-add-vhost-clone-and-deploy.sh -u user -h FQDN [-r repo-address] [-d app-dir] [-t temp-dir] [-v]
#                meteor-add-vhost-clone-and-deploy.sh --user user --host FQDN [--repo repo-address] [--dir app-dir] [--temp temp-dir] [--verbose]
#
#   DESCRIPTION: This script should be run in your production or staging
#       OPTIONS:
#                -b | --bundle
#                   Default = 'bundle'
#                   The name of your bundle, <bundle-name>.tar.gz.
#                   I recommend making them descriptive and versioned, so
#                    that you can easily switch versions in emergencies.
#                -d | --dir
#                   Default = 'app'
#                   Name of directory to clone your app into
#                   Note: This is relative to the passed user's home directory
#                -h | --host
#                   * Required
#                   The fully qualified domain name of the virtual host.
#                -r | --repo
#                   Default = NULL
#                   A valid repository URI (https://github...x.git,
#                     ssh://git@github.../app.git, etc).
#                   If omitted, will attempt to 'git pull' rather than clone.
#                -t | --temp
#                   Defaults = '~/www/tmp'
#                   Name of temp directory to create with meteor bundle -directory
#                -u | --user
#                   The name of the system account the host will be attributed to.
#                   If their home directory already exists, vhost creation will be skipped
#                -v | --verbose
#                   If passed, will show all commands executed.
#  REQUIREMENTS: Nginx, Passenger, Node 0.10.43, Meteor locally installed, ~/www/.
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jason White (Jason@iDoAWS.com),
#  ORGANIZATION: @iDoAWS
#       CREATED: 04/12/2016 12:09
#      REVISION:  001
#===============================================================================

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Check for arguments or provide help
if [ ! -n "$1" ] ; then
  echo "Usage:"
  echo "  $0 -u user -h FQDN [-r repo-address] [-d app-dir] [-t temp-dir] [-v]"
  echo "  $0 --user user --host FQDN [--repo repo-address] [--dir app-dir] [--temp temp-dir] [--verbose]"
  exit 0
fi

# Parse command line arguments into variables
while :
do
    case "$1" in
      -b | --bundle)
    BUNDLE="$2"
    shift 2
    ;;
      -d | --dir)
    DIR="$2"
    shift 2
    ;;
      -h | --host)
    HOST="$2"
    shift 2
    ;;
      -r | --repo)
    REPO="$2"
    shift 2
    ;;
      -s | --ssl)
    SSL=true
    shift 1
    ;;
      -t | --temp)
    TEMP_DIR=true
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
if [ ! -n $USERNAME ] ; then
  echo 'User name is required.'
  exit 1
fi
if [ ! -n $HOST ] ; then
  echo 'A valid hostname (FQDN) is required.'
  exit 1
fi

# Set necessary defaults
if [ ! -n "$DIR" ] ; then
  DIR='app'
fi
if [ ! -n "$TEMP_DIR" ] ; then
  TEMP_DIR=~/www/tmp
fi

# Validate temporary location
if [ -d $TEMP_DIR ] ; then
  echo "Temporary directory $TEMP_DIR already exists, please remove or rename and try again."
  exit 1
fi

# Check verbosity
if [ -n "$VERBOSE" ] ; then
  set -v
fi

# Create Virtual Host
if [ -d "/home/$USERNAME" ] ; then
  echo "/home/$USERNAME exists, skipping nginx-add-meteor-vhost.sh"
else
  nginx-add-meteor-vhost.sh -u $USERNAME -h $HOST
fi

# Change to new user
sudo su $USERNAME
cd

# Clone or pull
if [ -d "$DIR" ] ; then
  cd "$DIR"
  DIR=`pwd`
  if [ -d .git ] ; then
    git pull
  else
    echo "Directory exists but lacks .git/, cannot clone or pull."
    cd
    exit 1
  fi
else
  git clone $REPO $DIR
fi

# Check app is a Meteor app
if [ ! -d .meteor ] ; then
  echo "$DIR does not appear to be a Meteor application root."
  cd
  exit 1
fi

# Bundle to temporary directory
meteor bundle --directory $TEMP_DIR

# Install dependencies
cd $TEMP_DIR
cd programs/server
npm install --production
npm prune --production

# Copy over persistent files for standalone mode, jic
if [ -f "~/$DIR/bundle/Passengerfile.json" ]; then
  cp "~/$DIR/bundle/Passengerfile.json" "$TEMP_DIR/tmp/bundle/"
fi

# Switch directories, restart app
cd ~/www
if [ -d ./bundle ] ; then
  mv bundle bundle.old
  PRIOR=true
fi
mv $TEMP_DIR ./bundle
rm -rf $TEMP_DIR

# Exit su environment
exit

# End
echo "Tasks complete.  Nginx will need to be restarted in order to take effect."
read -p "Would you like me to restart Nginx for you? [y/N] " -n 1 -r REPLY
if [[ $REPLY =~ "^[Yy]$" ]] ; then
  sudo service nginx restart
fi
exit 0
