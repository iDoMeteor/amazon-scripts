#!/bin/bash
#===============================================================================
#
#          FILE: meteor-add-vhost-bundle-and-send.sh
#
#         USAGE: meteor-add-vhost-bundle-and-send.sh -n newuser -h FQDN -u user  -r remoteserver [-i key] [-b bundle-name] [-d app-dir] [-t temp-dir] [-s <settings>.json] [-f] [-v]
#                meteor-add-vhost-bundle-and-send.sh --new newuser --host FQDN --user user --remote remoteserver [--key key] [--bundle bundle-name] [--dir app-dir] [--temp temp-dir] [--settings <settings>.json] [--force] [--verbose]
#
#   DESCRIPTION:
#             From nginx-add-meteor-vhost:
#                This script will add a virtual host configuration file to
#                 the Nginx sites-available/ directory and then creates a
#                 symbolic link to that file in sites-enabled/.
#                The file is named <host>.conf and will be configured to run
#                 under the supplied user name using the app bundle in their
#                 ~/www/bundle directory.  It will be handled by Passenger
#                 and served on via regular HTTP on port 80.
#               A user will be created and the home directory will have a
#                 symblolic link named www (~/www/) that leads to their web
#                 application directory, /var/www/<user>.  Note that on my
#                 Amazon Meteor Server 1 AMI, /var/www/ is a symbolic link
#                 to /opt/www/.
#               The app will be given a Mongo database @ localhost:27017/<user>.
#             Then:
#               The script will bundle local application source, send the
#                 tarball to the new user's home directory and finally deploy
#                 by calling meteor-unbundle-and-deploy.sh.
#       OPTIONS:
#                -b | --bundle
#                   Default = 'bundle'
#                   The name of your bundle, <bundle-name>.tar.gz.
#                   I recommend making them descriptive and versioned, so
#                    that you can easily switch versions in emergencies.
#                -d | --dir
#                   Default = ./
#                   Location of your app's Meteor root (ie; has contains .meteor)
#                   If omitted, assumes that your pwd is that the app root
#                -f | --force
#                   Passing the force flag will suppress the prompt to restart
#                     nginx and just do it.
#                -h | --host
#                   * Required
#                   The fully qualified domain name of the virtual host.
#                -i | --key
#                   The SSH public key file for the given user and server.
#                -n | --new
#                   The name of the remote system account the vhost will be
#                     attributed to.
#                   If their home directory already exists, vhost creation will
#                     be skipped
#                -r | --remote
#                   The fully qualified domain name of the remote server.
#                -s | --settings
#                   Location of your app's JSON settings file, which will then
#                     be inserted into the Nginx configuration file.
#                -t | --temp
#                   Defaults = '~/www/tmp'
#                   Name of temp directory to create with meteor bundle -directory
#                -u | --user
#                   The remote user name to use when logging in with SSH.
#                -v | --verbose
#                   If passed, will show all commands executed.
#  REQUIREMENTS: Nginx, Passenger, Node 0.10.43, Meteor locally installed, ~/www/,
#                 @iDoMeteor amazon-scripts installed in user paths on the remote
#                 server as well as in ~/bin or ~/amazon/scripts on the local.
#          BUGS: ---
#         NOTES: Script will look for 'meteor-unbundle-and-deploy.sh' in the
#                 following locations in order from top to bottom:
#                   * ~/amazon/scripts/
#                   * ~/bin/
#                   * <app-dir>/private/scripts/
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
  echo "  `basename $0` -n newuser -h FQDN -u user -r remoteserver [-i key] [-b bundle-name] [-t temp-dir] [-s <settings>.json] [-f] [-v]"
  echo "  `basename $0` -new newuser --host FQDN --user user --remote remoteserver [--key key] [--bundle bundle-name] [--temp temp-dir] [--settings <settings>.json] [--force] [--verbose]"
  echo "Environment: Development"
  exit 0
fi

# Save origin
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
    DIR="$2"
    shift 2
    ;;
      -f | --force)
    FORCE="--force"
    shift 1
    ;;
      -h | --host)
    HOST="$2"
    shift 2
    ;;
      -i | --key)
    KEYFILE=$2
    shift 2
    ;;
      -n | --new)
    NEWUSER="$2"
    shift 2
    ;;
      -r | --remote)
    SERVER=$2
    shift 2
    ;;
      -s | --settings)
    SETTINGS_FILE="$2"
    shift 2
    ;;
      -S | --ssl)
    SSL=true
    shift 1
    ;;
      -t | --temp)
    TEMP_DIR=true
    shift 1
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
if [ ! -v NEWUSER ] ; then
  echo "A username is required for the vhost owner."
  exit 1
fi
if [ ! -v FORCE ] ; then
  FORCE=""
fi
if [ ! -v HOST ] ; then
  echo "A valid hostname (FQDN) is required."
  exit 1
fi
if [ ! -v REMOTEUSER ] ; then
  echo "Remote username is required to login to $SERVER."
  exit 1
fi
if [ ! -v SERVER ] ; then
  echo "Server is required."
  exit 1
fi
if [[ -v SETTINGS_FILE && -f $SETTINGS_FILE ]] ; then
  SETTINGS="--settings ~/` basename $SETTINGS_FILE`"
elif [[ -v SETTINGS_FILE && ! -f $SETTINGS_FILE ]] ; then
  echo "Settings file $SETTINGS_FILE not found."
  exit 1
else
  SETTINGS=""
fi

# Make sure we're working with a Meteor app
if [[ -v DIR && -d $DIR ]] ; then
  cd $DIR
elif [[ -v DIR && ! -d $DIR ]] ; then
  echo "You must be in, or supply, a valid Meteor app directory."
  exit 1
fi

if [ ! -d .meteor ] ; then
  echo "You must be in, or supply, a valid Meteor app directory."
  exit 1
fi

# Set necessary defaults
if [ ! -v BUNDLE ] ; then
  BUNDLE='bundle'
fi
if [ ! -v TEMP_DIR ] ; then
  TEMP_DIR=~/www/tmp
fi

# Check verbosity
if [ -v VERBOSE ] ; then
  set -v
fi

# Check for keyfile
if [[ -v KEYFILE && -f $KEYFILE ]]; then
  KEYARG="-i $KEYFILE"
else
  KEYARG=
fi

# Bundle and send
echo "Preparing to bundle your application."
meteor bundle ../$BUNDLE.tar.gz
if [ -n "$SETTINGS" ] ; then
  echo "Transferring settings file to server."
  scp $SETTINGS_FILE $REMOTEUSER@$SERVER:
fi
echo "Preparing to create user and virtual host on server."
ssh $KEYARG $REMOTEUSER@$SERVER bash nginx-add-meteor-vhost.sh -u $NEWUSER -h $HOST $SETTINGS --force
echo "Preparing to copy bundle to server."
scp $KEYARG ../$BUNDLE.tar.gz $NEWUSER@$SERVER:
echo "Preparing to unbundle application on server."
ssh $KEYARG $NEWUSER@$SERVER bash meteor-unbundle-and-deploy.sh -b $BUNDLE

# End
cd $ORIGIN
echo "All tasks complete."
if [[ '--force' = $FORCE ]] ; then
    ssh $KEYARG $REMOTEUSER@$SERVER sudo service nginx restart
else
  echo "Server processes have probably not been affected."
  read -p "Would you like me to restart the app's Passenger process for you? [y/N] " -n 1 -r REPLY
  if [[ $REPLY =~ "^[Yy]$" ]] ; then
    ssh $KEYARG $REMOTEUSER@$SERVER sudo sudo passenger-config restart-app /var/www/$NEWUSER/
  fi
  read -p "Would you like me to restart Nginx for you? [y/N] " -n 1 -r REPLY
  if [[ $REPLY =~ "^[Yy]$" ]] ; then
    ssh $KEYARG $REMOTEUSER@$SERVER sudo service nginx restart
  fi
fi
exit 0
