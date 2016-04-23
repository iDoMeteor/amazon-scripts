# Amazon Linux Scripts by @iDoMeteor/@iDoAWS

## TL;DR

A set of scripts for creating Nginx/Passenger virtual host files for Node/Meteor
as well as bundling, transferring and deploying Meteor applications.

Written for use on my [Amazon Linux 03.06 Node/Meteor Server]() but should work on
most standard distros.

## Scripts Included

Server scripts:
* ec2-prep-for-distro.sh
* meteor-add-vhost-clone-and-deploy.sh
* meteor-bundle-and-deploy.sh
* meteor-unbundle-and-deploy.sh
* nginx-add-meteor-vhost.sh
* nginx-add-node-vhost.sh

Remote scripts:
* meteor-add-vhost-send-and-deploy.sh
* meteor-bundle-and-send.sh

Coming Soon:
* route53-add-domains
* route53-delete-domains
* route53-list-domains
* route53-list-records

The easy way to remember to remember which to run where?

If it has 'send' in the name, then it should not be run from the server because
it wouldn't have to send anything anywhere! :)

**All scripts** output usage info if you run them without any arguments.

**You must read** the header comments in each script for a detailed description
of what they do and what arguments they take.

### ec2-prep-for-distro.sh

**DO NOT RUN THIS SCRIPT** unless you **seriously** know what you are doing! |D

This script will attempt to completely anonymize my Amazon Linux AMI, and will
do a pretty good job on any Linux based Nginx/Mongo based server.

It will also perform some basic security hardening such as **locking all account
passwords**, **disabling SSH password logins**, and **shreds** all **keys**,
**logs** and **histories**.

**Caveats**

The script leaves behind a few vital goodies:
* These scripts in /usr/local/bin and /usr/local/bin/.git for pulling updates on
  boot
* The 'default_site' user account, the #OnePageWonder row content in its Mongo
  database, it's virtual host file and it's app in /var/www/default_site/

It does not wipe free space, since imaging leaves it behind anyway.

### meteor-add-vhost-clone-and-deploy.sh

*Environment: Server*
* Runs nginx-add-meteor-vhost
* Changes to the new user
* Clones the given repository or pulls from the default remote
* Bundles the application
* Deploys the app in the user's ~/www
* Offers to restart services

### meteor-add-vhost-send-and-deploy.sh

*Environment: Developer*
* Runs nginx-add-meteor-vhost on the server
* Bundles the local application
* Sends it to the new user's account
* Runs meteor-unbundle-and-deploy


### meteor-bundle-and-deploy.sh

*Environment: Server*
* Bundles the application
* Deploys the app in the user's ~/www
* Saves previous ~/www/bundle to ~/www/bundle.old
* Offers to restart services


### meteor-bundle-and-send.sh

*Environment: Developer*
* Bundles the local application
* Sends it to the new user's account
* Runs meteor-unbundle-and-deploy


### meteor-unbundle-and-deploy.sh

*Environment: Server*
* Unbundles the application
* Deploys the app in the user's ~/www
* Saves previous ~/www/bundle to ~/www/bundle.old
* Offers to restart services


### nginx-add-meteor-vhost.sh

*Environment: Server*
* Creates an Nginx/Passenger/Node 0.10.4x/Meteor virtual host .conf file in /etc/nginx/sites-available
* Creates a symbolic link to the above file in /etc/nginx/sites-enabled
* Restarts Nginx


### nginx-add-node-vhost.sh

*Environment: Server*
* Creates an Nginx/Passenger/Node 5.x virtual host .conf file in /etc/nginx/sites-available
* Creates a symbolic link to the above file in /etc/nginx/sites-enabled
* Restarts Nginx


## TODO
### route53-add-domain
### route53-add-domain
### route53-delete-domain
### route53-list-domains
### route53-list-records


## Feedback

I love feedback & comments on Twitter via
[@iDoAWS](https://twitter.com/iDoAWS) or
[@iDoMeteor](https://twitter.com/iDoMeteor).  Bug reports and feature requests
can be submitted via [Github
issues](https://github.com/idometeor/amazon-scripts/issues).

For private communique, hit me up @ Gmail.
