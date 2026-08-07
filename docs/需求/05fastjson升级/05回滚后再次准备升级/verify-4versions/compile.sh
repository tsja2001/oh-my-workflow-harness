#!/bin/bash
cd /tmp/fjlab
CP184=jars/fastjson-1.2.84.jar
CP2064="jars/fastjson-2.0.64.jar:jars/fastjson2-2.0.64.jar:jars/fastjson2-extension-2.0.64.jar"

t() {
  echo "############ 编译 $1"
  rm -rf outc; mkdir -p outc
  javac -nowarn -encoding UTF-8 -cp "$2" -d outc CompileProbe.java 2>&1
  if [ -f outc/CompileProbe.class ]; then echo ">>> 编译通过 ✅"; else echo ">>> 编译失败 ❌（上面就是断点清单）"; fi
  echo
}
t "fastjson 1.2.84 (1.x)" "$CP184"
t "fastjson 2.0.64 (2.x)" "$CP2064"

echo "############ 去掉已知会消失的 getClassFromMapping 后，2.0.64 还能编译吗"
sed 's|^\s*Class<?> c = TypeUtils.getClassFromMapping.*|        Class<?> c = String.class; // removed|' CompileProbe.java > CompileProbe2.java
sed -i 's/class CompileProbe/class CompileProbe2/;s/CompileProbe.class/CompileProbe2.class/' CompileProbe2.java
rm -rf outc2; mkdir -p outc2
javac -nowarn -encoding UTF-8 -cp "$CP2064" -d outc2 CompileProbe2.java 2>&1
[ -f outc2/CompileProbe2.class ] && echo ">>> 通过 ✅ 说明唯一编译断点就是 getClassFromMapping" || echo ">>> 仍失败 ❌"
