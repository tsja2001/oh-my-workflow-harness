#!/bin/bash
cd /tmp/fjlab
for v in "2.0.64|out64|jars/fastjson-2.0.64.jar:jars/fastjson2-2.0.64.jar:jars/fastjson2-extension-2.0.64.jar" \
         "1.2.83|out83|jars/fastjson-1.2.83.jar"; do
  n=$(echo "$v" | cut -d'|' -f1); o=$(echo "$v" | cut -d'|' -f2); cp=$(echo "$v" | cut -d'|' -f3)
  echo "################################################################"
  echo "###############   用改动后的真实类 × fastjson $n"
  echo "################################################################"
  rm -rf ov-$o; mkdir -p ov-$o
  javac -nowarn -encoding UTF-8 -cp "$cp:$o" -d ov-$o Verify.java 2>&1 | head -10
  java -Dfile.encoding=UTF-8 -cp "$cp:$o:ov-$o" Verify
  echo
done
