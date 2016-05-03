#!/bin/bash -
#===============================================================================
#
#          FILE: meteor-bundle-and-deploy
#
#         USAGE: meteor-bundle-and-deploy [app-dir] [-t temp-dir] [-v]
#                meteor-bundle-and-deploy [app-dir] [--temp temp-dir] [--verbose]
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

# Save PWD
ORIGIN=`pwd`

# Secure exit strategy
function finito () {
  if [ ! -v $TEMP_EXISTS -a -v $TEMP_DIR -a -e $TEMP_DIR ] ; then
    rm -rf $TEMP_DIR
  fi
}
trap finito EXIT INT TERM

# Check for arguments or provide help
if [ $# -eq 0 ] ; then
  echo "Usage:"
  echo "  `basename $0` [app-dir] [-t temp-dir] [-v]"
  echo "  `basename $0` [app-dir] [--temp temp-dir] [--verbose]"
  exit 0
fi

# Warn ec2-user or root
ME=`whoami`
if [[ ME =~ ^(ec2-user|root)$ ] ; then
  echo "You probably want to run this as an app user, rather than $ME\."
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
  echo "You must be in, or supply, a valid Meteor app directory."
  exit 1
fi

if [ ! -d .meteor ] ; then
  echo "You must be in, or supply, a valid Meteor app directory."
  cd $OLDPWD
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
  TEMP_EXISTS=true
  exit 1
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
  echo "This appears to have been an upgrade."
  read -p "Would you like me to restart the Passenger process? [Y/n]" -n 1 -r REPLY
  echo ""
  if [[ $REPLY =~ ^[Yy\n]$ ]] ; then
    sudo passenger-config restart-app $APP_DIR
  else
    echo "If this is an upgrade, run 'sudo passenger-config restart-app $APP_DIR'."
    echo "Otherwise, Passenger will be serving your old version from memory."
  fi
  echo "After manually confirming the app is running, archive & remove ~/www/bundle.old."
else
  echo "This appears to be the first deployment for this app."
  read -p "Would you like me to restart Nginx for you? [Y/n]" -n 1 -r REPLY
  echo ""
  if [[ $REPLY =~ ^[Yy\n]$ ]] ; then
    sudo service nginx restart
  else
    echo "If this is the application's first deployment, Nginx will need to be restarted."
    echo "If this is an upgrade, run 'sudo passenger-config restart-app $APP_DIR'."
    echo "Otherwise, Passenger will be serving your old version from memory."
  fi
  echo "After manually confirming the app is running, archive & remove ~/www/bundle.old."
fi
cd $ORIGIN
echo
echo "Tasks complete.  App has been deployed."
echo
exit 0
