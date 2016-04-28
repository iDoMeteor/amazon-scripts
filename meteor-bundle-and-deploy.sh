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

# Secure exit strategy
function finito () {
  rm -rf $TEMP_DIR
}
trap finito EXIT INT TERM

# Run function
function run()
{
  echo "Running: $@"
  "$@"
}

# Check for arguments or provide help
if [ ! -n "$1" ] ; then
  echo "Usage:"
  echo "  $0 [app-dir] [-t temp-dir] [-v]"
  echo "  $0 [app-dir] [--temp temp-dir] [--verbose]"
  exit 0
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
  exit 1
fi

# Parse command line arguments into variables
while :
do
    case "$1" in
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
if [ ! -n "$TEMP_DIR" ] ; then
  TEMP_DIR=~/www/tmp
fi

# Validate temporary location
if [ -d $TEMP_DIR ] ; then
  echo "Temporary directory $TEMP_DIR already exists, please remove or rename and try again."
  exit 1
fi

# Check for verbosity
if [ -n "$VERBOSE" ] ; then
  set -v
fi

# Bundle to temporary directory
run meteor bundle --directory $TEMP_DIR

# Install dependencies
run cd $TEMP_DIR
run cd programs/server
npm install --production
npm prune --production

# Copy over persistent files for standalone mode, jic
if [ -e $APP_DIR/bundle/Passengerfile.json ]; then
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
echo "Tasks complete.  App has been deployed."
echo
echo "If this is the first app deployment, restart Nginx."
echo
echo "If this is an upgrade, run 'sudo passenger-config restart-app $APP_DIR'."
echo "After manually confirming the app is running, then remove ~/www/bundle.old."
exit 0
