# Fastjson 公共转换层修复与部署说明

> 日期：2026-07-27  
> 工具：codex  
> 当前状态：本文只说明准备怎么改、怎么部署和怎么验证；代码尚未修改，也没有执行提交、推送、Maven deploy 或 Jenkins。  
> 下一阶段：用户确认后才开始本地开发和验证；公共 jar 发布、远程推送和 Jenkins 部署仍需再次确认。  

关联文档：

```text
docs/需求/05fastjson升级/50-代码复盘与学习-codex.md
```

---

## 1. 先说最简单的结论

方案 A 预计只修改一个公共 Java 文件中的两处代码：

```text
01zhaocai-end/scm-cloud-dependencies/
scm-cloud-dependencies-oauth2/src/main/java/com/pcitc/scm/web/oauth2/
datatransfer/service/impl/OperListResponseTransferServiceImpl.java
```

修改目的：

> 不要再把一行返回数据“写成 JSON 字符串后重新读取”，而是直接复制这一行已有的数据，避免 Date 变成 String。

修改完成后，先把新的公共 jar 发到 Nexus，再重新构建 `scm-source-web-test`，新的公共代码才会真正进入 test 环境正在运行的 source 服务。

---

## 2. 具体准备怎么修改

### 2.1 当前错误写法

这个公共类有两种处理场景。

第一种：返回的是单个对象，当前代码在第 83 行：

```java
target.put(v, operResolverService.resolverOperList(
        target.toJavaObject(new TypeReference<Map<String, Object>>() {})
));
```

第二种：返回的是数组，当前代码在第 113 行：

```java
obj.put(v, operResolverService.resolverOperList(
        obj.toJavaObject(new TypeReference<Map<String, Object>>() {})
));
```

问题集中在：

```java
toJavaObject(new TypeReference<Map<String, Object>>() {})
```

fastjson 2.x 处理这个带泛型的 Map 时，会经过一次 JSON 文本转换，Date 就变成 String。

### 2.2 推荐改法

引入 Java 自己的 `HashMap`：

```java
import java.util.HashMap;
```

删除不再使用的：

```java
import com.alibaba.fastjson.TypeReference;
```

单对象分支改成：

```java
target.put(v, operResolverService.resolverOperList(
        new HashMap<>(target)
));
```

数组分支改成：

```java
obj.put(v, operResolverService.resolverOperList(
        new HashMap<>(obj)
));
```

### 2.3 用生活例子理解

旧做法：

```text
打开抽屉
→ 把里面的东西全部写到纸上
→ 根据纸上的文字重新装一个抽屉
```

日期对象经过“写到纸上”以后，只剩下一串日期文字。

新做法：

```text
打开抽屉
→ 直接复制每一个格子里的原东西
```

原来是 Date，复制后仍然是 Date；原来是 Integer、Boolean、String，也继续保持原类型。

### 2.4 为什么要改两处

第 83 行处理：

```text
data 是一个对象
```

第 113 行处理：

```text
data.root 是一个列表
```

今天出问题的供应商寻源列表走第 113 行。

如果只修第 113 行，当前列表可以恢复，但以后某个使用单对象转换的接口仍可能报同类错误。因此两处必须一起处理。

### 2.5 这次不准备改什么

公共根修方案下，不需要修改：

- `SourceQueryController.java`
- `OperSupplierSourcePageListImpl.java`
- `SupplierSourceVO.java`
- `scm-cloud-parent` 的 fastjson 版本
- `scm-assemblies-all` 上次的兼容代码

也不需要给日期字段加 `@JSONField(format=...)`。

---

## 3. 修改后怎么从代码走到 test 环境

### 3.1 先认识三个地方

| 地方 | 作用 | 类比 |
|---|---|---|
| GitLab | 保存源码和提交记录 | 放菜谱 |
| Nexus | 保存编译后的公共 jar | 放预制菜 |
| K8s Pod | 真正运行 source 服务 | 顾客正在吃的餐厅 |

只修改本地代码，三个地方都不会自动变化。

### 3.2 完整部署链路

```text
本地修改 OperListResponseTransferServiceImpl
        │
        ▼
本地编译和日期类型实验通过
        │
        ▼
本地 Git 提交
        │
        ▼
用户明确同意后，代码才允许推送到远程
        │
        ▼
手动 mvn deploy
把新的 scm-cloud-dependencies-oauth2 jar 发到 Nexus
        │
        ▼
用户点 scm-source-web-test
重新构建 source 的 Spring Boot 大 jar 和 Docker 镜像
        │
        ▼
K8s 重新启动 source Pod
        │
        ▼
用真实供应商账号调用列表接口，检查按钮和日志
```

### 3.3 为什么公共 jar 要手动 deploy

`scm-cloud-dependencies` 是公司的地基仓库之一，现有记录显示没有对应 Jenkins 构建任务。

它的根 POM 已明确配置：

```text
普通版本上传到 maven-releases
SNAPSHOT 上传到 maven-snapshots
```

证据：

```text
01zhaocai-end/scm-cloud-dependencies/pom.xml:38-48
```

需要发布的模块是：

```text
com.pcitc:scm-cloud-dependencies-oauth2:1.0.0-JDSN-SNAPSHOT
```

只发布这个模块的计划命令是：

```bash
cd 01zhaocai-end/scm-cloud-dependencies/scm-cloud-dependencies-oauth2
mvn clean deploy -s ~/.m2/settings-zc.xml -DskipTests
```

注意：

- 这条命令会写 Nexus，当前不会执行。
- 不使用 `-am` 批量重发其他公共模块，避免把无关模块一起覆盖。
- 发布前必须确认站在正确的最新主线，不能拿旧分支覆盖 Nexus 上的新内容。
- 禁止用 `bash -x` 调试 Maven 配置，避免把凭据打印出来。

### 3.4 为什么这次不一定需要 `scm-source-all-test`

平时修改 `scm-source-all` 业务代码，要：

```text
scm-source-all-test
→ scm-source-web-test
```

但方案 A 没有修改 `scm-source-all`，修改的是公共 jar。

这次对应关系是：

```text
手动 deploy scm-cloud-dependencies-oauth2
→ scm-source-web-test
```

`scm-cloud-starters-web/scm-cloud-source/pom.xml:132` 直接依赖 `scm-cloud-dependencies-oauth2`，因此 source-web 重新构建时会从 Nexus 拉公共 jar，并装进最终运行包。

`scm-cloud-dependencies/pom.xml:24-27` 对 SNAPSHOT 配置了：

```xml
<updatePolicy>always</updatePolicy>
```

正常情况下，每次构建都会检查最新 SNAPSHOT。

如果团队 Jenkins 流程强制要求始终先点 all，也可以按团队流程补点；但真正让这次公共代码进入运行环境的关键步骤，是：

```text
公共 jar 已进 Nexus
+ source-web 重新打镜像并部署
```

只完成 Maven deploy，不点 source-web，运行中的 Pod 仍然是旧代码。

---

## 4. 会有什么风险

### 4.1 风险一：它是公共代码

本地现有代码扫描到：

- 110 个 `OperResolverService` 实现。
- 140 处 `@OperListTransfer` 使用。

不是说这 140 处都会出错，而是它们都经过这个公共转换器。

所以改动虽然只有两处，影响面却不像普通业务文件那么小。

### 4.2 风险二：其他服务以后重建时也会拿到新 jar

公共 jar 使用的是：

```text
1.0.0-JDSN-SNAPSHOT
```

SNAPSHOT 的特点是同一个逻辑版本可以反复发布。

今天发布新 jar 后：

- 已经运行且没有重建的其他服务，不会立刻变化。
- 以后重新构建的服务，会逐渐拿到这次修改。

所以这不是只对 source 永久生效的私有补丁，而是一个会随各服务重建逐步扩散的公共修复。

### 4.3 风险三：从错误分支 deploy 会覆盖同事的新内容

之前 fastjson 升级已经真实踩过一次：

> 从落后的公共仓库分支执行 deploy，把 Nexus 上较新的 SNAPSHOT 覆盖成了旧内容。

因此发布前必须确认：

```text
当前分支正确
本地包含远程主线最新提交
git diff 只有本次一个文件
```

### 4.4 风险四：浅拷贝会保留原始类型

这正是我们想要的效果：

```text
Date 继续是 Date
Integer 继续是 Integer
Boolean 继续是 Boolean
```

但 fastjson2 当前的泛型转换可能已经让部分类型发生过变化。

改成浅拷贝，相当于恢复到更接近 fastjson 1.x 的行为。理论上这是兼容修复，但公共代码不能只看理论。

当前源码扫描没有发现操作按钮解析器修改传入 Map，也没有发现它们依赖复杂嵌套 Map；这是风险较低的证据，但本地源码不等于公司所有已发布二进制，所以仍要做代表性回归。

### 4.5 风险五：回滚也需要重新打镜像

如果公共修复出现问题，不能只在 Git 里撤销。

完整回滚是：

```text
撤销公共代码提交
→ 重新 deploy 旧逻辑的 oauth2 SNAPSHOT
→ 重新构建 scm-source-web-test
→ 检查 Pod 和接口
```

因为真正运行的是镜像里的 jar，不是 GitLab 页面上的源码。

---

## 5. 为什么还必须验证

### 5.1 编译通过只能证明“语法没写错”

这次原始问题本身就是运行时类型问题：

```text
代码能编译
服务能启动
SQL 能执行
请求真正走到 Date 强转时才报错
```

所以只看编译结果，根本覆盖不到原问题。

### 5.2 Jenkins 绿灯不能证明 Pod 用的是新公共 jar

Jenkins 绿灯只说明构建命令成功。

仍可能发生：

- Nexus 上发错了模块。
- Jenkins 拉到旧 SNAPSHOT。
- web 镜像没重新构建。
- K8s 仍在运行旧 Pod。

因此要从构建日志或最终大 jar 中确认：

```text
scm-cloud-dependencies-oauth2 的新时间戳版本确实被装进去了
```

### 5.3 接口返回成功也不能证明按钮转换成功

`GlobalResponseHandler` 会捕获返回转换异常。

因此可能出现：

```json
{
  "status": true,
  "data": {
    "root": []
  }
}
```

或者列表有数据，但 `operList` 没有正常补全。

验收不能只看：

```text
HTTP 200
status=true
```

还要看每一行是否真的有正确的操作按钮。

### 5.4 为什么还要测别的接口

改的是公共代码，不是只供供应商寻源列表使用。

至少要覆盖：

1. 数组分支：今天的 `querySupplierSourcePageList`。
2. 单对象分支：找一个使用对象操作列转换的接口。
3. 普通类型：Integer、Boolean、String 不应被改坏。
4. 其他 source 操作列：采购方寻源、报名、费用列表各抽一个。

这不是为了追求“测试看起来很完整”，而是因为修改点本身就同时服务这些分支。

---

## 6. 计划怎么验证

### 发布前

1. 用 fastjson 1.2.83 和 2.0.62 跑同一组日期转换实验。
2. 验证 `new HashMap<>(obj)` 在 2.0.62 下仍保留 Date。
3. 隔离编译修改后的公共 Java 文件。
4. 检查 Git diff 只有一个公共文件和必要测试。
5. 扫描现有解析器，确认没有依赖 Map 被深度重新解析的特殊写法。

### 发布公共 jar 后

1. 检查 Nexus 新 SNAPSHOT 的发布时间和内容。
2. 在 `scm-source-web-test` 日志中确认拉到了新时间戳 jar。
3. 检查新 Pod 已启动，旧 Pod 已替换。

### 运行验收

使用能查到 `10930000-JC-2026-0016` 的供应商账号：

1. 调 `/e/business/source/source/querySupplierSourcePageList`。
2. 确认列表有数据。
3. 确认每一行存在符合状态的 `operList`。
4. 服务日志不再出现：

   ```text
   java.lang.String cannot be cast to java.util.Date
   ```

5. 再抽查采购方寻源、报名、费用列表各一个接口。

当前 test TOKEN 对应的公司查不到这条供应商数据，所以最终按钮验收需要匹配的供应商测试账号；这属于运行验证依赖，不影响当前根因结论。

---

## 7. 最后用三句话记住

1. 代码只改公共转换器两处：不要走 JSON 泛型转换，改成保留类型的 Map 浅拷贝。
2. 部署不是只点 Jenkins：先把新公共 jar 手动发到 Nexus，再重建 source-web 镜像。
3. 必须验证是因为编译、Jenkins 绿灯、HTTP 200 都可能成功，但页面按钮仍然没有被正确补上。

