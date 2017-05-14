#!/bin/bash
set -eu
WD="$PWD"
VERSION="$1"
BUNDLE_FLAGS="--tools=valadoc"
WAF_URL="https://github.com/waf-project/waf/archive/waf-${VERSION}.tar.gz"
WAF_TMP="/tmp/waflight"
rm -rf "$WAF_TMP"
mkdir "$WAF_TMP"
cd "$WAF_TMP"
wget "$WAF_URL"
tar -xzf "waf-${VERSION}.tar.gz"
echo "> ls $PWD"
ls
cd "waf-waf-${VERSION}"
echo "> ls $PWD"
ls
python3 ./waf-light $BUNDLE_FLAGS
sed -i "s#/usr/bin/env python#/usr/bin/env python3#" waf
head -n1 waf
mv waf "$WD/waf"
chmod a+x "$WD/waf"
rm -rf "$WAF_TMP"
