#!/bin/bash -
#===============================================================================
#
# Add -d | --dir
#
#
#          FILE: meteor-bundle-and-send.sh
#
#         USAGE: meteor-bundle-and-send.sh -u user -s server [-i keyfile.pem] [-b bundle-name] [-v]
#                meteor-bundle-and-send.sh --user user --server server [--key keyfile.pem] [--bundle bundle-name] [--verbose]
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
#                -i | --key
#                   The SSH public key file for the given user and server.
#                -s | --server
#                   The fully qualified domain name of the remote server.
#                -u | --user
#                   The name of the system account the host will be attributed to.
#                -v | --verbose
#                   If passed, will show all commands executed.
#  REQUIREMENTS: Node, Meteor, SSH/SCP, remote shell access
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
  echo "  `basename $0` -u user -s server [-i keyfile.pem] [-b bundle-name] [-v]"
  echo "  `basename $0` --user user --server server [--key keyfile.pem] [--bundle bundle-name] [--verbose]"
  echo "This should be run from your development environment."
  exit 0
fi

# Debug buffer
function run()
{
  if [ -v $DEBUG ] ; then
    echo "Running: $@"
  fi
  "$@"
}

# Parse command line arguments into variables
while :
do
    case ${1:-} in
      -b | --bundle)
    BUNDLE="$2"
    shift 2
    ;;
      --debug)
    DEBUG=true
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
  exit 1
fi
if [ ! -v SERVER ] ; then
  echo "Server is required."
  exit 1
fi

# Set defaults if required
if [ ! -v BUNDLE ] ; then
  BUNDLE='bundle'
fi

# Check for verbosity
if [ -v VERBOSE ] ; then
  set -v
fi

# Check for keyfile
if [[ -f $KEYFILE ]]; then
  KEYARG="-i $KEYFILE"
else
  KEYARG=
fi

run meteor bundle ../$BUNDLE.tar.gz
run scp $KEYARG ../$BUNDLE.tar.gz $REMOTEUSER@$SERVER:
run scp $KEYARG private/amazon/meteor-unbundle-and-deploy.sh $REMOTEUSER@$SERVER:
run ssh $KEYARG $REMOTEUSER@$SERVER bash meteor-unbundle-and-deploy.sh -b $BUNDLE

# End
echo "Local tasks complete."
exit 0
