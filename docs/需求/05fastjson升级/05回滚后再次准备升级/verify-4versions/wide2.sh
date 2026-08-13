#!/bin/bash
cd /tmp/fjlab
CP183=jars/fastjson-1.2.83.jar
CP2064="jars/fastjson-2.0.64.jar:jars/fastjson2-2.0.64.jar:jars/fastjson2-extension-2.0.64.jar"
for v in "183|$CP183" "2064|$CP2064"; do
  n=${v%%|*}; cp=${v#*|}
  rm -rf o2-$n; mkdir -p o2-$n
  javac -nowarn -encoding UTF-8 -cp "$cp" -d o2-$n Wide2.java 2>&1 | head -10
  [ -f o2-$n/Wide2.class ] || { echo "!!! $n 编译失败"; exit 1; }
  java -Dfile.encoding=UTF-8 -cp "$cp:o2-$n" Wide2 2>&1 | grep '|' | sort -t'|' -k1,1 > w2-$n.txt
done
awk -F'|' 'NR==FNR{ id=$1; sub(/^[^|]*\|/,""); a[id]=$0; next }
           { id=$1; v=$0; sub(/^[^|]*\|/,"",v);
             if (a[id] != v) { print "▼ "id; print "   1.2.83 : "a[id]; print "   2.0.64 : "v; d++ }
             else { print "= "id" : "v; s++ } }
           END{ printf "\n---- 相同 %d 项，差异 %d 项 ----\n", s, d }' w2-183.txt w2-2064.txt
