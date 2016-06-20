#!/bin/bash
# TODO: Add -h option!
ORIGIN=`pwd`
/usr/local/bin/meteor-git-and-deploy.sh -r https://github.com/RocketChat/Rocket.Chat -d rocketchat
cd $ORIGIN
