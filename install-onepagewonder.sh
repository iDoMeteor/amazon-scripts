#!/bin/bash
ORIGIN=`pwd`
/usr/local/bin/meteor-git-and-deploy.sh -r https://github.com/idometeor/onepagewonder -d onepagewonder
cd $ORIGIN
