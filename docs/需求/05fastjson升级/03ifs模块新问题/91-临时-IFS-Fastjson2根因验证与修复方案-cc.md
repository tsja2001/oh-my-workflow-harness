# IFS 模块 Fastjson2 兼容问题：根因独立验证 + 修复方案（cc）

> 日期：2026-07-31
> 工具：cc（Claude）
> 当前状态：已从源码独立核实根因，并用公司实际依赖 fastjson 2.0.62 跑了可复现实验，三种修法都实测过；**尚未改任何代码/配置/数据库**。
> 下一阶段：用户拍板选方案 → 本地开发+隔离编译+实验回归 → 评审 → 公共 jar 发布与部署（需二次确认）。
> 关联文档：本文在 `90-临时-IFS模块Fastjson2兼容问题排查记录-codex.md` 基础上，**独立复核并补充了"实测验证的修复方案"**，两份结论一致，可并读。

---

## 0. 先分清：这是哪个错

这个文件夹里有两条**互不相干**的错误日志，别混：

| 文件 | 报错 | 模块 | 是不是 fastjson 的锅 |
|---|---|---|---|
| `错误2.md` | `没有找到 ProductSkuCache 的方法：get(String)` | IFS | ✅ **是**（本文只讲它） |
| `long_text_...txt` | `获取seqid失败` | 订单发货 | ❌ 不是，是数据库发号并发，另案处理 |

**本文只处理 `错误2.md` 这条 IFS + fastjson 问题。**

---

## 1. 一句话结论（大白话）

京东"价格变更"消息进来后，IFS 要跑一段后台可配的"规则脚本"（QLExpress）。脚本里写的是把返回数据**当成一层层的 Map 去 `.get("字段名")`** 取值。

- Fastjson **1.x** 时代：`JSON.toJSON(对象)` 会把**里里外外每一层都变成 JSONObject（Map）**，所以 `.get("content")` 一路都能取到。
- 升级到 Fastjson **2.x** 后：`JSON.toJSON(对象)` **只把最外层变成 Map，嵌套的 Java 实体原样保留**。于是脚本取到最里层时，拿到的是 `ProductSkuCache` 这个 Java 实体，它只有 `getContent()`、没有 `get("content")` 这种方法 → 报"找不到 get(String)"。

**根因：老规则配置依赖了 fastjson 1.x "全递归转 Map" 的隐藏行为；2.x 改了这个行为，老配置就崩了。不是谁最近改坏了代码。**

---

## 2. 完整调用链（每一步都在源码里核对过）

1. RocketMQ 消费京东价格变更消息
   `ExcuteMessageConsumer.consumer` → `JdChannelMessageAdapter.excuteChannelMessage` → `PriceChangeExcuteAdapterImpl.pushProductInfo`
2. 加载模板 `pushProductJD-PRICE_CHANGE`，逐步执行
   `ApiMgtServiceImpl.innerExecute`（读 steps，按 type 找 StepEngine 执行）
3. 某个 **aim 步骤**先调回调 `ifs-channelProductService-getProductSkuDetail`，拿到 `ProductSkuModel`，塞进 sourceMap：
   [`AIMStepEngineServiceImplForIFS.java:93`](../../../../01zhaocai-end/scm-ifs-all/scm-ifs-log/src/main/java/com/pcitc/scm/ifs/log/service/impl/AIMStepEngineServiceImplForIFS.java) → `resultMap.put(名字, JSON.toJSON(result))` ← **类型在这里被"定型"**
4. 随后一个 **paramResolver 步骤**跑 QLExpress 规则脚本：
   [`ParamResolverStepEngineServiceImplForIFS.java:68`](../../../../01zhaocai-end/scm-ifs-all/scm-ifs-log/src/main/java/com/pcitc/scm/ifs/log/service/impl/ParamResolverStepEngineServiceImplForIFS.java)（就是 `错误2.md` 堆栈里的那一帧）
5. 脚本里执行到 `detailObj.get("content")`，而 `detailObj` 此时是 `ProductSkuCache` 实体 → 报错

数据结构（源码确认）：
- [`ProductSkuModel`](../../../../01zhaocai-end/scm-ifs-all/scm-ifs-external/src/main/java/com/pcitc/scm/ifs/external/product/model/ProductSkuModel.java)：`private Map<String, ProductSkuCache> detailMap;`
- [`ProductSkuCache`](../../../../01zhaocai-end/scm-ifs-all/scm-ifs-external/src/main/java/com/pcitc/scm/ifs/external/product/model/ProductSkuCache.java)：`@Data`，有 `content` 字段 → 只生成 `getContent()`，**没有** `get(String)`

版本确认：`scm-cloud-parent/pom.xml:65` → `fastjson.version = 2.0.62`；`:306-309` 用的是兼容包 `com.alibaba:fastjson`，代码里 import 的是 `com.alibaba.fastjson.JSON`（1.x 风格 API，跑在 2.x 内核上）。

---

## 3. 实测验证（用公司实际依赖 fastjson 2.0.62 跑出来的）

我写了一个和 `ProductSkuModel / ProductSkuCache` 结构一致的最小实验（`Model` 里含 `Map<String,Cache> detailMap`，`Cache` 里有 `content` + 日期字段），直接用本机 `~/.m2` 里的 `fastjson-2.0.62.jar` 编译运行。实验脚本已存进仓库（见第 7 节），可一键复现。

结果：

| 场景 | 嵌套对象类型 | `.get("content")` 能用？ | 日期还是 Date？ |
|---|---|---|---|
| **A. 现状** `JSON.toJSON(model)` | `Cache`（Java 实体） | ❌ **不能**（复现线上错） | — |
| **B. 文本往返** `JSON.parse(JSON.toJSONString(model))` | JSONObject | ✅ 能 | ❌ **日期被转成 Long 时间戳** |
| **C. 递归规范化（推荐）** | JSONObject | ✅ 能 | ✅ **各层日期都保持 Date** |

关键实测输出：
- A：`detailMap = java.util.HashMap`，`detailObj = Cache` → 就是"嵌套实体没变成 Map"，`get(String)` 找不到 = 线上根因。
- B：嵌套对象确实变 Map 了，但 `bizTime` 从 `Date` 变成了 `java.lang.Long` → **正是 codex 担心的"重演日期问题"，实测坐实，此路不通。**
- C：`detailObj` 变成 Map、`get("content")` 取到 `hello-content`，且顶层日期和嵌套里的日期**都仍是 Date** → 全部通过。

---

## 4. 三种修法与取舍

### 方案 A：改配置（`get("content")` → `getContent()`）——止血用
把失败模板 `ifs.pushProductJD-PRICE_CHANGE.ifs` 里的 `detailObj.get("content")` 改成 `detailObj.getContent()`。
- 优点：**不用发代码**，改完当场对单条失败数据重试即可，最快止血。
- 缺点：① 是**逐模板、逐处**改，codex 在 test 里就数出 21 个模板、89 处 `detailObj.get(...)`（生产数量待同事核）；② 把配置**焊死在 2.x 的类型上**——万一以后回滚 fastjson 或对象结构变了又会崩；③ 治标不治本，新写的模板还会踩。
- 结论：**只当"当天止血"，不当长期方案。**

### 方案 B：代码里文本往返 `JSON.parse(JSON.toJSONString(result))`——❌ 不要用
实验已证明它会把日期变成 Long/String，等于把之前 Source 那个"日期变字符串"的坑再挖一遍。**否决。**

### 方案 C：在公共注入点做"递归规范化"——✅ 推荐（长期正解）
在"把回调结果塞进 sourceMap"的那一步，用一个递归方法把 **Bean/Map/List 全部转成 JSONObject/JSONArray，而标量（Date/数字/布尔/字符串/枚举/java.time）原样保留**。等于把 fastjson 2.x 的行为**手动补回 1.x 的"全递归转 Map"**，同时不碰日期类型。

- 优点：**一处修复，覆盖所有 IFS 模板**（不用改几百处配置）；恢复的正是老配置本来依赖的假设；实测日期保真。
- 代价：动的是**公共链路**（所有 IFS 模板都过这里），必须做回归。
- 落点（源码里 5 处一模一样的 `resultMap.put(名字, JSON.toJSON(result))`，都应改用同一个新方法）：
  - `AIMStepEngineServiceImplForIFS.java:93`（本次失败路径）
  - `ParamResolverStepEngineServiceImplForIFS.java:81`
  - `ErrorResolverStepEngineServiceImplForIFS.java:80`
  - `BodyWrapStepEngineServiceImplForIFS.java:70`
  - `CustomRuleStepEngineServiceImplForIFS.java:41`

  建议把递归方法加到公共工具类 `com.pcitc.scm.common.json.JsonTransferUtil`（`scm-common-json`），5 处统一调用。

参考实现（已实测通过，见第 7 节实验里的 `normalize`）：
```java
// 递归把 Bean/Map/List 变成 JSONObject/JSONArray；Date/数字/布尔/字符串/枚举/java.time 原样保留
static Object toResolverTree(Object o) {
    if (o == null) return null;
    if (o instanceof Map) {
        JSONObject r = new JSONObject();
        for (Map.Entry<?,?> e : ((Map<?,?>) o).entrySet())
            r.put(String.valueOf(e.getKey()), toResolverTree(e.getValue()));
        return r;
    }
    if (o instanceof Collection) {
        JSONArray r = new JSONArray();
        for (Object e : (Collection<?>) o) r.add(toResolverTree(e));
        return r;
    }
    if (o instanceof Object[]) {
        JSONArray r = new JSONArray();
        for (Object e : (Object[]) o) r.add(toResolverTree(e));
        return r;
    }
    Class<?> c = o.getClass();
    if (o instanceof CharSequence || o instanceof Number || o instanceof Boolean
            || o instanceof Date || o instanceof Character || c.isEnum()
            || c.isPrimitive() || c.getName().startsWith("java.time.")) {
        return o;                       // 标量保真
    }
    Object j = JSON.toJSON(o);          // Bean 先转一层，再递归
    return (j instanceof Map || j instanceof Collection || j instanceof Object[]) ? toResolverTree(j) : j;
}
```

### 为什么不能直接复用已有的 `JsonTransferUtil.toResolverMap`
Source 那次修复给 `JsonTransferUtil` 加的 `toResolverMap`，是对**一个 JSONObject 做浅拷贝**（顶层类型保真、`nested instanceof Map` 通过即可），**输入是 JSONObject、且不递归转嵌套 Bean**。而 IFS 这里注入点喂进来的是**原始 Java 实体**（`ProductSkuModel`），需要的是**递归**把里层 Bean 也变 Map。所以 Source 的浅拷贝**覆盖不到** IFS，得用方案 C 的递归版（可作为 `toResolverMap` 的"深度版"新方法并存）。

### 不建议回退 fastjson
回退 1.x 会把这次升级要解决的安全问题又带回来，且推翻已完成的 2.x 兼容工作。除非生产事故负责人明确要紧急回滚，否则走"止血(A) + 公共修复(C)"。

---

## 5. 建议的落地节奏

1. **当天止血**：让有生产权限的同事**先导出备份** `ifs.pushProductJD-PRICE_CHANGE.ifs`，把其中 `detailObj.get("content")` 改 `detailObj.getContent()`，对单条失败 SKU 重试，确认商品池状态从 `ERROR` 走到 `FINISH`。（方案 A）
2. **长期修复**：本地实现方案 C（改 `JsonTransferUtil` + 5 个 StepEngine 注入点）→ 隔离编译 → 用第 7 节实验 + IFS 21 个模板回归 → 评审 → 公共 jar 手动 `deploy` 到 Nexus → 重建对应 IFS 运行包 → 生产验证。（公共代码/发布/部署每一步都要用户二次确认）

---

## 6. 验证清单

**方案 C 发布前（本地）**
- [ ] 递归方法：嵌套 Bean → 可 `.get(String)`；顶层 + 嵌套日期都仍是 Date（第 7 节实验已过，改动落地后再跑一次）
- [ ] 5 个注入点都替换、隔离编译通过、`git diff` 干净
- [ ] 用 test 里含 `detailObj.get` 的 21 个模板回归（ADD / INFO_CHANGE / PRICE_CHANGE，各渠道）

**需要有生产权限的同事只读核对**
- [ ] 导出生产 `ifs.pushProductJD-PRICE_CHANGE.ifs`，核对 `detailObj.get(...)` 处数
- [ ] 生产 IFS 运行包里 fastjson 实际版本
- [ ] 一条失败记录的 SKU / 状态 / 失败次数 / 完整时段日志
- [ ] 是否有 XXL-JOB / 其他任务扫 `ERROR` 记录重试（会不会拿同一份坏配置反复失败）

---

## 7. 可复现实验（已跑通）

- 实验源码：`docs/需求/05fastjson升级/03ifs模块新问题/verify-toJson/IfsToJsonExp.java`
- 运行脚本：`docs/需求/05fastjson升级/03ifs模块新问题/verify-toJson/run.sh`
- 依赖：本机 `~/.m2` 里现成的 `fastjson-2.0.62.jar`（+ `fastjson2` / `fastjson2-extension`），不需要 Maven。
- 一键跑：`bash docs/需求/05fastjson升级/03ifs模块新问题/verify-toJson/run.sh`
- 预期：A 复现 `get(String)` 失败；B 复现日期被转成 Long；C 全部通过（嵌套可 `.get`、各层日期保真）。

---

## 8. 操作边界

- 本次只读源码、跑本地实验；**未改**任何公司代码 / test·uat·prod 数据 / 生产配置 / 远程分支，**未** deploy / Jenkins / 重试消息。
- 凭据未落任何文档。
