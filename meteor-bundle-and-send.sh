#!/bin/bash -
#===============================================================================
#
#          FILE: meteor-bundle-and-send.sh
#
#         USAGE: meteor-bundle-and-send.sh -u user -s server [-i keyfile.pem] [-b bundle-name] [-d source-dir] [-v]
#                meteor-bundle-and-send.sh --user user --server server [--key keyfile.pem] [--bundle bundle-name] [--dir source-dir] [--verbose]
#
#   DESCRIPTION: This script should generally be run on your development
#                 machine from your application's root source directory.  It
#                 will bundle your application into <bundle-name>.tar.gz and
#                 copy that file to the server along with the script to
#                 unbundle and deploy the app.
#                The file and script will be copied to the supplied user's
#                 home directory and then run the script using the supplied
#                 bundle name as its sole parameter.
#                The meteor-unbundle-and-deploy.sh script is expected to be
#                 in your app's /private/ directory (where this one probably
#                 is).
#       OPTIONS:
#                -b | --bundle
#                   Default: 'bundle'
#                   The name of your bundle, <bundle-name>.tar.gz.
#                   I recommend making them descriptive and versioned, so
#                    that you can easily switch versions in emergencies.
#                -d | --dir
#                   Default: ./
#                   Location of your app's source root (ie; contains .meteor)
#                   If omitted, assumes that your PWD is that directory
#                -i | --key
#                   The SSH public key file for the given user and server.
#                -s | --server
#                   The fully qualified domain name of the remote server.
#                -u | --user
#                   The name of the system account the host will be attributed to.
#                -v | --verbose
#                   If passed, will show all commands executed.
#  REQUIREMENTS: Node, Meteor, SSH/SCP, remote shell access
#          BUGS: Keyfile issues
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
  echo "  `basename $0` -u user -s server [-i keyfile.pem] [-b bundle-name] [-v]"
  echo "  `basename $0` --user user --server server [--key keyfile.pem] [--bundle bundle-name] [--verbose]"
  echo "This should be run from your development environment."
  echo "Also, meteor-unbundle-and-deploy.sh should be in the remote user's path."
  exit 0
fi

# Check Node version
NODE_VERSION=`node --version`
if [[ ! $NODE_VERSION =~ ^v0\.10\.4 ]] ; then
  echo "You should bundle Meteor apps with Node v0.10.4x."
  echo "You are using Node $NODE_VERSION, please correct this and try again."
  echo "You may switch to the tested & installed Meteor-friendly version with 'sudo n 0.10.43' using the ec2-user account."
  read -p "Would you still like to try anyway? [y/N]" -n 1 -r REPLY
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]] ; then
    echo "Exiting without action."
    exit 1
  fi
fi

# Save PWD
ORIGIN=`pwd`

# Parse command line arguments into variables
while :
do
    case ${1:-} in
      -b | --bundle)
    BUNDLE="$2"
    shift 2
    ;;
      -d | --dir)
    SRC_DIR=$2
    shift 2
    ;;
      -i | --key)
    KEYFILE=$2
    shift 2
    ;;
      -s | --server)
    SERVER=$2
    shift 2
    ;;
      -u | --user)
    REMOTEUSER="$2"
    shift 2
    ;;
      -v | --verbose)
    VERBOSE=true
    shift 1
    ;;
      -*)
    echo "Error: Unknown option: $1" >&2
    cd $ORIGIN
    exit 1
    ;;
      *)  # No more options
    break
    ;;
    esac
done

# Validate required arguments
if [ ! -v REMOTEUSER ] ; then
  echo "User is required."
  cd $ORIGIN
  exit 1
fi
if [ ! -v SERVER ] ; then
  echo "Server is required."
  cd $ORIGIN
  exit 1
fi

# Set defaults if required
if [ ! -v BUNDLE ] ; then
  BUNDLE='bundle'
fi
if [ -v SRC_DIR ] ; then
  if [ -d $SRC_DIR ] ; then
    cd $SRC_DIR
  else
    echo "Source directory $SRC_DIR is invalid."
    cd $ORIGIN
    exit 1
  fi
fi
if [ ! -d .meteor ] ; then
  echo "You must be in, or supply, a valid Meteor app directory."
  cd $ORIGIN
  exit 1
fi

# Check for verbosity
if [ -v VERBOSE ] ; then
  set -v
fi

# Check for keyfile
if [[ -v KEYFILE && -f $KEYFILE ]]; then
  KEYARG="-i $KEYFILE"
else
  KEYARG=
fi

echo "Preparing $BUNDLE.tar.gz"
meteor bundle ../$BUNDLE.tar.gz
scp $KEYARG ../$BUNDLE.tar.gz $REMOTEUSER@$SERVER:
ssh $KEYARG $REMOTEUSER@$SERVER meteor-unbundle-and-deploy.sh -b $BUNDLE

# End
cd $ORIGIN
echo "Local tasks complete."
echo ""
read -p "Would you like me to restart the app's Passenger process for you? [y/N] " -n 1 -r REPLY
if [[ $REPLY =~ "^[Yy]$" ]] ; then
  run ssh $KEYARG ec2-user@$SERVER sudo sudo passenger-config restart-app /var/www/$NEWUSER/
fi
echo ""
read -p "Would you like me to restart Nginx for you? [y/N] " -n 1 -r REPLY
if [[ $REPLY =~ "^[Yy]$" ]] ; then
  run ssh $KEYARG ec2-user@$SERVER sudo service nginx restart
fi
echo ""
exit 0
