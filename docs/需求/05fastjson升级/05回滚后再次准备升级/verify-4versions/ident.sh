#!/bin/bash
cd /tmp/fjlab
for v in "1.2.83|jars/fastjson-1.2.83.jar" "2.0.64|jars/fastjson-2.0.64.jar:jars/fastjson2-2.0.64.jar:jars/fastjson2-extension-2.0.64.jar"; do
  n=${v%%|*}; cp=${v#*|}
  echo "================= fastjson $n ================="
  rm -rf oi; mkdir -p oi
  javac -nowarn -encoding UTF-8 -cp "$cp" -d oi Ident.java 2>&1 | head -8
  java -Dfile.encoding=UTF-8 -cp "$cp:oi" Ident 2>&1
  echo
done
