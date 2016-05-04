#!/bin/bash -
#===============================================================================
#
#          FILE: meteor-unbundle-and-deploy.sh
#
#         USAGE: meteor-unbundle-and-deploy.sh -b bundle-name [-v]
#                meteor-unbundle-and-deploy.sh --bundle bundle-name [--verbose]
#
#   DESCRIPTION: This script untars a tarball bundled by Meteor to a temporary
#                 location, runs node install & prune, and then replaces an
#                 existing bundle with the new one.
#                Once this is complete, the script will restart the app's
#                 Passenger process and remove's the temporary directory.
#                It is left to the user to remove the replaced bundle, which
#                 will be renamed bundle.old.
#                This script will generally be run automatically by the remote
#                 developer's meteor-bundle-and-send script.
#       OPTIONS:
#                -b | --bundle
#                   The name of your bundle, <bundle-name>.tar.gz.
#                   I recommend making them descriptive and versioned, so
#                    that you can easily switch versions in emergencies.
#                -v | --verbose
#                   If passed, will show all commands executed.
#  REQUIREMENTS: Node 0.10.43, Passenger
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jason White (Jason@iDoAWS.com),
#  ORGANIZATION: @iDoAWS
#       CREATED: 04/12/2016 12:08
#      REVISION:  001
#===============================================================================

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Check for arguments or provide help
if [ $# -eq 0 ] ; then
  echo "Usage:"
  echo "  `basename $0` -b bundle-name [-v]"
  echo "  `basename $0` --bundle bundle-name [--verbose]"
  echo "This should be run on your staging or production server."
  exit 0
fi

cd ~/www

APP_DIR=`pwd`

# Parse command line arguments into variables
while :
do
    case ${1:-} in
      -b | --bundle)
    BUNDLE="$2"
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
if [ ! -v BUNDLE ] ; then
  echo 'Bundle name is required.'
  exit 1
fi

# Check for verbosity
if [ -v VERBOSE ] ; then
  set -v
fi

# Extract newly uploaded package
if [ -d ./tmp ] ; then
  rm -rf ./tmp
fi
mkdir tmp
cd tmp
tar xzf ~/$BUNDLE.tar.gz
rm ~/$BUNDLE.tar.gz

# Install dependencies
cd bundle/programs/server
npm install --production
npm prune --production

# Copy over persistent files for standalone mode, jic
if [ -f $APP_DIR/bundle/Passengerfile.json ]; then
  cp $APP_DIR/bundle/Passengerfile.json $APP_DIR/tmp/bundle/
fi

# Switch directories, restart app
cd $APP_DIR
if [[ -d ./tmp && -d bundle ]] ; then
  mv bundle bundle.old
  PRE_EXIST=true
fi
mv tmp/bundle bundle
rm -rf tmp

cd

# End
if [ -v PRE_EXIST ] ; then
  echo ""
  echo ""
  echo "This appears to be an upgrade, run 'sudo passenger-config restart-app $APP_DIR'."
  echo "After manually confirming the app is running, then remove ~/www/bundle.old."
else
  echo ""
  echo ""
  echo "This appears to be the first app deployment, restart Nginx for changes to take affect."
fi
echo "Remote tasks complete.  App has been deployed."
echo ""
exit 0
