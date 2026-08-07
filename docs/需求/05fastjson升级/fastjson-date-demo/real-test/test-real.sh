#!/usr/bin/env bash
# 编译“真实那个改过的 JsonTransferUtil.java” + 本测试，验证 toResolverMap 功能
set -e
cd "$(dirname "$0")"

M2="$HOME/.m2/repository"
CP="$M2/com/alibaba/fastjson/2.0.62/fastjson-2.0.62.jar"
CP="$CP:$M2/com/alibaba/fastjson2/fastjson2/2.0.62/fastjson2-2.0.62.jar"
CP="$CP:$M2/com/alibaba/fastjson2/fastjson2-extension/2.0.62/fastjson2-extension-2.0.62.jar"

JTU="/home/t/projects/work-wsl/01zhaocai-end/scm-assemblies-all/scm-common-all/scm-common-json/src/main/java/com/pcitc/scm/common/json/JsonTransferUtil.java"

echo "===== 1) 编译真实的（改过的）JsonTransferUtil.java ====="
rm -rf out && mkdir -p out
javac -encoding UTF-8 -cp "$CP" -d out "$JTU" && echo "JsonTransferUtil 编译通过（说明新方法 toResolverMap 语法正确）"

echo ""
echo "===== 2) 编译并运行功能测试 ====="
javac -encoding UTF-8 -cp "$CP:out" -d out ToResolverMapTest.java
java -cp "$CP:out" ToResolverMapTest
