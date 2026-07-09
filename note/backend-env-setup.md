# 招采后端本地开发环境配置

本文档按当前项目情况整理：后端主要使用 Java 8，启动入口在 `03zhaocai-start/scm-cloud-starters-web`，业务源码主要在 `01zhaocai-end`。

## 1. IDEA 项目 SDK

你现在这部分已经基本配置正确。

在 IDEA 中文界面中检查：

`文件` -> `项目结构` -> `项目`

建议配置：

- `SDK`：`corretto-1.8 Amazon Corretto 1.8.0_492`
- `语言级别`：`8 - lambda、类型注解等`
- `编译器输出`：可以保持当前 `work-wsl/out`

然后检查模块：

`文件` -> `项目结构` -> `模块`

建议：

- 选中每个后端模块
- `模块 SDK` 使用 `项目 SDK`
- 不要让某些模块单独使用 Java 11 或 Java 17

## 2. WSL 安装 JDK 8

IDEA 里配置了 JDK，不代表 WSL 终端里也能用。后续打包、排查依赖、跑脚本时，WSL 里也需要 `java` 和 `javac`。

在 WSL 终端执行：

```bash
sudo apt update
sudo apt install -y openjdk-8-jdk
```

如果 Ubuntu 24.04 默认源找不到 `openjdk-8-jdk`，可以先用 SDKMAN 安装 Java 8：

```bash
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk list java
```

在列表里选一个 Java 8，例如 Temurin、Zulu 或 Corretto 的 8 版本，然后安装。示例：

```bash
sdk install java 8.0.492-tem
sdk default java 8.0.492-tem
```

安装后验证：

```bash
java -version
javac -version
```

期望看到 `1.8.0` 或 `8`。

## 3. WSL 安装 Maven

项目比较老，并且公司 Nexus 使用的是 `http://` 地址。Maven `3.8.1+` 默认会拦截 HTTP 仓库，容易报 `maven-default-http-blocker`。

因此本项目优先建议使用 Maven `3.6.3`。如果你已经通过 `apt` 安装了 Maven `3.8.7`，也建议改成手动安装 Maven `3.6.3`。

```bash
cd /tmp
wget https://archive.apache.org/dist/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz
sudo mkdir -p /opt/maven
sudo tar -xzf apache-maven-3.6.3-bin.tar.gz -C /opt/maven
```

编辑 `~/.zshrc`：

```bash
nano ~/.zshrc
```

追加到文件末尾：

```bash
export MAVEN_HOME=/opt/maven/apache-maven-3.6.3
export PATH=$MAVEN_HOME/bin:$PATH
```

使配置生效：

```bash
source ~/.zshrc
mvn -version
```

确认输出类似：

```bash
Apache Maven 3.6.3
Java version: 1.8.0_xxx
```

如果仍然显示 `Apache Maven 3.8.7`，说明 `/usr/bin/mvn` 优先级还在前面，检查：

```bash
which mvn
echo $PATH
```

正常应该优先指向：

```text
/opt/maven/apache-maven-3.6.3/bin/mvn
```

## 4. Maven 私服 settings.xml

项目依赖公司 Nexus 私服。需要配置 Maven 的 `settings.xml`。

WSL Maven 的配置路径：

```bash
mkdir -p ~/.m2
nano ~/.m2/settings.xml
```

把公司提供的 Maven settings 放进去。注意不要把账号密码提交到 Git。

还需要确认 Nexus 域名能解析。如果公司要求配置 hosts：

```bash
sudo nano /etc/hosts
```

添加公司提供的 Nexus 映射，例如：

```text
公司Nexus_IP nexus.jdsn.com.cn
```

验证连通性：

```bash
ping nexus.jdsn.com.cn
```

如果 `ping` 不通，不一定代表 Maven 不能用，但说明网络或 hosts 需要再确认。公司内网/VPN 也要打开。

## 5. IDEA Maven 配置

中文路径：

`文件` -> `设置` -> `构建、执行、部署` -> `构建工具` -> `Maven`

建议配置：

- `Maven 主路径`：选择 Maven 3.6.x / 3.8.x
- `用户设置文件`：选择你配置好的 `settings.xml`
- `本地仓库`：默认即可，或者指定到你的 Maven 本地仓库

如果你的 IDEA 是 Windows 版但项目在 WSL，有两种选择：

- 简单方案：IDEA 用 Windows 上的 JDK/Maven/settings，WSL 终端也单独配一份 JDK/Maven/settings。
- 统一方案：IDEA 使用 WSL 解释器/WSL Maven。新手先用简单方案更稳。

继续检查：

`文件` -> `设置` -> `构建、执行、部署` -> `构建工具` -> `Maven` -> `导入`

建议：

- `导入器的 JDK`：选择 `corretto-1.8`
- 勾选自动导入相关选项，或者后续手动点击 Maven 面板刷新

继续检查：

`文件` -> `设置` -> `构建、执行、部署` -> `构建工具` -> `Maven` -> `运行程序`

建议：

- `JRE`：选择 `corretto-1.8`

## 6. IDEA Lombok 和注解处理

项目里有 Lombok，IDEA 需要启用注解处理。

检查插件：

`文件` -> `设置` -> `插件`

搜索 `Lombok`，确认已安装并启用。

启用注解处理：

`文件` -> `设置` -> `构建、执行、部署` -> `编译器` -> `注解处理器`

建议：

- 勾选 `启用注解处理`

## 7. IDEA 编码和换行

编码建议统一 UTF-8。

中文路径：

`文件` -> `设置` -> `编辑器` -> `文件编码`

建议：

- `全局编码`：`UTF-8`
- `项目编码`：`UTF-8`
- `属性文件的默认编码`：`UTF-8`

## 8. Git 基础配置

在 WSL 终端执行：

```bash
git config --global core.autocrlf input
git config --global core.filemode false
```

确认用户名邮箱：

```bash
git config --global user.name
git config --global user.email
```

如果需要修改：

```bash
git config --global user.name "你的名字"
git config --global user.email "你的公司邮箱"
```

## 9. IDEA 导入项目方式

不要把 `/home/t/projects/work-wsl` 当成一个完整 Maven 项目，因为顶层没有总 `pom.xml`，下面是多个 Git 仓库平铺。

建议先导入启动项目：

`文件` -> `打开`

选择：

```text
/home/t/projects/work-wsl/03zhaocai-start/scm-cloud-starters-web/pom.xml
```

打开后选择作为 Maven 项目导入。

然后根据你要看的业务，再导入对应模块，例如：

```text
/home/t/projects/work-wsl/01zhaocai-end/scm-auth-all/pom.xml
/home/t/projects/work-wsl/01zhaocai-end/scm-srm-all/pom.xml
/home/t/projects/work-wsl/01zhaocai-end/scm-source-all/pom.xml
/home/t/projects/work-wsl/01zhaocai-end/scm-contract-all/pom.xml
```

如果 IDEA 已经打开了 `work-wsl` 根目录，也可以在右侧 Maven 面板里点击 `+`，手动添加这些 `pom.xml`。

## 10. 首次 Maven 验证

先验证启动项目能读取 Maven 配置：

```bash
cd /home/t/projects/work-wsl/03zhaocai-start/scm-cloud-starters-web
mvn -version
mvn -U dependency:tree -DskipTests
```

如果依赖能正常下载，说明 JDK、Maven、settings、私服网络基本打通。

再验证一个业务模块，例如：

```bash
cd /home/t/projects/work-wsl/01zhaocai-end/scm-auth-all
mvn -U clean install -DskipTests
```

如果失败，优先看错误类型：

- `maven-default-http-blocker`：你正在用 Maven `3.8.1+`，它拦截了公司 HTTP Nexus。切换到 Maven `3.6.3`。
- `Could not resolve artifact`：Maven 私服、settings、网络、hosts 问题。
- `Source option 5 is no longer supported` 或 Java 版本相关错误：JDK 没切到 Java 8。
- `Lombok`、`get/set` 找不到：IDEA 注解处理没开，或者 Maven 依赖没拉下来。
- `401 Unauthorized`：私服账号密码不对。

## 11. 暂时不用急着配置的东西

这些等你真正要启动某个服务时再处理：

- Nacos
- MySQL
- Redis
- Elasticsearch
- Docker
- 前端 Node 环境

当前第一阶段目标是：IDEA 能识别项目，Maven 能拉依赖，Java 版本是 8。
