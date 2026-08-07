#!/bin/bash
cd /tmp/fjlab
for v in "1.2.84|jars/fastjson-1.2.84.jar" "2.0.64|jars/fastjson-2.0.64.jar:jars/fastjson2-2.0.64.jar:jars/fastjson2-extension-2.0.64.jar"; do
  n=${v%%|*}; cp=${v#*|}
  echo "=================== fastjson $n ==================="
  rm -rf o2; mkdir -p o2
  javac -nowarn -encoding UTF-8 -cp "$cp" -d o2 Probe2.java 2>&1 | head -5
  java -cp "$cp:o2" Probe2
  echo
done
