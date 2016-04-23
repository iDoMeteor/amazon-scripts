#!/bin/bash -
#===============================================================================
#
#          FILE: ec2-prep-for-distro
#
#         USAGE: ec2-prep-for-distro [-v]
#
#   DESCRIPTION: This script prepares an Amazon Linux instance for public
#                 distrobution by securing the SSH daemon, removing all logs
#                 histories, *KEYS* and other extraneous potentially sensitive
#                 data as well as *locking all user account passwords*.
#               It does not ask for any confirmation, so you really, REALLY,
#                 REALLY should *NOT* run this if you are not *SUPER DUPER SURE*
#                 that you know what it does and that you want to do it!!!
#               As this is such a critical script, I shall outline the actions
#                 that it performs in detail:
#                   * It unsets the Bash history file and clears current history
#                   * It stops the Passenger, Nginx and Mongo services,
#                     in that order
#                   * It changes, in place without back up, /etc/ssh/sshd_config
#                     in the following ways:
#                       * It changes the login grace time to 20 seconds
#                       * It globally disables password authentication
#                       * It globally disables root login
#                       * It enables public key authentication
#                       * It disables DNS lookups
#                   * It locks the passwords for the root user as well as all
#                     users who have a directory in /home/
#                   * It shreds the following files:
#                       * /etc/syslog.conf
#                       * All *key* files from /etc/ssh/
#                       * All .*history files on disk
#                       * All .vim* files from all users
#                       * All files and directories from /tmp/
#                       * All files and directories from /var/cache/
#                       * All files and directories from /var/mail/
#                       * All files and directories from /var/spool/mail/
#                       * All files and directories from /var/tmp/
#                       * All files from all users' .ssh/
#                     and then removes all sub-directories from them where
#                     appropriate
#                   * It shreds all files in /var/lib/mongo except files that
#                     begin with 'default_site'
#                   * It connects to Mongo and removes all collections except for
#                     the 'opw-rows' collection, which contains the default web
#                     site content for my Amazon AMI image
#                   * Disables & shreds /swap and/or /swp
#                   * Lastly, shreds everything in /var/log/, removes all sub-dirs
#                     and clears the history one final time!
#               When all of this is complete, you should immediately shut
#               down the instance and create your image, lest you begin
#               to create a new paper trail! :)
#
#       OPTIONS:
#                -v | --verbose
#                   If passed, will show all commands as they are executed.
#  REQUIREMENTS: (Amazon) Linux, shred, sudo privileges
#          BUGS: ---
#         NOTES: This should do a pretty good job on most other distros as well,
#                 such as Ubuntu or Redhat, etc. as it does not hit the package
#                 manager in any way.  It mostly just searches the file system
#                 for standard filenames and locations and shreds them.  As for
#                 SSH, sshd_config lives in /etc/ssh/ in every system I've ever
#                 used!
#        AUTHOR: Jason White (Jason@iDoAWS.com),
#  ORGANIZATION: @iDoAWS
#       CREATED: 04/15/2016 15:32
#      REVISION:  001
#===============================================================================

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Confirm that the user really wants to do this
read -p "Are you sure you wish to anonymize this volume? [y/N] " -n 1 -r REPLY
if [[ $REPLY =~ ^[Yy]$ ]]
  echo "Proceeding to cleanse volume data."
else
  exit 0
fi

# Stop tracking & clear history
unset HISTFILE
history -c

# Check verbosity
if [[ $1 eq '-v']] ; then
  set -v
fi

# Stop services
sudo passenger stop
sudo service nginx stop
sudo service mongod stop

# Secure SSH
sudo sed -i "s/^#?LoginGraceTime .*/LoginGraceTime 20s/" /etc/ssh/sshd_config
sudo sed -i "s/^#?PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config
sudo sed -i "s/^#?PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
sudo sed -i "s/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sudo sed -i "s/^#?UseDNS .*/UseDNS no/" /etc/ssh/sshd_config

# Lock all account passwords
sudo passwd -l root
for i in /home/* ; do
  if [ -d "$i" ] ; then
    sudo passwd -l $(basename "$i")
  fi
done

# Shred logs, histories, keys, caches, tmps, etc
sudo find / -name .*history -exec shred -fuz {} +
sudo find /etc/ssh/*key* -exec shred -fuz {} +
sudo find /etc/syslog.conf -exec shred -fuz {} +
sudo find /root/.ssh/ /home/*/.ssh/ -exec shred -fuz {} +
sudo find /root/.vim* /home/*/.vim* -exec shred -fuz {} +
sudo find /tmp -exec shred -fuz {} +
sudo find /var/cache -exec shred -fuz {} +
sudo find /var/cache -exec shred -fuz {} +
sudo find /var/lib/yum/history -exec shred -fuz {} +
sudo find /var/mail -exec shred -fuz {} +
sudo find /var/spool/mail -exec shred -fuz {} +
sudo find /var/tmp -exec shred -fuz {} +

# Remove what should now be empty directories
sudo rm -rf /tmp/*
sudo rm -rf /var/cache/*
sudo rm -rf /var/mail/*
sudo rm -rf /var/spool/mail/*
sudo rm -rf /var/tmp/*

# Shred all Mongo DBs & journal except for default_site's
for i in /var/lib/mongo ; do
  if [[ ! i =~ "^default_site" ]] ; then
    if [ -f i ] ; then
      sudo shred -rf i
    elif [ -d i ] ; then
      find i -exec sudo shred -fuz {} +
    fi
  fi
done

# Remove all non-row documents from default_site's DB
mongo --eval '
use default_site;
var collections = db.getCollectionNames;
collections.forEach(
  function (c) {
    if ('opw-rows' != c) {
      db[c].remove({});
    }
  }
  db.runCommand({compact: 'default_site'});
);
'

# Shred swap
sudo swapoff -a
if [ -f /swap ] ; then
  sudo shred -fuz /swap
fi
if [ -f /swp ] ; then
  sudo shred -fuz /swp
fi

# End
echo "Tasks complete.  Volume is ready for imaging."
echo "You should immediately run 'sudo shutdown -h now; kill -9 $$' and create your image!"
history -c
sudo find /var/log -exec shred -fuz {} + && sudo rm -rf /var/log/* && sudo history -c
exit 0
