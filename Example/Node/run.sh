#!/bin/sh

#  run.sh
#  TestServer
#
#  Created by Desnos on 01/12/2014.
#
export PATH=$PATH:/usr/local/bin
echo $PATH

SOURCE="${BASH_SOURCE[0]}"
PROJECT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

cd $PROJECT_DIR
echo $PWD
pkill -f node

npm install --save socket.io
node App.js