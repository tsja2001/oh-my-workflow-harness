#!/bin/bash
# 一键复现 IFS fastjson2 兼容问题 + 验证修法。依赖本机 ~/.m2 里的 fastjson 2.0.62，不需要 Maven。
set -e
cd "$(dirname "$0")"
M2="$HOME/.m2/repository"
CP="$M2/com/alibaba/fastjson/2.0.62/fastjson-2.0.62.jar"
CP="$CP:$M2/com/alibaba/fastjson2/fastjson2/2.0.62/fastjson2-2.0.62.jar"
CP="$CP:$M2/com/alibaba/fastjson2/fastjson2-extension/2.0.62/fastjson2-extension-2.0.62.jar"
rm -rf out && mkdir -p out
javac -encoding UTF-8 -cp "$CP" -d out IfsToJsonExp.java
java -Dfile.encoding=UTF-8 -cp "$CP:out" IfsToJsonExp
