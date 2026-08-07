#!/bin/bash
cd /tmp/fjlab
R=/home/t/projects/work-wsl

echo "===== 1. 代码里 import 的所有 com.alibaba.fastjson.* 类（生产源码）====="
grep -rhoE '^import\s+(static\s+)?com\.alibaba\.fastjson[a-zA-Z0-9_.]*' --include=*.java $R/01zhaocai-end $R/03zhaocai-start 2>/dev/null \
 | sed -E 's/^import\s+(static\s+)?//' | sed -E 's/\.[A-Z_]+$//' | sort | uniq -c | sort -rn > imports.txt
cat imports.txt

echo
echo "===== 2. 这些 import 的类在 2.0.64 兼容层里【是否还存在】====="
unzip -Z1 jars/fastjson-2.0.64.jar 'com/alibaba/fastjson/*.class' 2>/dev/null | sed 's|/|.|g;s|\.class$||' | sort -u > cls2064.txt
unzip -Z1 jars/fastjson2-2.0.64.jar '*.class' 2>/dev/null | sed 's|/|.|g;s|\.class$||' | sort -u >> cls2064.txt
unzip -Z1 jars/fastjson2-extension-2.0.64.jar '*.class' 2>/dev/null | sed 's|/|.|g;s|\.class$||' | sort -u >> cls2064.txt
sort -u cls2064.txt -o cls2064.txt
unzip -Z1 jars/fastjson-1.2.84.jar 'com/alibaba/fastjson/*.class' 2>/dev/null | sed 's|/|.|g;s|\.class$||' | sort -u > cls1284.txt

MISS=0
while read -r n c; do
  [ -z "$c" ] && continue
  if grep -qx "$c" cls2064.txt; then st="OK"; else st="!!! 2.0.64 中不存在"; MISS=$((MISS+1)); fi
  if grep -qx "$c" cls1284.txt; then st1="1.2.84有"; else st1="1.2.84也无"; fi
  printf "%-8s %-6s %6s次  %s\n" "$st" "$st1" "$n" "$c"
done < imports.txt
echo "缺失类数: $MISS"

echo
echo "===== 3. 代码调用的方法名 × 2.0.64 是否有同名方法 ====="
grep -rhoE '\b(JSON|JSONObject|JSONArray|JSONPath|TypeUtils|ParserConfig|SerializeConfig)\.[a-zA-Z0-9_]+' --include=*.java $R/01zhaocai-end $R/03zhaocai-start 2>/dev/null \
 | sort | uniq -c | sort -rn > calls.txt
head -50 calls.txt
echo "--- 逐个核对（只列 2.0.64 里找不到同名方法的）---"
while read -r n call; do
  cls=${call%%.*}; m=${call#*.}
  case $cls in
    JSON) fq=com.alibaba.fastjson.JSON;; JSONObject) fq=com.alibaba.fastjson.JSONObject;;
    JSONArray) fq=com.alibaba.fastjson.JSONArray;; JSONPath) fq=com.alibaba.fastjson.JSONPath;;
    TypeUtils) fq=com.alibaba.fastjson.util.TypeUtils;; ParserConfig) fq=com.alibaba.fastjson.parser.ParserConfig;;
    SerializeConfig) fq=com.alibaba.fastjson.serializer.SerializeConfig;; *) continue;;
  esac
  if ! javap -cp jars/fastjson-2.0.64.jar "$fq" 2>/dev/null | grep -qE "[ .]$m\("; then
     echo "  !!! $call  (代码中 $n 处) -> 2.0.64 的 $fq 没有此方法"
  fi
done < calls.txt

echo
echo "===== 4. getClassFromMapping 调用现场 ====="
grep -rn "getClassFromMapping" --include=*.java $R/01zhaocai-end 2>/dev/null
echo "--- 1.2.84 里有吗 ---"
javap -cp jars/fastjson-1.2.84.jar com.alibaba.fastjson.util.TypeUtils 2>/dev/null | grep -i "ClassFromMapping"
javap -cp jars/fastjson-1.2.84.jar com.alibaba.fastjson.parser.ParserConfig 2>/dev/null | grep -i "ClassFromMapping"
echo "--- 2.0.64 里有吗 ---"
javap -cp jars/fastjson-2.0.64.jar com.alibaba.fastjson.util.TypeUtils 2>/dev/null | grep -i "ClassFromMapping"
javap -cp jars/fastjson-2.0.64.jar com.alibaba.fastjson.parser.ParserConfig 2>/dev/null | grep -i "ClassFromMapping"

echo
echo "===== 5. toJSONBytes 变参版在 2.0.64 是否仍在（决定 1.x->2.x 方向要不要重编译）====="
javap -cp jars/fastjson-2.0.64.jar com.alibaba.fastjson.JSON 2>/dev/null | grep -i "toJSONBytes"
echo "--- 1.2.84 ---"
javap -cp jars/fastjson-1.2.84.jar com.alibaba.fastjson.JSON 2>/dev/null | grep -i "toJSONBytes"
