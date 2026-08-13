# fastjson 版本行为对照实验（可复现）

> 2026-08-10 cc 第 2 版。结论写在 `../10-拆解规划-cc.md` 第二部分。
> 全部只读实验：不碰公司代码 / 数据库 / 运行环境。

## 一键跑

```bash
mkdir -p /tmp/fjlab && cp *.java *.sh /tmp/fjlab/ && bash /tmp/fjlab/prep.sh
bash /tmp/fjlab/wide.sh      # 主结果：112 项行为差异
```

`prep.sh` 会从本地 `~/.m2`（1.2.83 / 2.0.62）和 Maven Central（1.2.84 / 2.0.64）准备 jar 到 `/tmp/fjlab/jars/`。

## 脚本清单

| 脚本 | 验什么 | 关键结论 |
|---|---|---|
| **`wide.sh` + `Wide.java`** ⭐ | **112 项行为探针，1.2.83 vs 2.0.64 自动 diff** | **96 项相同、16 项不同**，归并成 6 个根因。这是"影响面穷举"的依据 |
| `wide2.sh` + `Wide2.java` | 给新发现的 3 个雷定精确边界 | 实例 `toJSONString()` vs 静态 `JSON.toJSONString()` 行为相反；java.time 全系列反转；null→基本类型被清零 |
| `wide3.sh` + `Wide3.java` | 模拟真实返回链路 `Result<Page<VO>>` → `JSON.toJSON` 逐字段比类型 | Date/Timestamp/BigDecimal/Long/Integer/String/Boolean **全部一致**；只有 java.time 不同 → 前端基本不受影响 |
| `compile.sh` + `CompileProbe.java` | 把代码库出现的 30 种调用形态拿 2.0.64 真编译 | **全场唯一编译断点 = `TypeUtils.getClassFromMapping`** |
| `run.sh` + `Probe.java` | 6 项核心探针 × 4 个版本（1.2.83/1.2.84/2.0.62/2.0.64） | 1.2.83 与 1.2.84 输出**逐字相同** → 1.2.84 是零风险回滚落点 |
| `run2.sh` + `Probe2.java` | `JSON.toJSON()` 对 5 种嵌套结构的递归行为 | 2.x 只有 **Map 的值** 和 **数组** 不再转 Map；直接字段和 List 不变 |
| `xref.sh` / `apidiff.sh` | 代码实际 import/调用 × 2.0.64 是否存在；两版 API 差集 | import 的 9 个类 2.0.64 全在；`toJSONBytes` 变参签名 1.x 有的 2.x 全有 → **升级方向不需要重编译 gateway/MQ** |

## 16 项差异的 6 个根因

| 根因 | 探针 | 现象 | 代码里几处 |
|---|---|---|---|
| R-a java.time 序列化 | S16/S17/R20~R25 | LocalDate 字符串 → 时间戳 | 实体字段 4 处 |
| R-b JSONObject **实例** toJSONString | R1/R4/R5/R7/R10/R13/T11 | 内含 Date 时时间戳 → 字符串 | 23 处（含 DPS 签名 2 处） |
| R-c toJavaObject(TypeReference&lt;Map&gt;) | T06 | Date → String | 2 处（oauth2） |
| R-d JSON.toJSON 递归范围 | T02/T04 | Map 值/数组不再转 Map | 公共层 1 处收口 |
| R-e null/空串 → 基本类型 | D06/D07/R30~R35 | 保留默认值 → 置 0 | DTO 11 处 |
| R-f 循环引用 $ref 写法 | S23/S24 | 路径表示法不同 | 0 处（无影响） |

---

## 改动后的验证脚本（2026-08-10 S3 用）

| 脚本 | 验什么 | 结果 |
|---|---|---|
| `verify.sh` + `Verify.java` ⭐ | **直接调用改动后编译出来的真实类**（`JsonUtils.toRuleContextValue`、`JsonTransferUtil.getJsonPath`），25 项断言 × 2 个版本 | 2.0.64 与 1.2.83 **各 25/25 通过** |
| `ident.sh` + `Ident.java` | A 档改法返回的是不是"同一个对象"（不是同一个的话，按钮注入会写不回去 → 静默故障） | 两版都保持同一实例，写回可见 |

`verify.sh` 依赖 `s3f.sh` 产出的 `out64/`、`out83/`（用两个版本编译公司真实源码得到的 class）。
