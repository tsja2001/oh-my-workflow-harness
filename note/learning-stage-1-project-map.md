# 阶段 1：项目地图

本阶段目标：先看懂项目长什么样，知道“入口在哪里、业务代码在哪里、配置在哪里”。不要一开始钻进业务细节，也不要试图理解每个模块。

## 你现在要形成的核心认知

这个项目可以先理解成三层：

```text
启动层：03zhaocai-start/scm-cloud-starters-web
业务层：01zhaocai-end/*-all
公共层：01zhaocai-end/scm-cloud-dependencies、scm-cloud-assemblies、scm-assemblies-all
```

### 1. 启动层

路径：

```text
03zhaocai-start/scm-cloud-starters-web
```

这里是后端微服务的启动工程。你平时想启动某个服务、看服务名、端口、Nacos profile、Docker/Jenkins，一般先看这里。

例如：

```text
scm-cloud-auth
scm-cloud-gateway
scm-cloud-srm
scm-cloud-source
scm-cloud-contract
scm-cloud-order
scm-cloud-product
```

这些目录不是完整业务源码本体，更像“启动壳”。它们通过 Maven 依赖把业务 jar 拉进来。

### 2. 业务层

路径：

```text
01zhaocai-end
```

这里放业务源码和业务模块。

比较重要的完整源码仓库：

```text
01zhaocai-end/scm-auth-all
01zhaocai-end/scm-srm-all
01zhaocai-end/scm-source-all
01zhaocai-end/scm-contract-all
01zhaocai-end/scm-ifs-all
01zhaocai-end/scm-datacenter-all
```

目前有些目录本地只看到 README，没有源码/POM，例如：

```text
scm-order-all
scm-product-all
scm-file-all
scm-ubm-all
scm-platform-all
scm-mdm-all
scm-workflow-all
```

这不一定代表项目坏了，可能是：

- 仓库没有拉全。
- 分支不对。
- 公司只通过 Nexus 私服提供二进制 jar。
- 这些模块源码在其他仓库。

### 3. 公共层

这些模块不是具体业务，而是项目基础能力：

```text
01zhaocai-end/scm-cloud-bom
01zhaocai-end/scm-cloud-dependencies
01zhaocai-end/scm-cloud-assemblies
01zhaocai-end/scm-assemblies-all
```

作用大概是：

- `scm-cloud-bom`：统一版本管理。
- `scm-cloud-dependencies`：封装 Spring、OAuth2、ORM、Feign、Gateway、Elasticsearch 等依赖。
- `scm-cloud-assemblies`：统一管理公共组件版本。
- `scm-assemblies-all`：公共组件源码，比如 common、cache、mq、seq、workflow、rule、xxl-job。

## 01 和 03 的关系

这点最重要。

`03zhaocai-start/scm-cloud-starters-web` 不是和 `01zhaocai-end` 无关的老项目。它依赖 `01` 里的业务 jar 和公共组件。

典型关系：

```text
03/scm-cloud-srm
  -> 依赖 scm-srm-web-jar
  -> 源码在 01/scm-srm-all/scm-srm-web-jar

03/scm-cloud-source
  -> 依赖 scm-source-web-jar
  -> 源码在 01/scm-source-all/scm-source-web-jar

03/scm-cloud-contract
  -> 依赖 scm-contract-web-jar
  -> 源码在 01/scm-contract-all/scm-contract-web-jar
```

所以以后查功能时，不要只看 `03`。`03` 负责启动，真正业务逻辑通常在 `01`。

## 一个服务应该怎么看

以 `scm-cloud-srm` 为例。

先看启动模块：

```text
03zhaocai-start/scm-cloud-starters-web/scm-cloud-srm
```

重点文件：

```text
pom.xml
src/main/resources/bootstrap.yml
src/main/resources/bootstrap-dev.yml
src/main/java/com/pcitc/scm/srm/starter/SrmApp.java
```

分别看什么：

- `pom.xml`：这个服务依赖了哪些业务 jar、公共 jar、Feign API。
- `bootstrap.yml`：服务名、端口、默认 profile。
- `bootstrap-dev.yml`：Nacos 地址、namespace、group。
- `SrmApp.java`：Spring Boot 启动类。

然后看业务源码：

```text
01zhaocai-end/scm-srm-all
```

重点目录：

```text
scm-srm-web-jar
scm-srm-api
scm-srm-feign-api
scm-srm
scm-srm-apply
scm-srm-company
scm-srm-address
```

大致理解：

- `scm-srm-web-jar`：被启动工程引入，通常有 Controller、WebConfig、MapperScan。
- `scm-srm-api`：公共模型、DTO、接口定义。
- `scm-srm-feign-api`：给别的服务调用 SRM 用。
- `scm-srm-*`：具体业务子模块。

## 启动模块速查表

| 启动模块 | 服务名 | 默认端口 | 作用 |
| --- | --- | --- | --- |
| `scm-cloud-gateway` | `scm-gateway-web` | `9900` | 后台网关 |
| `scm-cloud-gateway-mall` | `scm-gateway-mall-web` | `9900` | 商城网关 |
| `scm-cloud-auth` | `scm-auth-web` | `8000` | 认证授权 |
| `scm-cloud-srm` | `scm-srm-web` | `8130` | 供应商管理 |
| `scm-cloud-source` | `scm-source-web` | `8110` | 寻源/采购流程 |
| `scm-cloud-contract` | `scm-contract-web` | `8150` | 合同 |
| `scm-cloud-ifs` | `scm-ifs-web` | `8083` | 外部接口/集成 |
| `scm-cloud-order` | `scm-order-web` | `8200` | 订单 |
| `scm-cloud-product` | `scm-product-web` | `8300` | 商品 |
| `scm-cloud-file` | `scm-file-web` | `8003` | 文件 |
| `scm-cloud-professor` | `scm-professor-web` | `8002` | 专家 |
| `scm-cloud-scheduling` | `scm-scheduling-web` | `8902` | XXL-JOB 调度 |
| `scm-cloud-workflow` | `scm-workflow-web` | `9800` | 工作流 |
| `scm-cloud-report` | `scm-report-web` | `80` | 报表/ES |
| `scm-cloud-ubm` | `scm-ubm-web` | `8100` | 基础管理 |
| `scm-cloud-statics` | `scm-statics` | `8001` | 静态资源 |

## 你需要认识的模块命名

### `*-web-jar`

最重要。

启动工程通常依赖它。它负责把某个业务模块的 Web 层装配进 Spring Boot 应用。

你查接口时，经常要从这里开始找 Controller 或 WebConfig。

### `*-api`

通常放：

- DTO
- VO
- Entity
- 枚举
- 常量
- 公共接口模型

### `*-feign-api`

服务间调用的接口定义。

比如 `scm-source` 想调用 `scm-srm`，可能会依赖 `scm-srm-feign-api`。

### `scm-cloud-dependencies-*`

框架级依赖封装。

比如：

- ORM
- OAuth2/JWT
- Feign
- Gateway
- Elasticsearch
- User Context

### `scm-share-*`

共享能力。

比如：

- 缓存
- MQ
- 序列号
- 工作流
- 规则
- ES
- 定时任务

## 第一阶段练习

### 练习 1：看启动工程有哪些服务

执行：

```bash
cd /home/t/projects/work-wsl/03zhaocai-start/scm-cloud-starters-web
find . -maxdepth 1 -type d -name 'scm-cloud-*' | sort
```

你要观察：

- 哪些目录是微服务。
- 哪些名字能对应业务含义。

### 练习 2：看一个服务的基础信息

以 SRM 为例：

```bash
cd /home/t/projects/work-wsl
sed -n '1,120p' 03zhaocai-start/scm-cloud-starters-web/scm-cloud-srm/src/main/resources/bootstrap.yml
```

你要找：

- `server.port`
- `spring.application.name`
- `spring.profiles.active`

### 练习 3：看一个服务依赖了哪些业务 jar

```bash
cd /home/t/projects/work-wsl
rg -n "<artifactId>.*(web-jar|feign-api|scm-cloud-dependencies)" 03zhaocai-start/scm-cloud-starters-web/scm-cloud-srm/pom.xml
```

你要观察：

- 它依赖哪个 `*-web-jar`。
- 它依赖哪些 `*-feign-api`。
- 它用了哪些公共依赖。

### 练习 4：从启动模块跳到业务源码

如果 `scm-cloud-srm` 依赖 `scm-srm-web-jar`，就去看：

```bash
cd /home/t/projects/work-wsl
find 01zhaocai-end/scm-srm-all -maxdepth 2 -type d | sort | sed -n '1,80p'
```

你要理解：

- `scm-srm-web-jar` 是业务 Web 层入口。
- `scm-srm-api` 是公共模型。
- `scm-srm-feign-api` 是跨服务接口。
- 其他 `scm-srm-*` 是具体业务子模块。

### 练习 5：找到 Web 装配类

```bash
cd /home/t/projects/work-wsl
find 01zhaocai-end/scm-srm-all/scm-srm-web-jar/src/main/java -name '*WebConfig.java' -print
```

然后看文件：

```bash
sed -n '1,120p' 01zhaocai-end/scm-srm-all/scm-srm-web-jar/src/main/java/com/pcitc/scm/srm/webconfig/SrmWebConfig.java
```

你要观察：

- `@ComponentScan` 扫描了哪些包。
- `@MapperScan` 扫描了哪些 mapper/repositories。

这就是为什么启动类在 `03`，但业务代码在 `01` 也能生效。

## 第一阶段你应该记住的结论

- `03` 是启动入口，`01` 是业务和公共源码。
- 查服务先看 `03/scm-cloud-xxx`。
- 查业务实现再看 `01/scm-xxx-all`。
- `pom.xml` 决定服务依赖了哪些业务 jar。
- `bootstrap.yml` 决定服务名、端口、profile。
- `bootstrap-dev.yml` 决定本地/开发环境连哪个 Nacos。
- `*-web-jar` 很关键，它通常是业务代码被启动工程装配进去的入口。

## 第一阶段完成标准

你可以尝试自己回答这些问题：

1. `scm-cloud-srm` 的服务名和端口是什么？
2. `scm-cloud-source` 的业务源码大概在哪？
3. 如果看到依赖 `scm-contract-web-jar`，应该去哪找合同相关 Controller？
4. 为什么只看 `03` 找不到完整业务逻辑？
5. `*-api` 和 `*-feign-api` 的区别是什么？

能回答这些，就可以进入阶段 2：请求链路。



账号：账号：c31387@365tc.top 密码：密码：fCdq2BF31n
以上为激活账号  （账号密码用来复制）激活前必须看下图！激活前必须看下图！

最重要的一点，在全部完成后，您切换到自己的账号，会发现自己的账号也可以使用
如果你下载好了office365的，用我发你的账号和密码不需要激活直接使用登录使用，


如果电脑没有安装365需要下载安装365office，下载365链接： http://s.o3v.cn/9mLmzP
链接复制到浏览器最上面直接打开别去搜
注：第一次登录需要修改密码，请修改保存好，一人一号【需要苹果系统安装包联系客服】

365全系列教程【有自带的用账号直接激活】：https://kurl08.cn/t8R2eE
