#!/bin/bash
cd /tmp/fjlab
mkdir -p jars out
M2=$HOME/.m2/repository
BASE=https://repo1.maven.org/maven2

get() { # url file
  [ -s "jars/$2" ] || curl -sSL --max-time 90 -o "jars/$2" "$1"
}
echo "===== 准备 jar ====="
# 1.2.83 从本地 m2
cp -n $M2/com/alibaba/fastjson/1.2.83/fastjson-1.2.83.jar jars/ 2>/dev/null
cp -n $M2/com/alibaba/fastjson/2.0.62/fastjson-2.0.62.jar jars/ 2>/dev/null
cp -n $M2/com/alibaba/fastjson2/fastjson2/2.0.62/fastjson2-2.0.62.jar jars/ 2>/dev/null
cp -n $M2/com/alibaba/fastjson2/fastjson2-extension/2.0.62/fastjson2-extension-2.0.62.jar jars/ 2>/dev/null
get $BASE/com/alibaba/fastjson/1.2.84/fastjson-1.2.84.jar fastjson-1.2.84.jar
get $BASE/com/alibaba/fastjson/2.0.64/fastjson-2.0.64.jar fastjson-2.0.64.jar
get $BASE/com/alibaba/fastjson2/fastjson2/2.0.64/fastjson2-2.0.64.jar fastjson2-2.0.64.jar
get $BASE/com/alibaba/fastjson2/fastjson2-extension/2.0.64/fastjson2-extension-2.0.64.jar fastjson2-extension-2.0.64.jar
ls -la jars/

CP183=jars/fastjson-1.2.83.jar
CP184=jars/fastjson-1.2.84.jar
CP2062="jars/fastjson-2.0.62.jar:jars/fastjson2-2.0.62.jar:jars/fastjson2-extension-2.0.62.jar"
CP2064="jars/fastjson-2.0.64.jar:jars/fastjson2-2.0.64.jar:jars/fastjson2-extension-2.0.64.jar"

run() { # name cp extra
  echo ""
  echo "##################################################################"
  echo "###############  $1  $3"
  echo "##################################################################"
  rm -rf out; mkdir -p out
  javac -nowarn -encoding UTF-8 -cp "$2" -d out Probe.java 2>&1 | head -20
  if [ ! -f out/Probe.class ]; then echo "!!! 编译失败（这本身就是结论：源码在这个版本上编译不过）"; return; fi
  java $3 -Dfile.encoding=UTF-8 -cp "$2:out" Probe 2>&1
}

run "fastjson 1.2.83  (当前生产版本)" "$CP183"
run "fastjson 1.2.84  (1.x 安全修复版)" "$CP184"
run "fastjson 2.0.62  (上次升级踩坑版)" "$CP2062"
run "fastjson 2.0.64  (2.x 最新)" "$CP2064"
run "fastjson 2.0.64 + SafeMode" "$CP2064" "-Dfastjson2.parser.safeMode=true"
run "fastjson 1.2.84 + SafeMode" "$CP184" "-Dfastjson.parser.safeMode=true"
