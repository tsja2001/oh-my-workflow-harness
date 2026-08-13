#!/bin/bash
mkdir -p /tmp/fjlab/jars
cd /tmp/fjlab
M2=$HOME/.m2/repository
BASE=https://repo1.maven.org/maven2
get(){ [ -s "jars/$2" ] || curl -sSL --max-time 120 -o "jars/$2" "$1"; }
cp -n $M2/com/alibaba/fastjson/1.2.83/fastjson-1.2.83.jar jars/ 2>/dev/null
cp -n $M2/com/alibaba/fastjson/2.0.62/fastjson-2.0.62.jar jars/ 2>/dev/null
cp -n $M2/com/alibaba/fastjson2/fastjson2/2.0.62/fastjson2-2.0.62.jar jars/ 2>/dev/null
cp -n $M2/com/alibaba/fastjson2/fastjson2-extension/2.0.62/fastjson2-extension-2.0.62.jar jars/ 2>/dev/null
get $BASE/com/alibaba/fastjson/1.2.84/fastjson-1.2.84.jar fastjson-1.2.84.jar
get $BASE/com/alibaba/fastjson/2.0.64/fastjson-2.0.64.jar fastjson-2.0.64.jar
get $BASE/com/alibaba/fastjson2/fastjson2/2.0.64/fastjson2-2.0.64.jar fastjson2-2.0.64.jar
get $BASE/com/alibaba/fastjson2/fastjson2-extension/2.0.64/fastjson2-extension-2.0.64.jar fastjson2-extension-2.0.64.jar
ls -la jars/
