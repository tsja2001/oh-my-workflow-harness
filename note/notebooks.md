# 项目复习笔记

## 1. `03/scm-cloud-starters-web` 是什么

| 位置 | 是什么 | 做什么 | 目的 |
| --- | --- | --- | --- |
| `03zhaocai-start/scm-cloud-starters-web` | 后端 Web 服务启动集合 | 放各个 `scm-cloud-xxx` 启动模块 | 把网关、认证、业务服务等跑起来 |
| `03/.../scm-cloud-gateway` | 后台网关启动壳 | 启动后台网关服务 | 后台请求入口 |
| `03/.../scm-cloud-gateway-mall` | 商城网关启动壳 | 启动商城网关服务 | 商城/门户请求入口 |
| `03/.../scm-cloud-srm` | SRM 启动壳 | 启动 `scm-srm-web` 服务 | 承接供应商业务请求 |

关键记法：

```text
03 负责启动服务。
01 提供业务源码。
运行时是服务进程处理请求，不是文件夹处理请求。
```

## 2. 两个 Gateway

| 模块 | 面向谁 | 作用 |
| --- | --- | --- |
| `scm-cloud-gateway` | 后台管理端 | 后台请求统一入口 |
| `scm-cloud-gateway-mall` | 商城/门户端 | 商城请求统一入口 |

网关主要做：

```text
接请求 -> 处理 Token/Cookie/路径/请求头 -> 根据路由找服务 -> 转发请求
```

## 3. 服务分类

| 类型 | 模块 |
| --- | --- |
| 网关 | `scm-cloud-gateway`、`scm-cloud-gateway-mall` |
| 业务服务 | `scm-cloud-srm`、`scm-cloud-source`、`scm-cloud-order`、`scm-cloud-product`、`scm-cloud-contract`、`scm-cloud-fee`、`scm-cloud-professor` |
| 基础服务 | `scm-cloud-auth`、`scm-cloud-file`、`scm-cloud-ubm`、`scm-cloud-ubm-mall`、`scm-cloud-statics`、`scm-cloud-scheduling`、`scm-cloud-workflow`、`scm-cloud-report`、`scm-cloud-ifs`、`scm-cloud-devops` |

## 4. 从 Gateway 到 SRM 的关系

| 位置 | 做什么 | 目的 |
| --- | --- | --- |
| `03/.../scm-cloud-gateway` | 启动网关服务 | 接住前端请求 |
| `01zhaocai-end/scm-gateway-all` | 提供网关过滤器、配置、路径解析源码 | 在网关里处理请求 |
| `03/.../scm-cloud-srm` | 启动 SRM 服务 | 接收网关转发 |
| `01zhaocai-end/scm-srm-all` | 提供 SRM Controller、Service、Mapper 源码 | 处理供应商业务 |

运行时可以理解成：

```text
scm-gateway-web 服务进程
  = 03/scm-cloud-gateway 启动壳
  + 01/scm-gateway-all 网关代码

scm-srm-web 服务进程
  = 03/scm-cloud-srm 启动壳
  + 01/scm-srm-all 业务代码
```

## 5. 进入 Controller 前的关键文件

按请求顺序看：

| 位置 | 具体文件 | 做什么 | 目的 |
| --- | --- | --- | --- |
| `03/scm-cloud-starters-web/scm-cloud-gateway` | `src/main/resources/bootstrap.yml` | 定义网关服务名、端口、环境 | 让网关启动 |
| `03/scm-cloud-starters-web/scm-cloud-gateway` | `src/main/resources/bootstrap-dev.yml` | 定义 Nacos 地址、namespace、公共配置 | 让网关注册和拉配置 |
| `01/scm-gateway-all` | `scm-gateway/.../GatewayRewriterFilter.java` | 解析 Token/Cookie、检查会话、处理路径、补请求头 | 请求进入业务服务前统一处理 |
| `01/scm-gateway-all` | `scm-gateway/.../GatewayConfig.java` | 接收 `scm.gateway.config` 配置 | 给过滤器提供规则 |
| `01/scm-gateway-all` | `scm-gateway/.../RequestPathResolver.java` | 拆 URL，例如拆出 `appModule=srm` | 帮网关判断请求属于哪个模块 |
| `03/scm-cloud-starters-web/scm-cloud-srm` | `src/main/resources/bootstrap.yml` | 定义 SRM 服务名、端口、`/scm-srm-web` 根路径 | 让 SRM 接收自己的接口 |
| `03/scm-cloud-starters-web/scm-cloud-srm` | `src/main/java/.../SrmApp.java` | 启动 SRM，并 `@Import` 业务配置 | 把业务代码装进服务进程 |
| `01/scm-srm-all` | `scm-srm-web-jar/.../SrmWebConfig.java` | 扫描 SRM 的 Controller、Service、Mapper | 让 Spring 找到业务代码 |
| `01/scm-srm-all` | `scm-srm-company/.../CompanyController.java` | 提供供应商公司相关接口 | 最终进入 Controller 方法 |

## 6. 简化请求链路

```text
前端请求
  -> 03 网关启动壳启动的网关服务
  -> 01 网关代码处理 Token、路径、请求头
  -> 网关通过 Nacos 找到 scm-srm-web
  -> 转发到 03 SRM 启动壳启动的 SRM 服务
  -> 01 SRM 业务代码里的 Controller
  -> Service
  -> Mapper
  -> MySQL / Redis / MQ / ES
```

## 7. `/scm-srm-web` 怎么理解

| 位置 | 含义 |
| --- | --- |
| 网关路由配置 | 可能用 `/scm-srm-web` 判断请求转给 SRM |
| SRM `bootstrap.yml` | `context-path=/scm-srm-web`，表示 SRM 自己的接口根路径 |

一句话：

```text
网关决定请求转给哪个服务。
SRM 的 bootstrap.yml 决定 SRM 收到请求后，哪个路径前缀属于自己。
```

## 8. 不要混淆

| 错误理解 | 正确理解 |
| --- | --- |
| 请求进入 `bootstrap.yml` | 请求进入运行中的服务进程 |
| 请求交给 `01` 目录处理 | `01` 的源码已被装进服务进程 |
| SRM 的 `bootstrap.yml` 是网关配置 | 它是 SRM 自己的启动配置 |
| `03` 里没有业务代码，所以服务没逻辑 | `03` 通过依赖和 `@Import` 装配 `01` 的业务代码 |
