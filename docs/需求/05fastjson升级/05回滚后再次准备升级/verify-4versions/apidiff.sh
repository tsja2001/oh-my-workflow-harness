#!/bin/bash
cd /tmp/fjlab
R=/home/t/projects/work-wsl

dump() { # jar outfile
  local jar=$1 outf=$2
  rm -f $outf
  # 只看 com.alibaba.fastjson.* 兼容层（不含 fastjson2 原生）
  for cls in $(unzip -Z1 $jar 'com/alibaba/fastjson/*.class' 2>/dev/null | grep -v '\$' | sed 's|/|.|g;s|\.class$||'); do
    javap -cp $jar "$cls" 2>/dev/null | grep -E '^\s+(public|protected)' | sed "s|^|$cls :: |"
  done > $outf
  wc -l < $outf
}

echo "===== 导出 1.2.84 兼容层公开方法 ====="; dump jars/fastjson-1.2.84.jar api-1284.txt
echo "===== 导出 2.0.64 兼容层公开方法 ====="; dump jars/fastjson-2.0.64.jar api-2064.txt

norm() { sed -E 's/\s+/ /g; s/ $//' "$1" | sort -u; }
norm api-1284.txt > n1284.txt
norm api-2064.txt > n2064.txt

echo
echo "===== A. 1.2.84 里存在、2.0.64 里【消失】的类 ====="
cut -d' ' -f1 n1284.txt | sort -u > c1284.txt
cut -d' ' -f1 n2064.txt | sort -u > c2064.txt
comm -23 c1284.txt c2064.txt

echo
echo "===== B. 两版都有的类里，1.2.84 有而 2.0.64 没有的方法（升级方向的断点） ====="
comm -23 n1284.txt n2064.txt | grep -vE '^\s*$' > gone.txt
wc -l < gone.txt
echo "--- 按类汇总 ---"
cut -d' ' -f1 gone.txt | sort | uniq -c | sort -rn | head -40

echo
echo "===== C. 关键类逐条明细 (JSON / JSONObject / JSONArray / TypeUtils / ParserConfig) ====="
grep -E '^com\.alibaba\.fastjson\.(JSON|JSONObject|JSONArray|JSONPath|util\.TypeUtils|parser\.ParserConfig|serializer\.SerializerFeature|parser\.Feature) ' gone.txt | head -80

echo
echo "===== D. 代码里到底用了哪些 fastjson 方法名（去重）====="
grep -rhoE '\b(JSON|JSONObject|JSONArray|JSONPath|TypeUtils|ParserConfig)\.[a-zA-Z0-9_]+' --include=*.java $R/01zhaocai-end $R/03zhaocai-start 2>/dev/null \
  | sort | uniq -c | sort -rn | head -60

echo
echo "===== E. getClassFromMapping 到底在哪个类上调用 ====="
grep -rn "getClassFromMapping" -B3 --include=*.java $R/01zhaocai-end 2>/dev/null | head -30
echo "--- 1.2.84 里这个方法在哪 ---"
grep -i "getClassFromMapping" n1284.txt
echo "--- 2.0.64 里 ---"
grep -i "getClassFromMapping" n2064.txt
