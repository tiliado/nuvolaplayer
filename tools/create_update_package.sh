#!/bin/bash

# Copyright 2011-2014 Jiří Janoušek <janousek.jiri@gmail.com>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met: 
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer. 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution. 
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

set -eu

WD=$PWD
RESULT="$(readlink -f "$1")"
shift

for WEB_APP_DIR in "$@"; do

  cd "$WD"
  cd "$WEB_APP_DIR"
  cd ..
  
  WEB_APP=`basename "$WEB_APP_DIR"`
  MAJOR=`"$WD/tools/print_json.py" "$WEB_APP/metadata.json" version_major`
  MINOR=`"$WD/tools/print_json.py" "$WEB_APP/metadata.json" version_minor`
  NAME=`"$WD/tools/print_json.py" "$WEB_APP/metadata.json" name`
  TAR="$RESULT/nuvolaplayer--$WEB_APP-$MAJOR.$MINOR.tar"
  
  echo "format = 3" > control
  echo "app_id = $WEB_APP" >> control
  echo $TAR:
  tar cvf $TAR $WEB_APP control
  rm -f control 
  gzip -9 -f $TAR
  cd "$WD"
done
