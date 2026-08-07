#!/usr/bin/env bash
# ================================================================
#  命令行一键运行（不需要装 Maven，直接用本地 ~/.m2 里现成的 jar）
#  用法：  bash run.sh
# ================================================================
set -e
cd "$(dirname "$0")"

M2="$HOME/.m2/repository"
CP="$M2/com/alibaba/fastjson/2.0.62/fastjson-2.0.62.jar"
CP="$CP:$M2/com/alibaba/fastjson2/fastjson2/2.0.62/fastjson2-2.0.62.jar"
CP="$CP:$M2/com/alibaba/fastjson2/fastjson2-extension/2.0.62/fastjson2-extension-2.0.62.jar"

echo "===== 编译 ====="
mkdir -p target/classes
javac -encoding UTF-8 -cp "$CP" -d target/classes src/main/java/demo/FastjsonDateDemo.java
echo "编译成功"
echo ""
echo "===== 运行 ====="
java -Dfile.encoding=UTF-8 -cp "$CP:target/classes" demo.FastjsonDateDemo
