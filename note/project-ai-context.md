# 招采项目 AI 快速上下文

本文档给后续 AI 使用，目标是快速判断项目结构、启动入口、源码位置和依赖关系。不要把它当成完整业务说明书；更深的业务逻辑仍需按模块进入源码分析。

## 当前结论

- 当前工作区不是一个单一 Git 仓库，而是多个 Git 仓库按目录放在一起：`01zhaocai-end`、`02zhaocai-front`、`03zhaocai-start`、`note`。
- 后端主线不是 `01` 和 `03` 独立运行，而是：`01zhaocai-end` 提供业务源码、公共组件、BOM 和可被依赖的 jar；`03zhaocai-start/scm-cloud-starters-web` 提供各微服务的 Spring Boot 启动工程。
- `03zhaocai-start/scm-cloud-starters-web/pom.xml` 的父 POM 是 `com.pcitc:scm-cloud-bom:1.0.0-JDSN-SNAPSHOT`，本地对应目录是 `01zhaocai-end/scm-cloud-bom`，但它的父级 `scm-cloud-parent` 当前本地只有 README，没有 POM，实际解析依赖需要公司 Nexus。
- 当前本地有些 `01zhaocai-end/*-all` 仓库只有 README 和 Git 元数据，没有源码/POM，例如 `scm-order-all`、`scm-product-all`、`scm-file-all`、`scm-ubm-all`、`scm-platform-all`、`scm-mdm-all`。遇到这些服务时，先确认是否分支不对、未拉全，还是只能通过 Nexus 里的二进制 jar 使用。
- 当前后端技术栈以 Java 8、Maven、Spring Boot、Spring Cloud Alibaba Nacos、OpenFeign、MyBatis/MyBatis-Plus、Redis、Elasticsearch、XXL-JOB 为主。

## 本地目录角色

| 路径 | 角色 | 后续定位优先级 |
| --- | --- | --- |
| `03zhaocai-start/scm-cloud-starters-web` | 后端微服务启动聚合工程，包含网关、认证、供应商、寻源、订单等启动模块 | 最高。查启动类、端口、profile、依赖 jar 先看这里 |
| `01zhaocai-end` | 后端业务源码、公共组件、BOM、依赖封装仓库集合 | 高。查具体 controller/service/mapper/webconfig/API 先看这里 |
| `01zhaocai-end/scm-cloud-bom` | 版本管理 BOM，父级来自 `scm-cloud-parent` | 高。查版本和 dependencyManagement |
| `01zhaocai-end/scm-cloud-assemblies` | 公共组件版本聚合：common、oauth2、custom 组件 | 高。查公共 jar 的版本来源 |
| `01zhaocai-end/scm-cloud-dependencies` | 框架依赖封装：api、oauth2、orm、user、export、innerfeign、gateway、elasticsearch | 高。查基础能力和自动配置 |
| `01zhaocai-end/scm-assemblies-all` | 共享组件源码集合：common、cache、db、mq、seq、workflow、rule、es、aim、scheduling | 中高。查 `scm-share-*` 和 `xxl-job-*` |
| `02zhaocai-front` | 前端仓库集合，来自 GitLab `scm-zc/scm-vue` 前端项目组；当前已部分克隆并切到 `prod` | 中 |
| `03zhaocai-start/mybatis-plus-generate` | MyBatis-Plus 代码生成器 | 低。生成实体/controller/mapper/service 时再看 |
| `03zhaocai-start/scm-cloud-starters-wfproduct` | 工作流产品相关启动工程/打包内容 | 低到中。和主 `scm-cloud-starters-web` 分开看 |

## Maven 和私服

- 公司 Nexus 域名：`nexus.jdsn.com.cn`，同事说明解析到 `10.0.54.19`。
- 多个 POM 使用 HTTP 仓库：`http://nexus.jdsn.com.cn/repository/maven-public/`。Maven `3.8.1+` 默认会拦截 HTTP 仓库，建议本项目用 Maven `3.6.3`。
- `mvn -U dependency:tree -DskipTests` 已能成功执行，说明当前 WSL 的 Java/Maven/Nexus 访问和依赖下载基本可用。
- 不要随意运行 `mvn deploy`。deploy 会发布到公司 Nexus，通常需要账号权限，也可能污染私服版本。
- `01zhaocai-end/scm-all/README.md` 里有历史 Maven settings 和凭据信息。后续 AI 不要复制或扩散密码；只提示用户找同事确认 settings。

## 前端仓库克隆状态

- 前端 GitLab 组：`http://10.0.65.220:9090/scm-zc/scm-vue`，本地目标目录：`/home/t/projects/work-wsl/02zhaocai-front`。
- WSL SSH 配置里 GitLab host 别名是 `company-gitlab`；克隆地址格式为 `company-gitlab:scm-zc/scm-vue/<repo>.git`。不要记录或复述 SSH 私钥内容。
- 2026-07-08 已从该组识别到 44 个仓库；其中 26 个已在本地且当前分支均为 `prod`。当时 GitLab SSH 端口 `55022` 临时拒绝连接，剩余仓库未完成克隆。
- 待继续克隆的前端仓库：`scm-vue-all-ubm`、`scm-vue-all-vmp`、`scm-vue-all-workbench`、`scm-vue-components`、`scm-vue-configmgt`、`scm-vue-forcepassword`、`scm-vue-forgetpassword`、`scm-vue-hpc`、`scm-vue-login`、`scm-vue-login-v2`、`scm-vue-mall-app`、`scm-vue-order-supplier`、`scm-vue-pc-expertmgt`、`scm-vue-platform`、`scm-vue-templatemgt`、`scm-vue-uniapp`、`scm-vue-user-supplier`、`scm-vue-workbench`。

## 版本和运行环境

- Java：Java 8。已配置过 `corretto-1.8 Amazon Corretto 1.8.0_492`，语言级别 8。
- Maven：建议 `3.6.3`，原因是公司 Nexus HTTP 仓库。
- Spring Boot Maven Plugin：`2.2.6.RELEASE`，见 `03zhaocai-start/scm-cloud-starters-web/pom.xml`。
- Docker 基础镜像使用 JDK 8，例如 `harbor.caas.cn/zhny-jcpt/openjdk8:x86_64-centos-jdk8u322-b06-promtail-v3`。
- 默认 profile 多数是 `${APP_PROFILE:dev}`；配置中心使用 Nacos，dev/test 常见地址默认值是 `10.0.54.19:8848`。

## POM 层级

主要链路：

```text
scm-cloud-parent
  -> scm-cloud-bom
       -> 业务 *-all 聚合工程
       -> scm-cloud-starters-web
```

`scm-cloud-bom` import 了：

- `scm-assembly`
- `scm-assembly-oauth2`
- `scm-assembly-custom`

`scm-cloud-assemblies` 下三个 POM 的职责：

- `scm-assembly`：管理 `scm-common-*`，如 utils、api、json、excel、pdf、qr、vcode 等。
- `scm-assembly-oauth2`：管理 `scm-cloud-dependencies-*`、`scm-share-aim-*`、`scm-share-cache-*`。
- `scm-assembly-custom`：管理 `scm-share-seq-*`、`scm-share-mq-*`、`scm-share-workflow-*`、`scm-share-es-*`、`scm-share-rule-*`、`scm-share-file-*`、`xxl-job-*`。

`scm-cloud-dependencies` 下的关键封装：

- `scm-cloud-dependencies-api`：公共 API 基础依赖。
- `scm-cloud-dependencies-oauth2`：认证、JWT、OpenFeign、Redis 等。
- `scm-cloud-dependencies-orm`：ORM/MyBatis-Plus 相关。
- `scm-cloud-dependencies-user`：用户上下文相关。
- `scm-cloud-dependencies-export`：导出相关。
- `scm-cloud-dependencies-innerfeign`：内部 Feign 调用封装。
- `scm-cloud-dependencies-gateway`：Spring Cloud Gateway、Nacos、Sentinel、Redis Session、Knife4j 等。
- `scm-cloud-dependencies-elasticsearch`：Elasticsearch client / Spring Data Elasticsearch。

## 启动工程索引

`03zhaocai-start/scm-cloud-starters-web` 是启动聚合工程。根 POM modules 包含以下服务：

| 启动模块 | application name | 默认端口 | 启动类 | 主要业务 jar / 依赖线索 |
| --- | --- | --- | --- | --- |
| `scm-cloud-gateway` | `scm-gateway-web` | `9900` | `com.pcitc.gateway.GatewayApp` | `scm-gateway-web-jar`、`scm-auth-feign-api`、gateway dependencies |
| `scm-cloud-gateway-mall` | `scm-gateway-mall-web` | `9900` | `com.pcitc.gateway.GatewayApp` | 商城网关，依赖与 gateway 类似 |
| `scm-cloud-auth` | `scm-auth-web` | `8000` | `com.pcitc.scm.auth.AuthApp` | `scm-auth-web-jar`，源码在 `01zhaocai-end/scm-auth-all` |
| `scm-cloud-ubm` | `scm-ubm-web` | `8100` | `com.pcitc.scm.ubm.starter.UbmApp` | `scm-ubm-web-jar`、`scm-template-web-jar`、`scm-plateform-web-jar`、`scm-mdm-web-jar`；本地对应多个仓库当前可能不完整 |
| `scm-cloud-ubm-mall` | `scm-ubm-mall-web` | `8100` | `com.pcitc.scm.ubm.starter.UbmApp` | 商城基础管理启动模块 |
| `scm-cloud-statics` | `scm-statics` | `8001` | `com.pcitc.scm.statics.starter.StaticsApp` | 静态资源服务，resources/public 下有静态内容 |
| `scm-cloud-file` | `scm-file-web` | `8003` | `com.pcitc.scm.file.FileApp` | `scm-share-file-web-jar`；本地 `scm-file-all` 当前只有 README |
| `scm-cloud-professor` | `scm-professor-web` | `8002` | `com.pcitc.scm.professor.springboot.ProfessorApp` | `scm-professor-web-jar`，专家管理 |
| `scm-cloud-source` | `scm-source-web` | `8110` | `com.pcitc.scm.source.starter.SourceApp` | `scm-source-web-jar`，源码在 `01zhaocai-end/scm-source-all` |
| `scm-cloud-srm` | `scm-srm-web` | `8130` | `com.pcitc.scm.srm.starter.SrmApp` | `scm-srm-web-jar`，源码在 `01zhaocai-end/scm-srm-all` |
| `scm-cloud-contract` | `scm-contract-web` | `8150` | `com.pcitc.scm.contract.starter.ContractApp` | `scm-contract-web-jar`，源码在 `01zhaocai-end/scm-contract-all` |
| `scm-cloud-fee` | `scm-fee-web` | `8160` | `com.pcitc.scm.fee.starter.FeeApp` | `scm-fee-web-jar`、`scm-pay-web-jar`，当前本地未见对应源码目录 |
| `scm-cloud-order` | `scm-order-web` | `8200` | `com.pcitc.scm.order.starter.OrderApp` | `scm-order-web-jar`；本地 `scm-order-all` 当前只有 README |
| `scm-cloud-product` | `scm-product-web` | `8300` | `com.pcitc.scm.product.starter.ProductApp` | `scm-product-web-jar`；本地 `scm-product-all` 当前只有 README |
| `scm-cloud-ifs` | `scm-ifs-web` | `8083` | `com.pcitc.scm.ifs.starter.IfsApp` | `scm-ifs-web-jar`，源码在 `01zhaocai-end/scm-ifs-all` |
| `scm-cloud-scheduling` | `scm-scheduling-web` | `8902` | `com.pcitc.scm.xxljob.web.starter.XxlJobApp` | `xxl-job-web-jar`，源码在 `01zhaocai-end/scm-assemblies-all/scm-scheduling-all` |
| `scm-cloud-workflow` | `scm-workflow-web` | `9800` | `com.pcitc.scm.workflow.starter.WorkflowApp` | `scm-workflow-web-jar`、`scm-share-workflow-*` |
| `scm-cloud-report` | `scm-report-web` | `80` | `com.pcitc.scm.report.starter.ReportApp` | `scm-report-web-jar`、`scm-share-es-web-jar`；ES 报表服务 |
| `scm-cloud-devops` | `scm-devops-web` | `9800` | `com.pcitc.scm.devops.starter.DevopsApp` | `scm-devops-web-jar` |

注意：`scm-cloud-ifs-schedule` 目录存在资源文件，但不在 `scm-cloud-starters-web/pom.xml` 的 modules 列表中。不要把它当成默认构建模块，除非后续 POM/分支另有说明。

## 业务源码定位规则

查一个接口或业务问题时，按这个顺序定位：

1. 先在 `03zhaocai-start/scm-cloud-starters-web/<启动模块>/pom.xml` 看它依赖哪个 `*-web-jar`、`*-feign-api`。
2. 再到 `01zhaocai-end/<业务>-all` 下找对应模块：
   - `*-web-jar`：通常放 controller、webconfig、mapper scan、服务装配，是启动工程真正引入的业务 Web 层。
   - `*-api`：实体、DTO、接口契约、常量、枚举或公共模型。
   - `*-feign-api`：跨服务 Feign 客户端接口。
   - 无后缀业务模块：通常是核心领域/服务实现。
   - `*-springboot`：一些老的独立启动方式，现在主线多用 `03` 的 starter。
3. 如果本地没有对应源码，先用 `mvn dependency:tree` 确认 artifact 来自 Nexus，再让用户确认是否还有仓库/分支未克隆。

已确认本地源码较完整的业务仓库：

- `01zhaocai-end/scm-auth-all`：认证/授权。
- `01zhaocai-end/scm-contract-all`：合同。
- `01zhaocai-end/scm-datacenter-all`：数据中心。
- `01zhaocai-end/scm-ifs-all`：接口/集成服务，模块很多，含外部系统、短信、日志、主数据、消息等。
- `01zhaocai-end/scm-source-all`：寻源/采购流程，模块最多之一。
- `01zhaocai-end/scm-srm-all`：供应商管理。
- `01zhaocai-end/scm-cloud-dependencies`、`scm-cloud-assemblies`、`scm-assemblies-all`：公共能力和依赖封装。

当前只看到 README、未看到业务源码/POM 的仓库包括：

- `scm-file-all`
- `scm-gateway-all`
- `scm-mdm-all`
- `scm-order-all`
- `scm-platform-all`
- `scm-product-all`
- `scm-professor-all`
- `scm-template-all`
- `scm-ubm-all`
- `scm-workflow-all`

这些目录的 README 说明了业务名，但不能证明源码已在本地。

## 配置中心和 profiles

每个启动模块一般都有：

```text
src/main/resources/bootstrap.yml
src/main/resources/bootstrap-dev.yml
src/main/resources/bootstrap-test.yml
src/main/resources/bootstrap-uat.yml
src/main/resources/bootstrap-prod.yml
```

常见模式：

- `bootstrap.yml` 定义 `server.port`、`spring.application.name`、`spring.profiles.active`。
- 默认 profile 多数为 `${APP_PROFILE:dev}`。
- `bootstrap-dev.yml` 使用 Nacos，默认 `nacos.ip` 多数是 `10.0.54.19:8848`，namespace 多数是 `scm-jdsn`。
- `test` namespace 常见为 `scm-jdsn-test`，`uat` 为 `scm-jdsn-uat`，`prod` 为 `jdsn-prod`。
- 具体数据库、Redis、MQ 等业务配置很可能在 Nacos 中，不一定在本地文件里。

本地单服务启动时常见 VM/options 或环境变量：

```bash
-Dspring.profiles.active=dev
APP_PROFILE=dev
nacos.ip=10.0.54.19:8848
```

实际以模块 `bootstrap*.yml` 和公司 Nacos 配置为准。

## Spring Boot 装配方式

`03` 的启动类通常只保留 Spring Boot 启动壳，实际 controller/service/mapper 通过依赖 jar 的 `@ComponentScan`、`@MapperScan` 或配置类装配进来。

典型例子：

- `01zhaocai-end/scm-auth-all/scm-auth-web-jar/src/main/java/com/pcitc/scm/auth/webconfig/AuthWebConfig.java`
- `01zhaocai-end/scm-contract-all/scm-contract-web-jar/src/main/java/com/pcitc/scm/contract/webconfig/ContractWebConfig.java`
- `01zhaocai-end/scm-source-all/scm-source-web-jar/src/main/java/com/pcitc/scm/source/webconfig/SourceWebConfig.java`
- `01zhaocai-end/scm-srm-all/scm-srm-web-jar/src/main/java/com/pcitc/scm/srm/webconfig/SrmWebConfig.java`
- `01zhaocai-end/scm-ifs-all/scm-ifs-web-jar/src/main/java/com/pcitc/scm/ifs/webconfig/IfsWebConfig.java`

因此查接口时，不要只看 `03` 的启动类；要顺着 starter POM 依赖进入 `01` 的 `*-web-jar`。

## 集采驾驶舱、导出和 XXL Job 线索

- `scm-cloud-source` 导入了 `SourceWebConfig`、`ExportWebConfig`、`XxljobExecutorWebConfig`，因此 `scm-source-all` 内的 controller/service/mapper、通用导出、XXL Job 执行器都会装配进 `scm-source-web`。
- 集采驾驶舱现有接口在 `01zhaocai-end/scm-source-all/scm-source-source/src/main/java/com/pcitc/scm/source/source/controller/SourceQueryController.java`：`GET /e/business/source/source/cockpit_collection_data_{typeCode}`。
- 煤炭重点坑口块的现有前端在 `02zhaocai-front/scm-vue-all-cockpit/src/views/procurementCatalogMgt/index.vue`：固定请求上述接口的 `typeCode=kengk`，把 `dataDesc` 映射为坑口名、`dataValue` 映射为价格，单位前端固定为“元/吨”。需求2开发前，后端虽已有 `KENGK` 枚举和 `queryKengk()` 占位方法，但仍走 `sc_collection_data` 的通用缓存查询；test 库有 5 条 `kengk` 旧数据，`collectionShow` 字典没有 `kengk` 开关项。
- 2026-07-10 需求2开发后：`test` 提交 `fcfbfd9ff` 已新增 `sc_coal_pit_daily_indicator` 主表、`sc_coal_pit_daily_indicator_item` 明细表对应代码和 `/e/business/source/coalPitDailyIndicator/*` 管理接口；驾驶舱 `kengk` 在 `SourceCollectionDataServiceImpl` 中优先直接调用台账实时查询，不再读取 `sc_collection_data`，无有效台账时返回空列表。长期开发分支为 `feature/taizhang-yang`。
- 当前驾驶舱读取有两种模式：`SourceCollectionDataServiceImpl` 会先查 UBM 字典 `collectionShow`，开关为 `1` 时实时 SQL 汇总 `sc_source_collection`，否则按 `data_type` 读取缓存表 `sc_collection_data`。
- 现有集采数据刷新服务是 `SourceCollectionServiceImpl.gatherData(SourceCollectionGatherParam)`；不传 `finalDate` 时默认取昨天，并依次执行 `gatherSource`、`gatherSap`、`gatherOrder`、`gatherFpt` 写入 `sc_source_collection`。
- XXL Job 执行器通用 handler 是 `simpleJobHandler`，它读取 XXL Job 参数并通过 AIM 调用带 `@TypeMapping` / `@MethodMapping` 的业务方法。`SourceCollectionService` 已标注 `@TypeMapping("sourceCollectionService")` 和 `@MethodMapping("gatherData")`。
- 通用 Excel 导出来自 `scm-cloud-dependencies-export`。查询接口常见做法是加 `@DataRequestTransfer(exportValue = {@ExportRequestTransfer()})`，请求传 `exportRequest=true` 和 `exportTemplateCode`；列配置来自模板服务和数据库表 `scm_simple_template`、`scm_simple_template_sub`。
- UBM 数据字典代码在 `01zhaocai-end/scm-ubm-all/scm-ubm-basicdict`，核心表是 `ubm_dict_group`、`ubm_dict_type`、`ubm_dict`。常用查询接口是 `/c/business/ubm/dict/query`，请求体用 `cate` 传字典类型编码；页面维护接口包括 `/c/business/ubm/dictGroup/queryDictGroupTree`、`/c/business/ubm/dictType/save`、`/c/business/ubm/dict/save`。
- 2026-07-09 查询 `scm_ubm_test`：`Owningplate`（所属板块）已存在于 `ubm_dict_type`，且 `ubm_dict` 下有 10 个启用选项 `BU001`~`BU010`；`collection_category`（集采类目）不存在，`1501/1701/2302/2502` 及“钢材/润滑剂/电线电缆/轴承及备件”在 `scm_ubm`、`scm_ubm_test`、`scm_ubm_uat` 字典值中均未命中。

## 构建、部署和 CI

- `03zhaocai-start/scm-cloud-starters-web` 和多数子模块都有 `Dockerfile`、`Jenkinsfile`。
- Dockerfile 逻辑：把 Maven 产物 `target/${JAR_FILE}` 加入镜像，入口使用 `java -javaagent:/usr/local/skywalking-agent/skywalking-agent.jar -jar -server -Dspring.profiles.active=${APP_PROFILE}`。
- Jenkinsfile 逻辑：拉代码、进入 `PROJECT_DIR`、执行 `mvn versions:set ... && mvn clean install -U -DskipTests=true`、构建镜像、推送 Harbor、用 kubectl 部署。
- Jenkinsfile 里可能含历史凭据或环境信息。后续 AI 不要复述密码；只说明需要 Jenkins 凭据/Harbor/KubeConfig。

## 推荐给后续 AI 的工作流

- 回答项目问题前，先读本文件和根目录 `AGENT.md`。
- 需要查某个服务时，先进入 `03zhaocai-start/scm-cloud-starters-web/<服务>` 看 `pom.xml`、`bootstrap.yml`、启动类。
- 需要查业务实现时，按 artifactId 进入 `01zhaocai-end/<业务>-all`，优先搜 controller/service/mapper/repositories/webconfig。
- 搜代码优先用 `rg`，不要全量打开所有文件。
- 遇到依赖不存在、源码缺失、父 POM 缺失时，优先判断是否来自 Nexus，不要立刻认定项目坏了。
- 不要运行会修改私服或远端环境的命令：`mvn deploy`、发布镜像、`kubectl apply`、数据库写操作等，除非用户明确要求。
