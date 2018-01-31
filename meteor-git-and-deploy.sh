#!/bin/bash
#===============================================================================
#
#          FILE: meteor-git-and-deploy.sh
#
#         USAGE: meteor-git-and-deploy.sh [-r repo-address] [-d app-dir] [-t temp-dir] [-v]
#                meteor-git-and-deploy.sh [--repo repo-address] [--dir app-dir] [--temp temp-dir] [--verbose]
#
#   DESCRIPTION: This script will change to the new user and clone the given repo
#                 into their home directory, bundle it, install the node modules
#                 and finally deploy it to the user's ~/www.
#       OPTIONS:
#                -d | --dir
#                   Default = 'app'
#                   Name of directory to clone your app into
#                -f | --force
#                   Passing the force flag will automatically remove the cloned
#                     source code repository.
#                -r | --repo
#                   Default = NULL
#                   A valid repository URI (https://github...x.git,
#                     ssh://git@github.../app.git, etc).
#                   If omitted, will attempt to 'git pull' from the specified
#                     directory or ./ rather than clone.
#                -t | --temp
#                   Defaults = '~/www/tmp'
#                   Name of temp directory to create with meteor bundle -directory
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
if [ $# -eq 0 ] ; then
  echo "Usage:"
  echo "  `basename $0` [-r repo-address] [-d app-dir] [-t temp-dir] [-f] [-v]"
  echo "  `basename $0` [--repo repo-address] [--dir app-dir] [--temp temp-dir] [--force] [--verbose]"
  echo "This should be run on your staging or production server."
  exit 0
fi

# Warn ec2-user or root
ME=`whoami`
if [[ $ME =~ ^(ec2-user|root)$ ]] ; then
  echo "You probably want to run this as an app user, rather than $ME."
  read -p "Would you still like to proceed? [y/N]" -n 1 -r REPLY
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]] ; then
    echo "Exiting without action."
    exit 1
  fi
fi

# Check Node version
#NODE_VERSION=`node --version`
#if [[ ! $NODE_VERSION =~ ^v0\.10\.4 ]] ; then
#  echo "You should bundle Meteor apps with Node v0.10.4x."
#  echo "You are using Node $NODE_VERSION, please correct this and try again."
#  echo "You may switch to the tested & installed Meteor-friendly version with 'sudo n 0.10.43' using the ec2-user account."
#  read -p "Would you still like to try anyway? [y/N]" -n 1 -r REPLY
#  echo ""
#  if [[ ! $REPLY =~ ^[Yy]$ ]] ; then
#    echo "Exiting without action."
#    exit 1
#  fi
#fi

# Save PWD
ORIGIN=`pwd`

# Parse command line arguments into variables
while :
do
    case ${1:-} in
      -d | --dir)
    DIR="$2"
    shift 2
    ;;
      -f | --force)
    FORCE=true
    shift 1
    ;;
      -r | --repo)
    REPO="$2"
    shift 2
    ;;
      -t | --temp)
    TEMP_DIR="$2"
    shift 1
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

# Set necessary defaults
if [ ! -v DIR ] ; then
  DIR='app'
fi
if [ ! -v TEMP_DIR ] ; then
  TEMP_DIR=~/www/tmp
fi

# Validate temporary location
if [ -d $TEMP_DIR ] ; then
  echo "Temporary directory $TEMP_DIR already exists, please remove or rename and try again."
  exit 1
fi

# Check verbosity
if [ -v VERBOSE ] ; then
  set -v
fi

# Ensure we have enough repository data to work with
if [[ ! -d "$DIR/.git" && ! -v REPO ]] ; then
  echo "Cannot clone or pull without a repository specified"
  exit 1
fi

# Clone or pull
if [ -d "$DIR" ] ; then
  cd "$DIR"
  if [ -d .git ] ; then
    git pull
  else
    git clone $REPO ./
  fi
else
  git clone $REPO $DIR
  cd $DIR
fi

DIR=`pwd`

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
meteor npm install --production
meteor npm prune --production

# Copy over persistent files for standalone mode, jic
if [ -f "$DIR/bundle/Passengerfile.json" ]; then
  cp "$DIR/bundle/Passengerfile.json" "$TEMP_DIR/tmp/bundle/"
fi

# Switch directories, restart app
cd ~/www
if [ -d ./bundle.old ] ; then
  rm -rf bundle.old
fi
if [ -d ./bundle ] ; then
  mv bundle bundle.old
  PRIOR=true
fi
mv $TEMP_DIR ./bundle

# End
if [ -v PRIOR ] ; then
  echo "This appears to have been an upgrade, run 'sudo passenger-config restart-app /var/www/$ME' from the ec2-user account."
  echo "Otherwise, Passenger will be serving your old version from memory."
  echo "After manually confirming the app is running, archive & remove ~/www/bundle.old."
else
  echo "This appears to be the first deployment for this app, run 'sudo service nginx restart' from the ec2-user account."
fi
cd $ORIGIN
echo
echo "Tasks complete.  App has been deployed."
echo
if [ -v FORCE ] ; then
  rm -rf "$DIR"
else
  read -p "Would you like to 'rm -rf' the source directory, $DIR? [y/N]" -n 1 -r REPLY
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    rm -rf "$DIR"
  fi
fi
echo
exit 0
