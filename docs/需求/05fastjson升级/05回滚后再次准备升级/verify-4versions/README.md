# fastjson 4 版本行为对照实验（可复现）

> 2026-08-07 cc 产出。结论已写进 `../10-拆解规划-cc.md` 第二部分。
> 只读实验，不碰公司代码/库/环境。

## 一键跑

```bash
mkdir -p /tmp/fjlab && cp *.java *.sh /tmp/fjlab/ && bash /tmp/fjlab/run.sh
```

jar 会自动从本地 `~/.m2` 取（1.2.83 / 2.0.62）+ 从 Maven Central 下载（1.2.84 / 2.0.64），落在 `/tmp/fjlab/jars/`。

## 各脚本干什么

| 脚本 | 验什么 | 关键结论 |
|---|---|---|
| `run.sh` + `Probe.java` | 6 项行为逐项对跑 1.2.83 / 1.2.84 / 2.0.62 / 2.0.64 | **1.2.83 与 1.2.84 输出逐字相同**；日期序列化格式四版一致（都是时间戳）；`toJavaObject(TypeReference<Map>)` 只有 2.x 把 Date 变 String；SafeMode 属性名 1.x 不带 2、2.x 带 2 |
| `run2.sh` + `Probe2.java` | `JSON.toJSON()` 对 5 种嵌套结构的递归行为 | 2.x 只有 **Map 的值** 和 **数组** 不再递归转换；直接字段和 List 行为不变 |
| `compile.sh` + `CompileProbe.java` | 把代码库里出现的全部 30 种调用形态拿 2.0.64 真编译 | **全场唯一编译断点 = `TypeUtils.getClassFromMapping`**，去掉后编译通过 |
| `apidiff.sh` | javap 导出两版兼容层公开方法做差集 | 原始差集有噪音（继承方法），结论以 `compile.sh` 为准 |
| `xref.sh` | 代码实际 import / 调用 × 2.0.64 是否存在 | import 的 9 个类在 2.0.64 全部存在；`toJSONBytes` 变参签名 1.2.84 有的 2.0.64 全都有（所以升级方向不需要重编译 gateway/MQ） |
