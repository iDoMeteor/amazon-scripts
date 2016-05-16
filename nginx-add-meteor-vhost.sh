#!/bin/bash -
#===============================================================================
#
#          FILE: nginx-add-meteor-vhost
#
#         USAGE: nginx-add-meteor-vhost -u user -h host [-s <settings>.json] [-f] [-v]
#                nginx-add-meteor-vhost --user user --host host [--settings <settings>.json] [--force] [--verbose]
#
#   DESCRIPTION: This script will add a virtual host configuration file to
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
#       OPTIONS:
#                -f | --force
#                   Passing the force flag will suppress the prompt to restart
#                     nginx and just do it.
#                -h | --host
#                   The fully qualified domain name of the virtual host.
#                -s | --settings
#                   XXX
#                -u | --user
#                   The name of the system account the host will be attributed to.
#                -v | --verbose
#                   If passed, will show all commands executed.
#  REQUIREMENTS: Nginx, Passenger, Node 0.10.40 managed by N, Mongo, ~/www/,
#                 /etc/nginx/sites-available/, /etc/nginx/sites-enabled/,
#                 /var/www/, sudo privileges.
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jason White (Jason@iDoAWS.com),
#  ORGANIZATION: @iDoAWS
#       CREATED: 04/15/2016 15:33
#      REVISION:  001
#          TODO: Add -S option to enable commented lines and do SSL work
#===============================================================================

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Check for arguments or provide help
if [ $# -eq 0 ] ; then
  echo "Usage:"
  echo "  `basename $0` -u user -h host [-s <settings>.json] [-f] [-v]"
  echo "  `basename $0` --user user --host host [--settings <settings>.json] [--force] [--verbose]"
  echo "This should be run on your staging or production server."
  exit 0
fi

# Parse command line arguments into variables
while :
do
    case ${1:-} in
      -f | --force)
    FORCE=true
    shift 1
    ;;
      -h | --host)
    HOST="$2"
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

# Validate arguments
if [ ! -v USERNAME ] ; then
  echo 'User name is required.'
  exit 1
fi
if [ 0 -ne $(getent passwd $USERNAME | wc -l) ] ; then
  echo 'PAM user already exists.'
  exit 1
fi
if [ -d /home/$USERNAME ] ; then
  echo 'User home directory already exists.'
  exit 1
fi
if [ -d /var/www/$USERNAME ] ; then
  echo 'User web directory already exists.'
  exit 1
fi
if [ ! -v HOST ] ; then
  echo 'Host name is required.'
  exit 1
fi
if [ -f /etc/nginx/sites-available/$HOST\.conf ] ; then
  echo 'Virtual host configuration already exists.'
  exit 1
fi
if [ -L /etc/nginx/sites-enabled/$HOST\.conf ] ; then
  echo 'Virtual host configuration is already enabled.'
  exit 1
fi
if [[ -v SETTINGS_FILE && -f $SETTINGS_FILE ]] ; then
  SETTINGS=`cat $SETTINGS_FILE`
elif [[ -v SETTINGS_FILE && ! -f $SETTINGS_FILE ]] ; then
  echo "Settings file $SETTINGS_FILE not found."
  exit 1
else
  SETTINGS=""
fi

# Check verbosity
if [ -v VERBOSE ] ; then
  set -v
fi

# Add $USERNAME and setup home dir
sudo adduser $USERNAME
sudo mkdir /home/$USERNAME/.ssh
sudo mkdir /var/www/$USERNAME
sudo cp ~/.ssh/authorized_keys /home/$USERNAME/.ssh/
sudo ln -s /var/www/$USERNAME /home/$USERNAME/www
sudo chown -R $USERNAME: /home/$USERNAME/
sudo chown -R $USERNAME: /var/www/$USERNAME

# Create /etc/nginx/sites-available/$HOST.conf
echo "server {
    server_name $HOST;
    root /var/www/$USERNAME/bundle/public;

    listen 80;
    # listen 443 ssl;

    passenger_enabled on;
    passenger_app_type node;
    passenger_startup_file main.js;
    passenger_nodejs /usr/local/n/versions/node/0.10.43/bin/node;
    passenger_sticky_sessions on;

    # ssl_certificate      /etc/ssl/$HOST.crt;
    # ssl_certificate_key  /etc/ssl/$HOST.key;

    passenger_env_var MONGO_URL mongodb://localhost:27017/$USERNAME;
    passenger_env_var ROOT_URL http://$HOST;
    passenger_env_var METEOR_SETTINGS $SETTINGS;

}" | sudo tee /etc/nginx/sites-available/$HOST.conf

# Enable
sudo ln -s /etc/nginx/sites-available/$HOST.conf /etc/nginx/sites-enabled/$HOST.conf

# End
echo "Tasks complete.  Nginx will need to be restarted in order to take effect."
if [ -v FORCE ] ; then
    sudo service nginx restart
else
  read -p "Would you like me to restart Nginx for you? [y/N] " -n 1 -r REPLY
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    sudo service nginx restart
  fi
fi
exit 0
