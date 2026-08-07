# IFS 模块 Fastjson 2.x 兼容问题排查记录

> 日期：2026-07-31  
> 工具：codex  
> 当前状态：已通过生产异常堆栈、代码调用链、test 配置和 Fastjson 1.2.83/2.0.62 对照实验定位根因；尚未修改代码、数据库或生产配置。  
> 下一阶段：先让有生产权限的同事备份并核对生产模板，做最小配置修复和单条失败数据重试；再决定是否实施公共代码兼容。  

## 1. 一句话结论

这次 IFS 异常基本可以确认是 Fastjson 从 1.x 升到 2.x 后产生的第二类兼容问题：

> IFS 的规则配置把 `ProductSkuCache` 当成 `JSONObject`，调用了 `detailObj.get("content")`；Fastjson 1.x 会把这个嵌套对象转成 `JSONObject`，Fastjson 2.x 保留为原始 Java 实体，因此运行时找不到 `get(String)` 方法。

当前生产报错不是 XXL-JOB 调度中心直接抛出的，真正出错线程是 RocketMQ 消费线程。XXL-JOB 可能参与后续失败重试，但不是本次异常的直接发生点。

## 2. 用户遇到的现象

### 2.1 背景

此前已把 Fastjson 从 1.x 升到 2.x，随后出现过 Source 模块日期从 `Date` 变成 `String` 的问题。该问题属于公共返回转换层的类型变化，已有单独记录。

2026-07-31，同事又反馈 IFS 生产模块的“定时任务”有异常，核心日志是：

```text
QlExpressRuleEngineServiceImpl - run QlExpress Exception at line 1

Caused by: java.lang.Exception:
没有找到 com.pcitc.scm.ifs.external.product.model.ProductSkuCache
的方法：get(java.lang.String)
```

堆栈中的关键调用包括：

```text
PriceChangeExcuteAdapterImpl.pushProductInfo
→ ApiMgtServiceImpl.innerExecute
→ ParamResolverStepEngineServiceImplForIFS.execute
→ QlExpressRuleEngineServiceImpl.execute
→ ProductSkuCache.get(String) 找不到
```

### 2.2 同一天另一个容易混淆的问题

`scm-scheduling-web-prod` 的 Jenkins 构建还出现过：

```text
Could not find artifact
com.pcitc:xxl-job-web-jar:jar:1.0.0-JDSN-PROD-SNAPSHOT
```

这是另一件独立问题：

- Scheduling 启动模块在
  `03zhaocai-start/scm-cloud-starters-web/scm-cloud-scheduling/pom.xml:127-130`
  依赖 `xxl-job-web-jar:${project.version}`。
- Jenkins 最终尝试下载 `1.0.0-JDSN-PROD-SNAPSHOT`，但 Nexus 中没有该版本，所以在编译阶段失败。
- 这属于 Jenkins/制品版本不匹配，不是本次 IFS 的 QLExpress 异常根因。

## 3. Scheduling 模块和本次异常是什么关系

Scheduling 模块主要是 XXL-JOB 的调度控制中心，可以理解为“定时任务驾驶舱”：

- 保存任务配置；
- 决定任务什么时候执行；
- 把执行指令发给业务服务；
- 展示执行日志和状态。

但本次异常日志的线程名是：

```text
RocketmqMessageConsumption-0-165
```

代码也证明确实走的是 RocketMQ 消费者：

```text
01zhaocai-end/scm-ifs-all/
scm-ifs-external/src/main/java/com/pcitc/scm/ifs/external/message/mq/
ExcuteMessageConsumer.java:35-50
```

因此准确说法是：

> 京东价格变更消息被 IFS 的 RocketMQ 消费者处理时，执行后台规则配置失败。即使后续存在 XXL-JOB 扫描失败数据并重试，也只是重试入口；真正的错误仍在 IFS 规则表达式和对象类型不兼容。

## 4. 真实业务调用链

### 第一步：消费京东商品价格变更消息

`ExcuteMessageConsumer.consumer()` 根据消息中的渠道选择适配器，并执行：

```java
adapter.excuteChannelMessage(message);
```

证据：

```text
01zhaocai-end/scm-ifs-all/
scm-ifs-external/src/main/java/com/pcitc/scm/ifs/external/message/mq/
ExcuteMessageConsumer.java:35-50
```

### 第二步：进入京东价格变更处理

`PriceChangeExcuteAdapterImpl` 先查询最新价格，再调用 `pushProductInfo()`：

```java
apiMgtService.innerExecute(apiRequest);
```

这里拼出的业务模板名称是：

```text
pushProductJD-PRICE_CHANGE
```

证据：

```text
01zhaocai-end/scm-ifs-all/
scm-ifs-external-jd/src/main/java/com/pcitc/scm/ifs/jd/message/exucte/service/impl/
PriceChangeExcuteAdapterImpl.java:83-104
```

### 第三步：加载并逐步执行 IFS 配置

`ApiMgtServiceImpl.innerExecute()` 读取模板中的 `steps`，逐个寻找对应的步骤执行器：

```java
for (int i = 0; i < steps.size(); i++) {
    service = factory.getByType(j.getString("type"));
    service.execute(j, sourceMap);
}
```

证据：

```text
01zhaocai-end/scm-ifs-all/
scm-ifs-log/src/main/java/com/pcitc/scm/ifs/log/service/impl/
ApiMgtServiceImpl.java:239-246
```

### 第四步：先查询 SKU 明细对象

模板第一步调用：

```text
ifs-channelProductService-getProductSkuDetail
```

结果保存为：

```text
skuModel
```

返回对象是 `ProductSkuModel`，其中的关键字段声明为：

```java
private Map<String, ProductSkuCache> detailMap;
```

证据：

```text
01zhaocai-end/scm-ifs-all/
scm-ifs-external/src/main/java/com/pcitc/scm/ifs/external/product/model/
ProductSkuModel.java:9-41
```

### 第五步：Fastjson 转换返回对象

回调结果进入 `sourceMap` 前会执行：

```java
resultMap.put(arrays.getString(i), JSON.toJSON(result));
```

证据：

```text
01zhaocai-end/scm-ifs-all/
scm-ifs-log/src/main/java/com/pcitc/scm/ifs/log/service/impl/
AIMStepEngineServiceImplForIFS.java:87-94
```

这行是本次兼容问题的关键入口。

### 第六步：QLExpress 执行配置表达式

test 环境 `ifs.pushProductJD-PRICE_CHANGE.ifs` 的实际表达式中存在：

```java
detailMap = skuModel.get("detailMap");
detailObj = detailMap.get("detail");

if (detailObj != null) {
    contentStr = detailObj.get("content");
}
```

表达式最终由下面代码执行：

```java
runner.execute(statement, expressContext, null, true, false);
```

证据：

```text
01zhaocai-end/scm-assemblies-all/
scm-share-rule-all/scm-share-rule/src/main/java/com/pcitc/scm/share/rule/service/impl/
QlExpressRuleEngineServiceImpl.java:35-41
```

## 5. 具体错在哪里

真正失败的是：

```java
detailObj.get("content")
```

Fastjson 2.x 下，三个变量的实际类型是：

| 变量 | 实际类型 | `.get(...)` 是否存在 |
|---|---|---|
| `skuModel` | `JSONObject` | 支持 `get("detailMap")` |
| `detailMap` | `HashMap` | 支持 `get("detail")` |
| `detailObj` | `ProductSkuCache` | 不支持 `get("content")` |

`ProductSkuCache` 是 Java 实体，不是通用 Map。它的 `content` 字段定义在：

```text
01zhaocai-end/scm-ifs-all/
scm-ifs-external/src/main/java/com/pcitc/scm/ifs/external/product/model/
ProductSkuCache.java:24-50
```

类上有 Lombok 的 `@Data`，编译后会生成：

```java
getContent()
```

但不会生成：

```java
get(String key)
```

所以 QLExpress 尝试寻找的是：

```java
ProductSkuCache.get(String)
```

该方法不存在，最终就产生了生产日志中的异常。

日志显示“at line 1”，是因为整段规则表达式以一整行字符串保存在配置中，不代表第一行 Java 源码写错。

## 6. 为什么 Fastjson 1.x 没事，2.x 才出错

使用项目本机实际依赖包做了最小对照实验：

```text
com.alibaba:fastjson:1.2.83
com.alibaba:fastjson:2.0.62
```

实验对象与业务结构一致：

```text
Model
└── Map<String, Cache> detailMap
    └── price → Cache
```

同样执行：

```java
JSONObject outer = (JSONObject) JSON.toJSON(model);
```

Fastjson 1.2.83 的结果：

```text
outer=com.alibaba.fastjson.JSONObject
detailMap=com.alibaba.fastjson.JSONObject
price=com.alibaba.fastjson.JSONObject
```

Fastjson 2.0.62 的结果：

```text
outer=com.alibaba.fastjson.JSONObject
detailMap=java.util.HashMap
price=FastjsonNestedBeanTest$Cache
```

这和生产异常完全对应：

- 1.x 把嵌套 `Cache` 也转成 `JSONObject`，因此旧配置能调用 `get("content")`。
- 2.x 保留嵌套 Map 和 Java 实体，`ProductSkuCache` 只能调用 `getContent()`。

当前父 POM 管理的 Fastjson 版本是 `2.0.62`：

```text
01zhaocai-end/scm-cloud-parent/pom.xml:65
01zhaocai-end/scm-cloud-parent/pom.xml:306-309
```

## 7. 这不是近期 IFS 业务代码改坏的

Git 核对结果：

- `AIMStepEngineServiceImplForIFS.java` 中的 `JSON.toJSON(result)` 可追溯到
  2023-04-21 的提交 `4ee48abb5`。
- 本次相关的四个文件在 `origin/prod`、`origin/uat`、`origin/test` 中 blob 完全一致。

因此目前证据支持：

> IFS 老代码和老配置长期依赖了 Fastjson 1.x 的嵌套转换行为；Fastjson 2.x 进入运行环境后，原有隐含依赖才被触发。

尚未直接核实生产 Pod 中的 jar 清单和实际部署时间，因此“生产具体从哪次构建开始使用 2.0.62”仍属于待确认项。

## 8. test 配置排查结果

2026-07-31 对 `scm_ubm_test.scm_staticdata_detail` 做了只读查询。

当前失败场景对应配置：

```text
request_key = ifs.pushProductJD-PRICE_CHANGE.ifs
enable = 1
JSON_VALID(data_detail) = 1
配置长度 = 5524
```

其中：

- 第一步回调：`ifs-channelProductService-getProductSkuDetail`
- 回调结果名：`skuModel`
- 存在 5 处 `detailObj.get(...)`

按以下条件扫描：

```text
enable = 1
request_key LIKE 'ifs.%'
```

结果为：

| 项目 | test 查询结果 |
|---|---:|
| 启用的 IFS 配置 | 195 |
| 含 `detailObj.get` 的配置 | 21 |
| `detailObj.get` 总调用次数 | 89 |

涉及的配置包括：

```text
DL：ADD / INFO_CHANGE / PRICE_CHANGE
JD：ADD / INFO_CHANGE / PRICE_CHANGE
JDWELFARE：ADD / INFO_CHANGE
OFS：ADD / INFO_CHANGE / PRICE_CHANGE
XFS：ADD / INFO_CHANGE / PRICE_CHANGE
XY：ADD / ADD1 / INFO_CHANGE / PRICE_CHANGE
ZKH：ADD / INFO_CHANGE / PRICE_CHANGE
```

注意：

> 以上是 test 数据，不能直接当作生产影响数量。生产必须用相同条件重新查询或从配置页面导出后才能确认。

## 9. 失败后数据会怎么样

`PriceChangeExcuteAdapterImpl` 捕获异常后会：

```text
ProductSkuPool.state = ERROR
ProductSkuPool.errorMessage = 异常信息
ProductSkuPool.failNum = failNum + 1
```

证据：

```text
PriceChangeExcuteAdapterImpl.java:93-104
```

外层 `ExcuteMessageConsumer` 还会：

```text
ExternalMessage.state = ERROR
ExternalMessage.failNum = failNum + 1
保存错误信息
返回 CommitMessage
```

证据：

```text
ExcuteMessageConsumer.java:35-50
```

这说明：

- 失败记录会被标成 `ERROR`；
- 当前 RocketMQ 消息在这一层会被确认消费，不会依赖同一条 MQ 消息自然重投；
- 是否由另外的定时任务扫描 `ERROR` 记录并补偿重试，尚未完成全链路核实；
- 如果补偿任务仍执行同一份错误配置，会重复失败并继续增加失败次数。

## 10. 和前一个日期问题的区别

两次问题都由 Fastjson 1.x → 2.x 的行为差异触发，但不是同一个报错点。

| 问题 | 旧代码的假设 | 2.x 后的变化 | 最终表现 |
|---|---|---|---|
| Source 日期问题 | `toJavaObject(Map)` 后 `Date` 仍是日期对象 | 日期变成 `String` | `(Date)` 强转失败 |
| 本次 IFS 问题 | `JSON.toJSON()` 后嵌套实体也是 `JSONObject` | 嵌套实体保留为 `ProductSkuCache` | `get(String)` 方法找不到 |

因此此前 Source 公共转换层的修复不会自动覆盖本次 IFS 链路。

## 11. 建议处理方案

### 11.1 生产应急方案：先改失败模板

先让有生产权限的同事备份并核对：

```text
ifs.pushProductJD-PRICE_CHANGE.ifs
```

把其中 5 处类似：

```java
detailObj.get("content")
```

改为：

```java
detailObj.getContent()
```

理由：

- `detailObj` 当前实际就是 `ProductSkuCache`；
- `@Data` 已生成 `getContent()`；
- 改动范围只在当前失败模板，适合作为止血方案；
- 不需要先发布 Java 代码。

操作前必须导出或复制原配置，方便一键回退。

### 11.2 应急修复后的验证

至少验证：

1. 配置保存后重新打开，确认 5 处都已生效。
2. 找一条失败的京东价格变更 SKU 重试。
3. 确认不再出现 `ProductSkuCache.get(String)`。
4. 确认商品池状态从 `ERROR` 正常走到 `FINISH`。
5. 确认失败次数不再增加，最终推送结果符合预期。
6. 观察其他 `ADD`、`INFO_CHANGE`、其他渠道是否出现同类错误。

### 11.3 长期方案：统一兼容规则引擎输入

长期有两个方向，需要评审后再选。

方向 A：逐个配置改成 Java getter。

```text
detailObj.get("content")
→ detailObj.getContent()
```

优点是逻辑明确；缺点是配置数量多，并且不同返回对象可能需要不同 getter。

方向 B：代码层把回调结果稳定转换成规则引擎预期的 JSON 树。

本地实验表明：

```java
JSON.parse(JSON.toJSONString(result))
```

在 1.2.83 和 2.0.62 下都能让嵌套对象重新成为 `JSONObject`。但不能直接把这行当最终修复发布，因为文本化再解析可能把 `Date` 等类型变成字符串，重演此前日期问题。

更稳妥的长期方案应当：

- 明确定义规则引擎输入允许哪些类型；
- 对 Map、List、普通实体做可控的递归转换；
- 对 Date、数字、Boolean 做类型保真；
- 用本次 21 个 test 模板做回归；
- 验证新增、信息变更、价格变更和失败补偿链路。

### 11.4 不优先建议回退 Fastjson

回退到 1.x 虽然可能暂时恢复旧行为，但会重新引入此前升级要解决的安全风险，也会撤销已经完成的 2.x 兼容工作。

除非生产事故负责人明确决定紧急回滚，否则优先采用当前模板止血和代码兼容。

## 12. 需要生产同事补充的证据

由于当前账号只能接触 test/UAT，仍需有生产权限的同事提供以下只读结果：

1. 生产 `ifs.pushProductJD-PRICE_CHANGE.ifs` 的脱敏导出内容。
2. 生产环境搜索 `detailObj.get` 的模板数量和调用次数。
3. IFS 运行包中的 Fastjson 实际版本。
4. 一条失败记录的业务 ID、SKU、状态、失败次数和完整时间段日志。
5. 是否有 XXL-JOB 或其他补偿任务扫描 IFS 的 `ERROR` 记录。
6. 配置修复后单条重试的结果。

可直接发给同事：

> 已定位到 IFS 规则配置与 Fastjson 2.x 的兼容问题。京东价格变更模板里把 `ProductSkuCache` 当成 JSONObject，调用了 `detailObj.get("content")`；2.x 下它实际是 Java 实体，只支持 `getContent()`，所以报找不到 `get(String)`。请先备份并导出生产 `ifs.pushProductJD-PRICE_CHANGE.ifs`，核对其中 5 处同类表达式；同时帮忙确认生产 IFS 包里的 Fastjson 版本、全局搜索 `detailObj.get` 的模板数量，以及是否有任务扫描 ERROR 记录重试。未经备份先不要直接保存配置。

## 13. 敏感信息与本次操作边界

- 用户曾提供生产平台访问凭据，本记录没有保存地址、账号或密码。
- 建议对已在聊天中暴露的生产密码尽快执行轮换。
- 本次只读取本地代码、Git 历史和 test 配置。
- 未登录生产 XXL-JOB。
- 未修改公司代码、test/uat/prod 数据、生产配置或远程分支。
- 未执行 Maven deploy、Jenkins 构建或消息重试。

