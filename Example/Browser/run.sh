#!/bin/sh

#  run.sh
#  SignalingServer
#
#  Created by Desnos on 01/12/2014.
#
export PATH=$PATH:/usr/local/bin
echo $PATH

SOURCE="${BASH_SOURCE[0]}"
PROJECT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

cd $PROJECT_DIR
echo $PWD

npm install socket.io-client
npm install socket.io
npm install socket.io-stream
npm install browserify-fs

browserify browser.js -o bundle.js
open index.html -a "Google Chrome"