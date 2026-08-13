# 升级fastjson2 带来的特性改变

| # | 特性改变 | 具体表现 | 影响 |
|---|---|---|---|
| 1 | 删除了 `TypeUtils.getClassFromMapping()` | 编译直接过不去 | 2 处 |
| 2 | `JSONObject` 转泛型 `Map<String,Object>` 时，Date 会变成 String | 上次寻源列表操作按钮消失 | 2 处 |
| 3 | `JSON.toJSON()` 不再递归转换 —— Map 的值和数组保持原样（1.x 会全部转成 JSONObject） | 上次 IFS 京东商品同步报找不到 get 方法 | 22处  |
| 4 | `JSONObject.toJSONString()` **实例写法**输出日期变成字符串，而静态写法 `JSON.toJSONString(x)` 仍是时间戳 —— 同一件事两种写法结果相反 | 报文内容变了。流程审批 DPS 对接拿它算 MD5 签名，签名会对不上 | 21 处 |
| 5 | `java.time.LocalDate/LocalDateTime` 序列化从字符串变成时间戳 | 接口报文格式变 | 4处 |
| 6 | 反序列化时 null / 空字符串给 int、boolean，会把字段默认值冲成 0 / false（1.x 保留默认值） | 字段值被意外清零 | 未使用到 |

其中4、5、6 是上次未发现问题。

**前端不受影响。** 经过对比，两个版本的日期、金额、大数、布尔全部一样。

---

# 影响的模块及处理方法

一共 5 个公共依赖文件 + 21 处业务代码。

## 公共依赖（3 个仓库 5 个文件）

| 仓库 | 文件 | 处理 |
|---|---|---|
| scm-assemblies-all | `scm-common-json/JsonTransferUtil.java`<br>`scm-share-aim-spring/JsonServiceImpl.java` | 特性 1。把删掉的方法换成 Java 自己的类型判断 |
| scm-assemblies-all | `scm-share-rule/JsonUtils.java`<br>`scm-share-rule/QlExpressRuleEngineServiceImpl.java` | 特性 3。规则引擎入口统一处理 |
| scm-cloud-dependencies | `scm-cloud-dependencies-oauth2/OperListResponseTransferServiceImpl.java` | 特性 2。改成保留原类型的浅拷贝 |
| scm-cloud-parent | `pom.xml` | 版本号 1.2.83 → 2.0.64 |

## 业务模块（4 个仓库 21 处）

只有特性 4 需要改业务代码，改法是把 `对象.toJSONString()` 换成 `JSON.toJSONString(对象)`，一行换一行，不动逻辑。

| 仓库 | 文件 | 处数 | 用途 |
|---|---|---|---|
| scm-workflow-all | `DPSProcessServiceImpl.java` | 4 | 其中 2 处是 **DPS 流程审批的 MD5 签名**，必须改 |
| scm-datacenter-all | `SourceChannelController.java` | 8 | 请求报文存库 |
| scm-ifs-all | 8 个文件（certification / external-common / external-jd×4 / external-ofs / mdm） | 8 | 对外接口报文、账单信息存库 |
| scm-source-all | `SourceCollectionServiceImpl.java` | 1 | MQ 消息体 |

---

# 部署及测试顺序

## 1. 发包 Nexus


1. scm-cloud-parent
2. scm-cloud-dependencies-oauth2
3. scm-assemblies-all 的 scm-common-json / scm-share-aim-spring / scm-share-rule


## 2.test 分 四次部署

按"上次出过事的排最后"来排，哪一波出问题就停在哪一波，只回退那一波。

| 波次 | 服务 | 验什么 |
|---|---|---|
| 1 | file、scheduling | 验证fastjson版本 |
| 2 | gateway、gateway-mall、auth | 能登录、网关转发正常、token 正常 |
| 3 | professor、fee、contract、devops、report、srm、product、order、workflow | 各自主流程列表、详情、导出；重点看列表每行的操作按钮；workflow 要专门走一遍流程审批提交，验证签名 |
| 4 | source、ubm、ubm-mall、ifs、ifs-schedule | 一个一个来，每个验完再下一个 |

第 4 波的验收点：

- **source**：调供应商寻源列表接口，每一行都要有操作按钮，日志里不能出现 `String cannot be cast to Date`
- **ubm / ubm-mall**：工作台待办、静态数据下拉、邀请功能（都走规则脚本）
- **ifs**：跑一条京东价格变更消息，商品池状态要从 ERROR 走到 FINISH，日志不能出现"找不到 get 方法"


## 回滚

- **单个服务出问题**：K8s 回滚到上一个镜像 tag，其他服务不动。
- **公共包出问题**：改一个版本号重发。
