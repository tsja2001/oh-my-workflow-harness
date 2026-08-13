#!/bin/bash
cd /tmp/fjlab
CP183=jars/fastjson-1.2.83.jar
CP2064="jars/fastjson-2.0.64.jar:jars/fastjson2-2.0.64.jar:jars/fastjson2-extension-2.0.64.jar"

for v in "183|$CP183" "2064|$CP2064"; do
  n=${v%%|*}; cp=${v#*|}
  rm -rf ow-$n; mkdir -p ow-$n
  javac -nowarn -encoding UTF-8 -cp "$cp" -d ow-$n Wide.java 2>&1 | head -10
  [ -f ow-$n/Wide.class ] || { echo "!!! $n 编译失败"; exit 1; }
  java -Dfile.encoding=UTF-8 -cp "$cp:ow-$n" Wide 2>&1 | grep '|' | sort -t'|' -k1,1 > wide-$n.txt
  echo "$n 输出行数: $(wc -l < wide-$n.txt)"
done

echo
echo "=================================================================="
echo "  1.2.83 与 2.0.64 行为差异"
echo "=================================================================="
awk -F'|' 'NR==FNR{ id=$1; sub(/^[^|]*\|/,""); a[id]=$0; next }
           { id=$1; v=$0; sub(/^[^|]*\|/,"",v);
             if (!(id in a)) { print "▼ "id" (1.2.83 缺此项)"; next }
             if (a[id] != v) { print "▼ "id; print "   1.2.83 : "a[id]; print "   2.0.64 : "v; d++ }
             else s++ }
           END{ printf "\n---- 相同 %d 项，差异 %d 项 ----\n", s, d }' wide-183.txt wide-2064.txt
