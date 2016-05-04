#!/bin/bash -
#===============================================================================
#
#          FILE: meteor-bundle-and-deploy.sh
#
#         USAGE: meteor-bundle-and-deploy.sh [app-dir] [-t temp-dir] [-v]
#                meteor-bundle-and-deploy.sh [app-dir] [--temp temp-dir] [--verbose]
#
#   DESCRIPTION: This script should be run in your production or staging
#                 environment, which already contains the source for your
#                 application, when you want to deploy that source.
#                The script will change into your application's root directory
#                 and run meteor bundle -directory <temp-dir>.  After the app
#                 has been bundled, it will change into the .../programs/server
#                 directory to install and prune the NPM modules.
#                Once the modules have been taken care of, it will move your
#                 existing app bundle to bundle.old and put your new bundle in
#                 its place.
#                Upon completion of all this hard work, it will then tell
#                 Passenger to restart the app process, negating the need to
#                 restart Nginx.
#                The script will remove the temporary directory that it creates,
#                 but it will leave the bundle.old for you to remove manually
#                 after you confirm that your new deployment functions as
#                 intended.
#       OPTIONS:
#                app-dir
#                   Location of your app's Meteor root (ie; has contains .meteor)
#                   If omitted, assumes that your pwd is that the app root
#                -t | --temp
#                   Name of temp directory to create with meteor bundle -directory
#                   Defaults to ~/www/tmp
#                -v | --verbose
#                   If passed, will show all commands executed.
#  REQUIREMENTS: Nginx, Passenger, Node 0.10.40, Meteor locally installed, ~/www/.
#          BUGS: ---
#         NOTES: App dir is relative to current location, temp dir is absolute
#                Assumes app bundle lives in ~/www/bundle
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
  echo "  `basename $0` [app-dir] [-t temp-dir] [-v]"
  echo "  `basename $0` [app-dir] [--temp temp-dir] [--verbose]"
  echo "This should be run on your staging or production server."
  exit 0
fi

# Save PWD
ORIGIN=`pwd`

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

# Make sure we're working with a Meteor app
if [ -d $1 ] ; then
  APP_DIR=$1
  shift 1
  cd $APP_DIR
else
  APP_DIR=`pwd`
fi
if [ ! -d .meteor ] ; then
  echo "You must be in, or supply, a valid Meteor app directory."
  cd $ORIGIN
  exit 1
fi

# Parse command line arguments into variables
while :
do
    case ${1:-} in
      -t | --temp)
    TEMP_DIR="$2"
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

# Set default temporary location if required
if [ ! -v TEMP_DIR ] ; then
  TEMP_DIR=~/www/tmp
fi

# Validate temporary location
if [ -d $TEMP_DIR ] ; then
  echo "Temporary directory $TEMP_DIR already exists, please remove or rename and try again."
  read -p "Would you like me to remove it and continue? [y/N]" -n 1 -r REPLY
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    rm -rf $TEMP_DIR
  else
    echo "Exiting without action."
    exit 1
  fi
fi

# Check for verbosity
if [ -v VERBOSE ] ; then
  set -v
fi

# Bundle to temporary directory
meteor bundle --directory $TEMP_DIR

# Install dependencies
cd $TEMP_DIR
cd programs/server
npm install --production
npm prune --production

# Copy over persistent files for standalone mode, jic
if [ -f $APP_DIR/bundle/Passengerfile.json ]; then
  cp $APP_DIR/bundle/Passengerfile.json $APP_DIR/tmp/bundle/
fi

# Switch directories, restart app
cd ~/www
if [ -d ./bundle ] ; then
  mv bundle bundle.old
  PRIOR=true
fi
mv $TEMP_DIR ./bundle

cd

# End
if [ -v PRIOR ] ; then
  echo "This appears to have been an upgrade, run 'sudo passenger-config restart-app $APP_DIR'."
  echo "Otherwise, Passenger will be serving your old version from memory."
  echo "After manually confirming the app is running, archive & remove ~/www/bundle.old."
else
  echo "This appears to be the first deployment for this app, run 'sudo service nginx restart'."
fi
cd $ORIGIN
echo
echo "Tasks complete.  App has been deployed."
echo
exit 0
