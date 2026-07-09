# 请求进入 SRM 服务到 Controller

这一节接着前面的网关流程讲。

前面我们已经知道：前端请求先到 `scm-gateway-web`，网关处理 Token、Cookie、路径、请求头，然后通过 Nacos 找到目标服务。现在假设网关已经判断这个请求应该交给 SRM。

接下来要理解的问题是：

```text
请求到了 SRM 服务后，SRM 是怎么接住它，并找到 CompanyController 的？
```

## 1. 先纠正一个说法

不是“启动 01 的 SRM 服务”。

准确说：

```text
03/scm-cloud-srm 负责启动 SRM 服务进程。
01/scm-srm-all 提供 SRM 业务源码。
```

运行时是一个合体后的服务进程：

```text
scm-srm-web 服务进程
  = 03/scm-cloud-srm 启动壳
  + 01/scm-srm-all 业务代码
  + 公共组件
  + Nacos / Redis / MySQL 等配置
```

所以请求不是“交给 01 文件夹”，而是进入已经启动好的 `scm-srm-web` 服务进程。这个进程里面已经装好了 `01/scm-srm-all` 的 Controller、Service、Mapper。

## 2. 这一段的完整流程

从网关转发后开始：

```text
网关转发请求
  -> scm-srm-web 服务进程
  -> SRM 的 context-path 匹配
  -> Spring MVC 匹配 Controller 路径
  -> CompanyController 方法
  -> CompanyReadService
  -> CompanyReadServiceImpl
  -> CompanyMapper / 其他 Mapper
  -> MySQL
```

Spring MVC 是 Spring Web 里负责匹配 HTTP 请求和 Controller 方法的机制。你可以把它理解成“前台接待员”：它看到请求路径和请求方法，然后把请求送到对应的 Controller 方法。

## 3. 第一步：SRM 服务先靠 `bootstrap.yml` 定义自己

看这个文件：

```text
03zhaocai-start/scm-cloud-starters-web/scm-cloud-srm/src/main/resources/bootstrap.yml
```

关键配置：

```text
server.port = 8130
server.servlet.context-path = /scm-srm-web
spring.application.name = scm-srm-web
spring.profiles.active = dev
```

这几个配置分别说明：

| 配置 | 含义 |
| --- | --- |
| `server.port=8130` | SRM 默认监听 8130 端口 |
| `context-path=/scm-srm-web` | SRM 服务自己的接口根路径 |
| `spring.application.name=scm-srm-web` | 注册到 Nacos 的服务名 |
| `profiles.active=dev` | 默认使用开发环境配置 |

这里最重要的是：

```text
context-path = /scm-srm-web
```

它的意思是：请求到达 SRM 服务后，路径必须先匹配 `/scm-srm-web` 这个服务根路径。

例如：

```text
/scm-srm-web/s/business/srm/company/queryCompanyList
```

SRM 会先识别：

```text
/scm-srm-web
```

然后把剩下的部分交给 Controller 匹配：

```text
s/business/srm/company/queryCompanyList
```

为什么要这样设计？

因为一个系统有很多服务，路径前缀可以让服务边界更清楚：

```text
/scm-srm-web      供应商服务
/scm-auth-web     认证服务
/scm-source-web   寻源服务
/scm-order-web    订单服务
```

这样前端、网关、后端都能从路径上看出请求大概属于哪个服务。

## 4. 第二步：`SrmApp.java` 启动服务，并把业务能力导入进来

看这个文件：

```text
03zhaocai-start/scm-cloud-starters-web/scm-cloud-srm/src/main/java/com/pcitc/scm/srm/starter/SrmApp.java
```

你重点看四个地方：

```text
@SpringBootApplication
@EnableDiscoveryClient
@ComponentScan(...)
@Import(...)
```

它们的作用：

| 注解 | 做什么 | 目的 |
| --- | --- | --- |
| `@SpringBootApplication` | 声明 Spring Boot 启动入口 | 让这个 Java 程序能作为 Web 服务启动 |
| `@EnableDiscoveryClient` | 启用服务发现 | 启动后注册到 Nacos |
| `@ComponentScan` | 扫描少量公共包 | 装入认证、ORM 等基础配置 |
| `@Import` | 手动导入很多配置类 | 把 SRM、缓存、MQ、工作流、Feign 等能力装进来 |

这里最关键的是：

```text
@Import(SrmWebConfig.class)
```

它说明：SRM 自己的业务 Controller、Service、Mapper 不是靠 `SrmApp.java` 同包自动扫进来的，而是靠 `SrmWebConfig` 继续扫描进来的。

为什么这样设计？

因为这个项目的启动模块在 `03`，业务源码在 `01`。它们不是天然在同一个包结构下面。

如果只靠默认扫描，`SrmApp.java` 很可能扫不到 `01/scm-srm-all` 里分散的业务模块。所以项目用了这种方式：

```text
启动类 SrmApp.java
  -> @Import(SrmWebConfig.class)
  -> SrmWebConfig 再告诉 Spring 去哪里找 SRM 业务代码
```

这就是“启动壳”和“业务源码”分离后，需要额外装配的原因。

## 5. 第三步：`SrmWebConfig.java` 告诉 Spring 去哪里找业务代码

看这个文件：

```text
01zhaocai-end/scm-srm-all/scm-srm-web-jar/src/main/java/com/pcitc/scm/srm/webconfig/SrmWebConfig.java
```

重点看两个注解：

```text
@ComponentScan(...)
@MapperScan(...)
```

`@ComponentScan` 是告诉 Spring：

```text
去这些包里找 Controller、Service、配置类、MQ 监听、定时任务。
```

它扫了这些类型的包：

```text
com.pcitc.scm.srm.*.controller
com.pcitc.scm.srm.apply.*.controller
com.pcitc.scm.srm.**.service.impl
com.pcitc.scm.srm.company.mq
com.pcitc.scm.srm.xxljob
com.pcitc.scm.srm.*.config
```

所以这些目录里的类才会被 Spring 管起来：

```text
01/scm-srm-all/scm-srm-company/.../controller
01/scm-srm-all/scm-srm-company/.../service/impl
01/scm-srm-all/scm-srm-apply/.../controller
...
```

`@MapperScan` 是告诉 MyBatis：

```text
去这些包里找 Mapper。
```

它扫：

```text
com.pcitc.scm.srm.*.repositories
com.pcitc.scm.ubm.*.repositories
```

Mapper 是数据库访问层。你可以理解成“会和数据库说话的类”。Controller 不应该直接写 SQL，它一般调用 Service，Service 再调用 Mapper。

为什么这样设计？

因为 SRM 内部又拆了很多子模块：

```text
scm-srm-company
scm-srm-apply
scm-srm-address
scm-srm-invoice
scm-srm-common
...
```

这些模块都属于 SRM，但分散在不同目录里。`SrmWebConfig` 的作用就是统一告诉 Spring：

```text
这些分散的 SRM 子模块都算我的业务代码，请一起加载。
```

## 6. 第四步：请求进入 `CompanyController`

看这个文件：

```text
01zhaocai-end/scm-srm-all/scm-srm-company/src/main/java/com/pcitc/scm/srm/company/controller/CompanyController.java
```

这个 Controller 的类上有：

```text
@RestController
```

意思是：这是一个 REST 接口类。REST 接口可以简单理解为“前端通过 HTTP 调用的后端接口”。

里面有一个接口：

```text
@PostMapping("s/business/srm/company/queryCompanyList")
queryCompanyList(...)
```

如果前端请求是：

```text
POST /scm-srm-web/s/business/srm/company/queryCompanyList
```

匹配过程是：

```text
SRM 服务先吃掉 context-path：
  /scm-srm-web

Spring MVC 再匹配 Controller 路径：
  s/business/srm/company/queryCompanyList

请求方法也要匹配：
  POST

匹配成功：
  进入 CompanyController.queryCompanyList(...)
```

如果方法是 GET，但 Controller 写的是 `@PostMapping`，就匹配不上，会出现请求方法不支持的问题。

如果路径写错，比如少了 `company`，也匹配不上，一般就是 404。

为什么 Controller 只负责接请求？

因为 Controller 的职责是“入口层”：

```text
接收请求
拿到参数
调用业务服务
包装返回结果
```

它不应该承担复杂业务，也不应该直接访问数据库。这样设计是为了让代码分层清楚：

```text
Controller 管入口
Service 管业务
Mapper 管数据库
```

以后你排查问题也好定位：

```text
接口进不来：看 Controller 路径和请求方法
业务结果不对：看 Service
SQL 或数据不对：看 Mapper / 数据库
```

## 7. 第五步：Controller 调用 Service

在 `CompanyController` 里，`queryCompanyList` 大概做了这件事：

```text
接收 pageBean 参数
调用 companyService.queryCompanyList(pageBean)
把结果用 Result.success(...) 包起来返回
```

这里的 `companyService` 是：

```text
CompanyReadService companyService
```

接口文件在：

```text
01zhaocai-end/scm-srm-all/scm-srm-company/src/main/java/com/pcitc/scm/srm/company/service/read/CompanyReadService.java
```

实现类在：

```text
01zhaocai-end/scm-srm-all/scm-srm-company/src/main/java/com/pcitc/scm/srm/company/service/impl/read/CompanyReadServiceImpl.java
```

为什么要有接口和实现类？

这是 Java 后端常见设计：

```text
Controller 依赖接口 CompanyReadService
真正业务写在 CompanyReadServiceImpl
```

好处是：

```text
Controller 不关心具体实现。
以后实现逻辑变了，Controller 不用改。
测试、扩展、替换实现更方便。
```

你可以把接口理解成“合同”，实现类理解成“真正干活的人”。Controller 只按合同办事，不直接绑定某个具体人。

## 8. 第六步：Service 调用 Mapper 查数据库

在 `CompanyReadServiceImpl.queryCompanyList(...)` 里，大概逻辑是：

```text
1. 记录请求日志
2. 从 pageBean 里取查询条件
3. 创建分页对象
4. 根据 companyCode、companyName 拼查询条件
5. 调 companyMapper.selectPage(...) 查供应商公司表
6. 遍历查询结果
7. 再查供应商产品目录
8. 组装 CompanyListVO
9. 返回分页结果 PageList
```

这里出现了：

```text
companyMapper
companyProductCateMapper
```

它们在：

```text
01zhaocai-end/scm-srm-all/scm-srm-company/src/main/java/com/pcitc/scm/srm/company/repositories
```

其中 `CompanyMapper.java` 继承：

```text
BaseMapper<Company>
```

这是 MyBatis-Plus 提供的基础 Mapper。MyBatis-Plus 是数据库访问工具，它帮你提供一些常用方法，比如：

```text
selectById
selectList
selectPage
insert
updateById
```

所以 `companyMapper.selectPage(...)` 不一定需要你手写 SQL，它可以根据实体类和条件构造器生成查询。

为什么数据库访问要放在 Mapper？

因为这样能把业务逻辑和数据库逻辑分开：

```text
Service 负责“业务怎么做”
Mapper 负责“数据怎么查”
```

如果 Service 里直接写一堆 SQL，业务代码会变得很难读，也不好维护。

## 9. 这一段的文件地图

| 顺序 | 文件 | 做什么 | 你现在看什么 |
| --- | --- | --- | --- |
| 1 | `03/.../scm-cloud-srm/src/main/resources/bootstrap.yml` | 定义 SRM 服务身份 | 服务名、端口、`context-path` |
| 2 | `03/.../scm-cloud-srm/.../SrmApp.java` | 启动 SRM，导入配置 | `@Import(SrmWebConfig.class)` |
| 3 | `01/.../scm-srm-web-jar/.../SrmWebConfig.java` | 扫描业务代码 | `@ComponentScan`、`@MapperScan` |
| 4 | `01/.../scm-srm-company/.../CompanyController.java` | HTTP 接口入口 | `@PostMapping`、调用哪个 Service |
| 5 | `01/.../scm-srm-company/.../CompanyReadService.java` | 业务接口定义 | 有哪些业务方法 |
| 6 | `01/.../scm-srm-company/.../CompanyReadServiceImpl.java` | 业务实现 | 方法内部大概流程 |
| 7 | `01/.../scm-srm-company/.../repositories/CompanyMapper.java` | 数据访问 | 查哪张表、是否有自定义 SQL |

## 10. 这一段可能遇到的分支

### 分支 1：请求路径前缀不对

```text
请求不是 /scm-srm-web 开头
  -> SRM 的 context-path 可能匹配不到
```

### 分支 2：Controller 路径不对

```text
/scm-srm-web 匹配了
但后面的 /s/business/srm/company/queryCompanyList 写错
  -> 找不到对应 Controller 方法
  -> 常见结果是 404
```

### 分支 3：HTTP 方法不对

```text
Controller 是 @PostMapping
请求却用 GET
  -> 方法不匹配
  -> 常见结果是 405
```

### 分支 4：参数格式不对

```text
Controller 用 @RequestBody
前端没传 JSON body，或者字段结构不对
  -> 参数解析失败
  -> 可能在进入业务逻辑前报错
```

### 分支 5：进入 Service 后业务报错

```text
Controller 已经进来了
Service 处理数据时报错
  -> 要看 Service 方法内部逻辑
```

### 分支 6：数据库查询异常

```text
Service 调 Mapper
Mapper 查数据库失败
  -> 要看 Mapper、实体类、表结构、数据库连接配置
```

## 11. 现在你应该真正掌握的主线

你现在不用记所有方法，也不用记每个表。

你只要能把这条链讲出来：

```text
网关转发到 scm-srm-web
  -> SRM bootstrap.yml 定义 /scm-srm-web
  -> SrmApp.java 启动服务
  -> SrmApp.java import SrmWebConfig
  -> SrmWebConfig 扫描 Controller / Service / Mapper
  -> CompanyController 匹配请求路径
  -> Controller 调 CompanyReadService
  -> CompanyReadServiceImpl 写业务逻辑
  -> CompanyMapper 查数据库
```

这就说明你已经从“知道服务名字”进步到“知道请求在服务内部怎么流动”。

下一步再继续学，就应该进入：

```text
Controller -> Service -> Mapper -> 数据库表
```

也就是拿 `queryCompanyList` 这个具体接口，真正跟一遍业务代码。
