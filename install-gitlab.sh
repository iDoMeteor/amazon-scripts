#!/bin/bash -
#===============================================================================
#
#          FILE: install-gitlab.sh
#
#         USAGE: install-gitlab.sh -h hostname [-m hostname] [-v]
#                install-gitlab.sh --host hostname [--mm hostname] [--verbose]
#
#   DESCRIPTION: This script will install Gitlab into /opt, and be made
#                 accessible via the hostname provided.  The Mattermost chat
#                 server will also be installed if you provide a hostname for
#                 it.
#       OPTIONS:
#                -h | --host
#                   The fully qualified domain name of the virtual host you wish
#                     to use to access GitLab.
#                -m | --mm
#                   The fully qualified domain name of the virtual host you wish
#                     to use to access Mattermost chat server.  If not supplied,
#                     Mattermost will not be enabled.
#                -v | --verbose
#                   If passed, will show all commands executed.
#  REQUIREMENTS: Nginx, Passenger, Yum
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jason White (Jason@iDoAWS.com),
#  ORGANIZATION: @iDoAWS
#       CREATED: 05/17/2016 22:33
#      REVISION:  001
#===============================================================================

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Check for arguments or provide help
if [ $# -eq 0 ] ; then
  echo "Usage:"
  echo "  `basename $0` -h hostname [-m hostname] [-v]"
  echo "  `basename $0` --host host name [--mm hostname] [--verbose]"
  echo "This should be run on your staging or production server."
  exit 0
fi

# Parse command line arguments into variables
while :
do
    case ${1:-} in
      -h | --host)
    HOST="$2"
    shift 2
    ;;
      -m | --mm)
    MM_HOST="$2"
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
if [ ! -v HOST ] ; then
  echo 'Host name is required.'
  exit 1
else
  URL="http://$HOST"
fi
if [ -v MM_HOST ] ; then
  MM_URL="http://$MM_HOST"
fi
if [ -f /etc/nginx/sites-available/$HOST\.conf ] ; then
  echo 'Virtual host configuration already exists.'
  exit 1
fi
if [ -L /etc/nginx/sites-enabled/$HOST\.conf ] ; then
  echo 'Virtual host configuration is already enabled.'
  exit 1
fi

# Check verbosity
if [ -v VERBOSE ] ; then
  set -v
fi

# Check for Gitlab Repo
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash

# Run Yum installer
sudo yum install gitlab-ce -y

# Configure Gitlab to use our pre-existing services
# http://docs.gitlab.com/omnibus/settings/nginx.html#using-an-existing-passengernginx-installation
echo "
## Disable internal servers
nginx['enable'] = false
unicorn['enable'] = false
gitlab_rails['internal_api_url'] = '$URL'
" | sudo tee -a /etc/gitlab/gitlab.rb

# Mattermost
if [ -v MM_URL ] ; then
echo "
## Enable Mattermost
mattermost_external_url '$MM_URL'
" | sudo tee -a /etc/gitlab/gitlab.rb
fi

# Recompile Gitlab
sudo gitlab-ctl reconfigure

# Create & enable virtual host
echo "upstream gitlab-workhorse {
  server unix://var/opt/gitlab/gitlab-workhorse/socket fail_timeout=0;
}

server {
  listen *:80;
  server_name $HOST;
  server_tokens off;
  root /opt/gitlab/embedded/service/gitlab-rails/public;

  client_max_body_size 250m;

  access_log  /var/log/gitlab/nginx/gitlab_access.log;
  error_log   /var/log/gitlab/nginx/gitlab_error.log;

  # Ensure Passenger uses the bundled Ruby version
  passenger_ruby /opt/gitlab/embedded/bin/ruby;

  # Correct the PATH variable to included packaged executables
  passenger_env_var PATH "/opt/gitlab/bin:/opt/gitlab/embedded/bin:/usr/local/bin:/usr/bin:/bin";

  # Make sure Passenger runs as the correct user and group to
  # prevent permission issues
  passenger_user git;
  passenger_group git;

  # Enable Passenger & keep at least one instance running at all times
  passenger_enabled on;
  passenger_min_instances 1;

  location ~ ^/[\w\.-]+/[\w\.-]+/(info/refs|git-upload-pack|git-receive-pack)$ {
    # 'Error' 418 is a hack to re-use the @gitlab-workhorse block
    error_page 418 = @gitlab-workhorse;
    return 418;
  }

  location ~ ^/[\w\.-]+/[\w\.-]+/repository/archive {
    # 'Error' 418 is a hack to re-use the @gitlab-workhorse block
    error_page 418 = @gitlab-workhorse;
    return 418;
  }

  location ~ ^/api/v3/projects/.*/repository/archive {
    # 'Error' 418 is a hack to re-use the @gitlab-workhorse block
    error_page 418 = @gitlab-workhorse;
    return 418;
  }

  # Build artifacts should be submitted to this location
  location ~ ^/[\w\.-]+/[\w\.-]+/builds/download {
      client_max_body_size 0;
      # 'Error' 418 is a hack to re-use the @gitlab-workhorse block
      error_page 418 = @gitlab-workhorse;
      return 418;
  }

  # Build artifacts should be submitted to this location
  location ~ /ci/api/v1/builds/[0-9]+/artifacts {
      client_max_body_size 0;
      # 'Error' 418 is a hack to re-use the @gitlab-workhorse block
      error_page 418 = @gitlab-workhorse;
      return 418;
  }

  location @gitlab-workhorse {

    ## https://github.com/gitlabhq/gitlabhq/issues/694
    ## Some requests take more than 30 seconds.
    proxy_read_timeout      300;
    proxy_connect_timeout   300;
    proxy_redirect          off;

    # Do not buffer Git HTTP responses
    proxy_buffering off;

    proxy_set_header    Host                \$http_host;
    proxy_set_header    X-Real-IP           \$remote_addr;
    proxy_set_header    X-Forwarded-For     \$proxy_add_x_forwarded_for;
    proxy_set_header    X-Forwarded-Proto   \$scheme;

    proxy_pass http://gitlab-workhorse;

    ## The following settings only work with NGINX 1.7.11 or newer
    #
    ## Pass chunked request bodies to gitlab-workhorse as-is
    # proxy_request_buffering off;
    # proxy_http_version 1.1;
  }

  ## Enable gzip compression as per rails guide:
  ## http://guides.rubyonrails.org/asset_pipeline.html#gzip-compression
  ## WARNING: If you are using relative urls remove the block below
  ## See config/application.rb under "Relative url support" for the list of
  ## other files that need to be changed for relative url support
  location ~ ^/(assets)/ {
    root /opt/gitlab/embedded/service/gitlab-rails/public;
    gzip_static on; # to serve pre-gzipped version
    expires max;
    add_header Cache-Control public;
  }

  error_page 502 /502.html;
}" | sudo tee /etc/nginx/sites-available/$HOST.conf
sudo ln -s /etc/nginx/sites-available/$HOST.conf /etc/nginx/sites-enabled/$HOST.conf

# Add Nginx user to gitlab-www
sudo usermod -aG gitlab-www nginx

# Restart Nginx
sudo service nginx restart

echo
echo "Gitlab has been successfully installed, visit the URL below to get started!"
echo "$URL"
echo
