# Fastjson 日期问题 · 演示测试（给领导看的）

## 这是什么

一个**独立的小程序**，把三种改法用**同一份数据**各跑一遍，当场比出谁能修好、谁修不好。
它**不依赖公司任何代码**，所以不管你最后决定在哪儿改，都能先用它把思路验证/演示出来。

跑一次大概 1 秒，输出一段带 ✅ / ❌ 的结果。

---

## 演示时会看到的结论（心里先有数）

```
场景 1  现网写法（toJavaObject 泛型 Map）  ： ❌ 报错  ← 问题根源（复现线上 ClassCastException）
场景 2  加方法 + 浅拷贝 new HashMap<>()     ： ✅ 修复  ← 推荐（领导“加方法”的思路，装对内容就行）
场景 3  设全局日期格式                      ： ❌ 无效（只把字符串换了个样子，类型还是 String）
```

一句话解说：**日期升级后被降级成了字符串；"浅拷贝"能原样保住日期，"改日期格式"不行。**

---

## 方式一：命令行运行（最省事，现场推荐）

打开 **Ubuntu (WSL) 终端**，粘贴这两行：

```bash
cd "/home/t/projects/work-wsl/docs/需求/05fastjson升级/fastjson-date-demo"
bash run.sh
```

就会看到"编译成功"后打印整段结果。机器上 Java 和 fastjson 依赖都装好了，不用额外装东西、不用联网。

> 如果你习惯在 Windows 终端(PowerShell)里操作，也可以：先输 `wsl` 回车进入 Ubuntu，再粘上面那两行。
> （不建议在 PowerShell 里直接拼一条带中文路径的长命令，中文容易乱码。）

---

## 方式二：IDEA 里运行（喜欢点绿色按钮的话）

1. **打开项目**：IDEA 顶部 `File → Open…`，选到 **`fastjson-date-demo`** 这个文件夹（里面有 `pom.xml`），点 OK。
   - IDEA 会认出它是个 Maven 项目，右下角会弹"加载/导入 Maven"提示，**等它转圈结束**（第一次要拉 fastjson 2.0.62，几秒钟；本地已有就秒好）。
2. **找到主程序**：左边项目树依次展开 `src → main → java → demo`，双击打开 **`FastjsonDateDemo.java`**。
3. **运行**：`main` 方法左边有个**绿色三角 ▶**，点它 → `Run 'FastjsonDateDemo.main()'`。
4. 窗口下方弹出的 **Run 面板**里，就是那段带 ✅ / ❌ 的结果。

> 万一中文显示成乱码：`Help → Edit Custom VM Options…` 里加一行 `-Dfile.encoding=UTF-8`，重启 IDEA 即可（新版 IDEA 一般默认 UTF-8，用不到）。

---

## 想让领导看到"就写在 JsonTransferUtil 旁边"（可选）

领导要是想在**公司项目**里、紧挨着 `JsonTransferUtil` 看这个演示，把
`src/main/java/demo/FastjsonDateDemo.java` 复制到公司模块的测试目录下：

```
01zhaocai-end/scm-assemblies-all/scm-common-all/scm-common-json/src/test/java/demo/FastjsonDateDemo.java
```

在你已经打开的公司项目里，直接对它 `Run` 即可（那个模块本来就带 fastjson 2.0.62 依赖）。
**注意：这只是演示用的临时文件，别提交进公司仓库。**

---

## 每个场景在讲什么（演示解说词，照着念就行）

- **场景 1｜现网写法**：这就是线上出错的那行——把一行数据转成通用 Map。你看，转完之后
  `sourceSignEndTime` 从"日期对象"变成了"字符串"，业务代码再按日期强转，当场崩 `ClassCastException`。
  **顺便注意：数字、字符串、对象都没坏，唯独日期被降级了。**

- **场景 2｜加方法 + 浅拷贝**：这就是"在 JsonTransferUtil 里加一个方法"的思路——方法内部用"浅拷贝"，
  把每个字段原样搬过去。你看，日期还是日期，强转成功；数字、对象也全都原样保留。**这个改法有效。**

- **场景 3｜全局日期格式**：这是"在日期格式上做文章"的思路。设完之后你看，日期字符串确实换了个样子
  （变成带 T 和 Z 的），但**它还是字符串**，强转照样崩。**格式只管长相，管不了类型——所以无效。**

- **结论**：只有"浅拷贝"能真正修好。落地时就是把这个浅拷贝方法放进 `JsonTransferUtil`，
  再让公共转换器那两行调用它。
