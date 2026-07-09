# scm-devops-all 新人学习文档（基于 origin/test）

> 本文基于 `01zhaocai-end/scm-devops-all` 的 `origin/test` 分支整理。  
> 这个分支最新提交在 2025-02-28，比本地当前 `dev` 分支更新，包含“运维流程”和“商城数据中台”相关代码。

## 1. 先用一句话理解这个模块

`scm-devops-all` 不是我们平时理解的 Jenkins、发布流水线那种 DevOps 平台。

在这个项目里，它更像一个“业务运维辅助模块”：

- 业务人员或运维人员遇到数据、流程、审批、消息问题时，可以通过这个服务查询或处理。
- 它不是主业务服务，但会去查 SRM、寻源、商城、工作流等业务数据。
- 它有一些接口是只查询，有一些接口会修改数据或触发审批流程。

可以先把它理解成：

```text
scm-devops-web = 给业务排查问题用的后台工具服务
```

它目前主要围绕四类事情：

```text
1. 供应商数据查询
2. 寻源/采购流程排查
3. 运维流程申请和审批
4. 商城审批数据中台查询
```

## 2. 先分清“源码模块”和“启动模块”

这个项目有一个很重要的结构：源码和启动不是放在同一个目录。

### 2.1 业务源码在哪里

业务源码在：

```text
01zhaocai-end/scm-devops-all
```

这里放的是 `scm-devops` 这个业务能力本身，比如 Controller、Service、Mapper、DTO。

### 2.2 真正启动在哪里

真正的 Spring Boot 启动工程在：

```text
03zhaocai-start/scm-cloud-starters-web/scm-cloud-devops
```

启动类是：

```text
com.pcitc.scm.devops.starter.DevopsApp
```

它启动后，服务信息大概是：

```text
服务名：scm-devops-web
默认端口：9800
访问前缀：/scm-devops-web
默认环境：dev，也可以用 APP_PROFILE 指定 test / uat / prod
```

也就是说，如果本地或环境里启动成功，接口路径大概长这样：

```text
http://host:9800/scm-devops-web/具体接口路径
```

例如：

```text
/scm-devops-web/s/business/devops/source/createOpsApply
/scm-devops-web/obs/business/devops/apply/query
```

## 3. Java 新人先理解几个常见词

先不用急着背所有模块名。先理解这几个角色。

### 3.1 Controller：接口入口

Controller 就是“别人调用这个服务时先进来的地方”。

比如前端点一个按钮，或者其他服务调用一个 HTTP 接口，最终通常会进入某个 Controller 方法。

你看到这些注解时，可以先理解为“这是接口”：

```java
@RestController
@PostMapping("xxx")
```

### 3.2 Service：业务处理

Controller 一般不直接写复杂业务逻辑，而是把事情交给 Service。

你看到这些名字时，可以理解为“做具体事情的人”：

```text
xxxService
xxxServiceImpl
```

其中 `Impl` 是 implementation 的缩写，意思是“实现类”。

### 3.3 Mapper：访问数据库

Mapper 负责和数据库打交道。

你看到这些名字时，可以理解为“查表、改表的人”：

```text
xxxMapper
```

这个项目里 Mapper 常配合 MyBatis-Plus 使用。常见写法：

```java
public interface SrmApplyMapper extends BaseMapper<SrmApply>
```

大概意思是：这个 Mapper 可以对 `SrmApply` 对应的表做常见的增删改查。

### 3.4 DTO / VO / Model 是什么

先粗略理解即可：

```text
DTO：接口传参或服务间传递的数据对象
VO：返回给前端看的数据对象
Model：和数据库表对应的 Java 对象
```

例如 `OpsApply` 是数据库表对象，`OpsApplyVO` 是接口传入/返回时用的对象。

### 3.5 Feign 是什么

Feign 可以理解成“用 Java 方法调用其他服务”。

比如 `scm-devops-web` 要查工作流审批历史，它不一定自己查数据库，而是通过 Feign 去调用 `scm-workflow-web`。

这个模块会调用很多外部服务，所以能不能跑通，不只取决于自己能不能启动，还取决于其他服务是否可用。

## 4. origin/test 的模块结构

`origin/test` 下，`scm-devops-all` 是一个 Maven 聚合工程。

它下面有这些子模块：

```text
scm-devops-all
├── scm-devops-api
├── scm-devops
├── scm-devops-source-api
├── scm-devops-source
├── scm-devops-supplier-api
├── scm-devops-supplier
├── scm-devops-mall-datacenter-api
├── scm-devops-mall-datacenter
└── scm-devops-web-jar
```

先不用把每个名字都记住。按用途分成三层看会更清楚。

### 4.1 API 模块：放数据对象

这些模块主要放 DTO、VO、枚举：

```text
scm-devops-api
scm-devops-source-api
scm-devops-supplier-api
scm-devops-mall-datacenter-api
```

它们通常不直接处理业务，只是定义“接口需要什么参数、返回什么数据”。

### 4.2 业务模块：写实际逻辑

这些模块放 Controller、Service、Mapper：

```text
scm-devops
scm-devops-source
scm-devops-supplier
scm-devops-mall-datacenter
```

它们是真正做事情的地方。

### 4.3 web-jar 模块：把业务装进 Spring Boot

```text
scm-devops-web-jar
```

这个模块很关键。它本身不写太多业务，而是通过配置告诉 Spring：

```text
把 scm-devops 下面的 Controller、Service、Mapper 都扫描进来
```

对应文件：

```text
scm-devops-web-jar/src/main/java/com/pcitc/scm/devops/webconfig/DevopsWebConfig.java
```

里面主要是：

```java
@ComponentScan(...)
@MapperScan(...)
```

你可以把它理解为“装配开关”。如果启动工程没有引入 `scm-devops-web-jar`，这些业务接口就不会生效。

## 5. 启动链路怎么串起来

从启动到接口可用，大概是这样：

```text
03/scm-cloud-devops 启动 DevopsApp
        ↓
DevopsApp @Import DevopsWebConfig
        ↓
DevopsWebConfig 扫描 scm-devops-all 里的 Controller / Service / Mapper
        ↓
Spring 容器里出现 SupplierController、SourceController、DataCenterController
        ↓
外部请求进入 Controller
        ↓
Controller 调 Service
        ↓
Service 查数据库或调用其他服务
```

如果你以后看到“接口 404”或“Bean 找不到”，就可以顺着这条链路排查：

```text
启动工程有没有依赖 scm-devops-web-jar？
DevopsApp 有没有 import DevopsWebConfig？
DevopsWebConfig 有没有扫到对应包？
Controller 上的路径是不是写对了？
```

## 6. 启动它需要依赖什么

`scm-devops-web` 不是一个完全独立的服务。它依赖很多基础设施和其他业务服务。

### 6.1 必须的基础设施

至少需要：

```text
Nacos：配置中心、注册中心
MySQL：业务数据源
Redis：OAuth、缓存、用户上下文等
公司 Nexus：下载 Maven 依赖
Java 8
Maven 3.6.x
```

### 6.2 Nacos 配置

启动工程的配置在：

```text
03zhaocai-start/scm-cloud-starters-web/scm-cloud-devops/src/main/resources
```

核心文件：

```text
bootstrap.yml
bootstrap-dev.yml
bootstrap-test.yml
bootstrap-uat.yml
bootstrap-prod.yml
```

`bootstrap.yml` 里定义了：

```text
server.port = 9800
server.servlet.context-path = /scm-devops-web
spring.application.name = scm-devops-web
```

`bootstrap-test.yml` 里定义了 test 环境的 Nacos 地址、namespace、group、账号等。文档里不记录密码，避免扩散敏感信息。

如果你本地想跑 test 环境，通常会用：

```bash
APP_PROFILE=test
```

或者 JVM 参数：

```bash
-Dspring.profiles.active=test
```

实际能不能跑通，还要看你机器是否能访问公司内网、Nacos、数据库和其他服务。

### 6.3 依赖的其他业务服务

`scm-devops-web` 会调用这些服务或能力：

```text
scm-auth-web：认证、用户上下文
scm-ubm-web：组织、工作流模板、用户组织信息
scm-source-web：寻源/采购相关数据
scm-workflow-web：审批流程、待办、审批历史
文件/附件服务：运维申请附件上传
AIM 公共调用能力：商城数据中台通过 AIM 调业务服务
```

所以学习时要有一个概念：

```text
scm-devops-web 能启动，只代表服务本身起来了。
接口能完整跑通，还要看它调用的服务是否在线、Nacos 配置是否正确、数据库是否有数据。
```

## 7. 四块核心功能

下面按业务功能介绍，不按模块名硬讲。

## 7.1 供应商数据查询

这块主要在：

```text
scm-devops-supplier
```

入口 Controller：

```text
scm-devops-supplier/src/main/java/com/pcitc/scm/devops/supplier/controller/SupplierController.java
```

它主要提供供应商相关数据的分页查询和筛选。

常见接口：

```text
POST e/business/devops/apply/getRecords
POST e/business/devops/applyBusinessData/getRecords
POST e/business/devops/company/getRecords
POST e/business/devops/mdmApply/getRecords
POST e/business/devops/onslogRecord/getRecords
POST e/business/devops/onslogRecordCus/getRecords
POST e/business/devops/applyDataRecords/getRecords
POST e/business/devops/apply/getAuditCompanyList
POST e/business/devops/apply/getApplyInfoCodeList
POST e/business/devops/apply/getBUList
POST e/business/devops/applyDataRecords/getBySupplierName
```

可以先这样理解：

```text
供应商申请表、供应商公司表、MDM 申请表、消息日志表，都可以通过这块查出来。
```

对应数据库表包括：

```text
srm_apply
srm_apply_business_data
srm_company
srm_mdm_apply
scm_onslog_record
scm_onslog_record_cus
ubm_organization_manage
```

典型调用链：

```text
SupplierController
    ↓
SrmApplyService
    ↓
SrmApplyServiceImpl
    ↓
SrmApplyMapper
    ↓
srm_apply / srm_apply_business_data / ubm_organization_manage
```

这里有一个公共查询工具：

```text
scm-devops-supplier/src/main/java/com/pcitc/scm/devops/supplier/util/Utils.java
```

它根据前端传入的筛选条件组装 MyBatis-Plus 的 `QueryWrapper`。

筛选条件大概支持：

```text
等于
不等于
大于
小于
包含
不包含
为空
不为空
```

新人看这块时，建议先看一个最简单接口：

```text
POST e/business/devops/company/getRecords
```

因为它基本就是：

```text
Controller 收到分页参数
Service 调 Utils.query
Mapper 查 srm_company
返回 PageList
```

这条链路比运维流程和跨服务调用简单，适合入门。

## 7.2 寻源/采购流程排查

这块主要在：

```text
scm-devops-source
```

入口 Controller：

```text
scm-devops-source/src/main/java/com/pcitc/scm/devops/source/controller/SourceController.java
```

其中一个重要接口：

```text
POST obs/business/devops/source/getWfInfoBySchemeId
```

它的作用是：

```text
根据采购方案编号，查询这个方案相关的工作流信息。
```

它会查这些流程：

```text
中标结果流程
供应商报名流程
澄清流程
终止流程
延期流程
```

对应 Service：

```text
scm-devops-source/src/main/java/com/pcitc/scm/devops/source/service/impl/SourceServiceImpl.java
```

典型调用链：

```text
SourceController.getWfInfoBySchemeId
    ↓
SourceServiceImpl.getWfInfoBySchemeId
    ↓
调用 scm-source-web 查询采购方案、报名、澄清、终止、延期等数据
    ↓
调用 scm-workflow-web 查询每个业务 ID 的审批节点
    ↓
组装 SourceWfInfo 返回
```

这块对新人来说难点不在 Java 语法，而在业务关系：

```text
一个采购方案下面可能关联多个业务单据；
每个业务单据又可能有自己的审批流程；
这个接口把这些流程统一查出来，方便运维排查。
```

## 7.3 运维流程申请和审批

这是 `origin/test` 比旧 `dev` 分支多出来的重要功能。

入口还是：

```text
scm-devops-source/src/main/java/com/pcitc/scm/devops/source/controller/SourceController.java
```

相关接口：

```text
POST s/business/devops/source/createOpsApply
POST s/business/devops/source/queryOpsApplyList
POST s/business/devops/source/queryOpsApplyListByGrade
POST s/business/devops/source/opsApplyStepT
```

可以先用业务语言理解：

```text
当业务上出现需要运维处理的问题时，用户可以创建一条运维申请。
申请会保存到 ops_apply 表。
同时可以上传附件。
然后系统启动一个工作流审批。
审批过程中，运维顾问可以填写补充信息或解决方案。
```

核心类：

```text
OpsApplyVO：接口传入/返回的运维申请数据
OpsApply：数据库表 ops_apply 对应的对象
OpsApplyServiceImpl：核心业务逻辑
OpsApplyMapper：操作 ops_apply 表
OpsApplySequence：生成申请编号
```

创建运维流程的主链路：

```text
SourceController.createOpsApply
    ↓
OpsApplyServiceImpl.createOpsApply
    ↓
获取当前登录用户 CurrentUserUtil.getCurrentUser()
    ↓
调用 UBM 查询当前用户所属组织
    ↓
生成运维申请编号
    ↓
写入 ops_apply 表
    ↓
上传附件
    ↓
查询工作流模板 OPS_APPLY
    ↓
调用工作流服务启动审批流程
```

这里能看到几个重要依赖：

```text
GIDService：生成编号
AttachService：处理附件
WorkflowTemplateFeignService：查询工作流模板
WorkflowFeignClientService：启动或推进工作流
OrgManagerFeignService：查询组织信息
InnerFeignService：包装内部 Feign 调用
```

审批补充信息接口：

```text
POST s/business/devops/source/opsApplyStepT
```

大概做三件事：

```text
1. 根据 applyId 查 ops_apply
2. 更新补充信息和附件
3. 调工作流 processComplete 完成当前任务
```

这部分比普通查询复杂，因为它同时涉及：

```text
数据库写入
附件
当前登录人
组织信息
工作流模板
审批流程推进
事务
```

学习时不要一上来死磕每一行。先把“创建申请 -> 上传附件 -> 启动工作流”这条主线记住。

## 7.4 商城审批数据中台

这是 `origin/test` 新增的另一块功能。

模块：

```text
scm-devops-mall-datacenter
scm-devops-mall-datacenter-api
```

入口 Controller：

```text
scm-devops-mall-datacenter/src/main/java/com/pcitc/scm/devops/mall/datacenter/controller/DataCenterController.java
```

接口：

```text
POST obs/business/devops/apply/query
POST obs/business/devops/type/query
POST obs/business/devops/message/query
```

先理解用途：

```text
商城有不同业务类型，比如商品上架审批、订单审批。
这个模块提供统一入口，根据业务类型去调用对应业务服务，查审批申请信息，并补上工作流审批历史。
```

业务类型枚举：

```text
BusinessTypeEnums
```

目前包含：

```text
product：商品上架审批申请
order：订单审批申请
```

核心逻辑：

```text
DataCenterController.query
    ↓
DataCenterServiceImpl.queryApply
    ↓
根据 businessType 找到回调配置
    ↓
通过 AIM 调对应业务服务
    ↓
拿到申请数据
    ↓
调用 workflow 查询审批历史
    ↓
返回给前端
```

这里的 AIM 可以先理解成：

```text
一种统一的跨业务调用机制。
```

比如 `product` 类型对应：

```text
product-productApplyService-queryApply
```

大致意思是：

```text
去 product 业务里找 productApplyService 的 queryApply 能力。
```

这个模块目前还有一个接口：

```text
POST obs/business/devops/message/query
```

但 Service 里 `queryMessage` 当前还是空实现，说明可能是预留或尚未完成。

## 8. 数据源怎么理解

这个模块会查多个数据库，不是只连一个库。

代码里经常能看到：

```java
@DS("srm")
@DS("source")
@DS("ubm")
@DS("scm")
```

可以这样理解：

```text
srm：供应商相关库
source：寻源/采购相关库
ubm：用户、组织、运维申请等相关库
scm：平台或组织相关库
```

这些数据源的真实连接信息不在代码里，通常在 Nacos 的配置里。

所以如果启动时报类似下面的问题：

```text
Cannot find datasource srm
Cannot find datasource source
Cannot find datasource ubm
```

优先去查 Nacos 配置，而不是只看 Java 代码。

## 9. 推荐学习路线

不要从所有模块名开始背。建议按下面顺序。

### 第一步：理解启动

先看：

```text
03zhaocai-start/scm-cloud-starters-web/scm-cloud-devops
```

重点文件：

```text
pom.xml
src/main/java/com/pcitc/scm/devops/starter/DevopsApp.java
src/main/resources/bootstrap.yml
src/main/resources/bootstrap-test.yml
```

目标是搞清楚：

```text
服务叫什么？
端口是多少？
context-path 是什么？
通过哪个配置中心拿配置？
它 import 了哪些能力？
```

### 第二步：理解装配

看：

```text
scm-devops-web-jar/src/main/java/com/pcitc/scm/devops/webconfig/DevopsWebConfig.java
```

目标是搞清楚：

```text
为什么业务源码里的 Controller 能被启动工程识别？
Mapper 是怎么被扫描的？
```

### 第三步：看最简单查询链路

推荐从供应商查询开始：

```text
SupplierController.getSrmCompanyList
    ↓
SrmCompanyService
    ↓
SrmCompanyServiceImpl
    ↓
SrmCompanyMapper
    ↓
srm_company
```

这一条链路比较适合 Java 新人，因为逻辑简单。

### 第四步：看寻源流程排查

看：

```text
SourceController.getWfInfoBySchemeId
SourceServiceImpl.getWfInfoBySchemeId
```

目标是理解：

```text
怎么根据采购方案查出多个业务流程？
怎么调用工作流服务查审批节点？
```

### 第五步：看 origin/test 新增运维流程

看：

```text
SourceController.createOpsApply
OpsApplyServiceImpl.createOpsApply
OpsApplyServiceImpl.opsApplyStepT
```

目标是理解：

```text
怎么创建运维申请？
怎么写 ops_apply 表？
怎么上传附件？
怎么启动工作流？
怎么推进审批任务？
```

### 第六步：看商城数据中台

看：

```text
DataCenterController
DataCenterServiceImpl
BusinessTypeEnums
```

目标是理解：

```text
怎么根据业务类型调用不同业务服务？
怎么补充审批历史？
```

## 10. 本地学习建议

### 10.1 不要直接在 dev 上学习最新代码

当前本地 `dev` 停在 2023-12，`origin/test` 才有 2025 年的运维流程代码。

建议创建一个本地学习分支：

```bash
cd /home/t/projects/work-wsl/01zhaocai-end/scm-devops-all
git switch -c learn-devops-test origin/test
```

启动仓库也建议对应看 `origin/test`：

```bash
cd /home/t/projects/work-wsl/03zhaocai-start/scm-cloud-starters-web
git switch -c learn-starter-test origin/test
```

如果你暂时不想切分支，也可以像这份文档一样，用：

```bash
git show origin/test:文件路径
```

直接查看 `origin/test` 上的文件。

### 10.2 不要随便执行 deploy

`scm-devops-all/pom.xml` 里配置了 Maven deploy 插件，且仓库指向公司 Nexus。

学习阶段不要运行：

```bash
mvn deploy
```

否则可能会往公司私服发布包。

### 10.3 可以先做只读学习

刚开始建议先做：

```text
看代码
画调用链
查接口
查表名
读 Nacos 配置
本地尝试启动
```

不要一开始就改数据类接口，尤其是：

```text
OataskController.updateStateBySchemeCode
OpsApplyServiceImpl.opsApplyStepT
```

这些接口有修改数据或推进流程的行为。

## 11. 启动排查清单

如果你要启动 `scm-devops-web`，可以按这个清单检查。

### 11.1 Java 和 Maven

```bash
java -version
mvn -version
```

建议：

```text
Java 8
Maven 3.6.x
```

### 11.2 Nexus

项目依赖公司 Maven 私服。确认：

```text
~/.m2/settings.xml 配好了
nexus.jdsn.com.cn 能访问
公司 VPN / 内网可用
```

### 11.3 Nacos

确认：

```text
Nacos 地址可访问
namespace 正确
group 正确
scm-devops-web 的配置存在
global-config.yaml 存在
```

### 11.4 数据源

确认 Nacos 里至少有这些动态数据源配置：

```text
srm
source
ubm
scm
```

### 11.5 依赖服务

如果只是启动，可能不一定要求所有业务服务都启动。

但如果要完整调用接口，通常依赖：

```text
scm-auth-web
scm-ubm-web
scm-source-web
scm-workflow-web
附件服务相关能力
AIM 对应业务服务，例如 product/order
```

### 11.6 常见现象

```text
启动时连不上 Nacos：先查 APP_PROFILE、nacos.ip、namespace。
接口 401/403：先查 token、认证服务、网关鉴权。
数据源不存在：先查 Nacos 动态数据源。
Feign 调用失败：先查目标服务是否在 Nacos 注册。
接口 404：先查 context-path 和 Controller 路径是否拼对。
工作流接口失败：先查工作流服务、模板配置、businessType。
```

## 12. 几个容易混淆的点

### 12.1 `devops` 不是发布平台

这里的 `devops` 更偏业务运维，不是 Jenkins/Kubernetes 那类发布系统。

### 12.2 `scm-devops-all` 不能单独当服务启动

它是源码聚合工程。真正启动要看：

```text
03zhaocai-start/scm-cloud-starters-web/scm-cloud-devops
```

### 12.3 Controller 路径没有统一写类级别前缀

很多 Controller 没有 `@RequestMapping` 写在类上，而是每个方法直接写完整路径。

比如：

```java
@PostMapping("s/business/devops/source/createOpsApply")
```

最终访问时还要加上服务的 context-path：

```text
/scm-devops-web/s/business/devops/source/createOpsApply
```

### 12.4 `origin/test` 和本地 `dev` 差异很大

`origin/test` 多了：

```text
scm-devops-mall-datacenter
scm-devops-mall-datacenter-api
OpsApply 运维流程相关代码
scm-cloud-devops 启动类里的 UBM Feign、SinoSupport 导入
```

所以学习最新代码时，不要只看本地 `dev`。

## 13. 你可以怎么向同事确认

如果你要和领导或同事确认方向，可以这样问：

```text
我看了 scm-devops-all 的 origin/test 分支，当前主要有供应商查询、寻源流程排查、运维流程申请、商城审批数据中台这几块。后续我应该重点熟悉哪一块？如果近期会接需求，是不是优先看 origin/test 里的运维流程 OpsApply 相关代码？
```

这比单纯问“我该看哪个模块”更高效，因为你已经把自己看过的内容和候选方向说清楚了。

## 14. 当前建议重点

如果没人特别指定，我建议你按这个优先级学习：

```text
1. 启动链路：scm-cloud-devops + DevopsApp + DevopsWebConfig
2. 简单查询：SupplierController -> SrmCompanyServiceImpl -> SrmCompanyMapper
3. 运维流程：SourceController -> OpsApplyServiceImpl -> ops_apply -> workflow
4. 数据中台：DataCenterController -> AIM -> workflow history
5. 寻源排查：SourceServiceImpl.getWfInfoBySchemeId
```

这样学的好处是：

```text
先知道服务怎么起来；
再从简单查询建立 Controller-Service-Mapper 的感觉；
然后进入 origin/test 最新的运维流程；
最后再看跨服务调用和工作流这类复杂链路。
```

