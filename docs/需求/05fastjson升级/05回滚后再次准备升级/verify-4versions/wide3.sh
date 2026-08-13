#!/bin/bash
cd /tmp/fjlab
CP183=jars/fastjson-1.2.83.jar
CP2064="jars/fastjson-2.0.64.jar:jars/fastjson2-2.0.64.jar:jars/fastjson2-extension-2.0.64.jar"
for v in "183|$CP183" "2064|$CP2064"; do
  n=${v%%|*}; cp=${v#*|}
  rm -rf o3-$n; mkdir -p o3-$n
  javac -nowarn -encoding UTF-8 -cp "$cp" -d o3-$n Wide3.java 2>&1 | head -5
  java -Dfile.encoding=UTF-8 -cp "$cp:o3-$n" Wide3 2>&1 | grep '|' | sort -t'|' -k1,1 > w3-$n.txt
done
awk -F'|' 'NR==FNR{ id=$1; sub(/^[^|]*\|/,""); a[id]=$0; next }
           { id=$1; v=$0; sub(/^[^|]*\|/,"",v);
             if (a[id]!=v){ print "▼ "id; print "   1.2.83 : "a[id]; print "   2.0.64 : "v; d++ }
             else { print "= "id" : "v; s++ } }
           END{ printf "\n---- 相同 %d，差异 %d ----\n", s, d }' w3-183.txt w3-2064.txt
