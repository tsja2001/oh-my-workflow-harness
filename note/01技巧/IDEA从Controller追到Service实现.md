# IDEA 从 Controller 追到 Service 实现

## 1. 先看一个真实场景

你在 Controller 里看到这个接口：

```java
@ApiOperation("根据采购方案ID查询寻源相关工作流信息")
@PostMapping("obs/business/devops/source/getWfInfoBySchemeId")
public Result<SourceWfInfo> getWfInfoBySchemeId(@RequestBody SourceWfInfoQuery param){
    SourceWfInfo sourceWfInfo = sourceService.getWfInfoBySchemeId(param);
    return Result.success(sourceWfInfo);
}
```

你按住 `Ctrl` 点击：

```java
sourceService.getWfInfoBySchemeId(param)
```

结果 IDEA 跳到了：

```java
public interface SourceService {
    SourceWfInfo getWfInfoBySchemeId(SourceWfInfoQuery sourceWfInfoQuery);
}
```

这个时候容易困惑：

```text
这里是 interface，只定义了方法，没有具体逻辑。
那真正的代码在哪里？
```

这个现象非常正常。你已经走到了 Java 后端最关键的一步：从 Controller 入口往下追业务实现。

## 2. 先说结论

`SourceService` 是接口，真正干活的是它的实现类。

通常实现类会叫：

```text
SourceServiceImpl
```

在这个项目里大概是：

```text
scm-devops-source/src/main/java/com/pcitc/scm/devops/source/service/impl/SourceServiceImpl.java
```

里面一般会有：

```java
@Service
public class SourceServiceImpl implements SourceService {
    @Override
    public SourceWfInfo getWfInfoBySchemeId(SourceWfInfoQuery sourceWfInfoQuery) {
        // 这里才是真正的业务逻辑
    }
}
```

所以：

```text
interface 只是说明这个 Service 有什么能力。
Impl 才是这个能力具体怎么实现。
```

## 3. IDEA 里具体怎么操作

以后你看到：

```java
sourceService.getWfInfoBySchemeId(param);
```

可以这样操作：

```text
Ctrl + 点击
```

通常是跳到“定义”，所以可能会跳到接口。

如果你想直接看实现类，用：

```text
Ctrl + Alt + B
```

它的含义是：

```text
Go To Implementation
跳转到实现
```

也可以右键方法名：

```text
Go To -> Implementation(s)
```

Mac 上通常是：

```text
Option + Command + B
```

## 4. 为什么会有 interface

可以把接口理解成“合同”或者“菜单”。

Controller 里写：

```java
sourceService.getWfInfoBySchemeId(param);
```

它的意思是：

```text
我需要一个 SourceService。
这个 SourceService 必须会 getWfInfoBySchemeId 这件事。
```

接口就是菜单：

```java
public interface SourceService {
    SourceWfInfo getWfInfoBySchemeId(SourceWfInfoQuery sourceWfInfoQuery);
}
```

它只告诉你：

```text
这里有一道菜，叫“根据采购方案查询工作流信息”。
```

真正做菜的是：

```java
public class SourceServiceImpl implements SourceService
```

也就是说：

```text
接口：规定能做什么
实现类：具体怎么做
```

## 5. 为什么 Controller 不直接写 SourceServiceImpl

你可能会想，为什么不直接写：

```java
@Autowired
private SourceServiceImpl sourceService;
```

而是写：

```java
@Autowired
private SourceService sourceService;
```

这是 Java 后端常见习惯，叫“面向接口编程”。

不用把这个词想得太复杂，先记住三个实际好处。

第一，Controller 不需要关心细节。

Controller 的职责是：

```text
接参数 -> 调业务 -> 包装返回结果
```

它不应该写一堆复杂业务逻辑，也不需要关心 Service 内部怎么查数据。

第二，以后可以换实现。

今天实现类是：

```text
SourceServiceImpl
```

以后如果要换一套逻辑，可以新增：

```text
SourceServiceNewImpl
```

只要它也实现 `SourceService`，Controller 理论上不用跟着大改。

第三，方便框架管理。

Spring、测试工具、代理增强等都很喜欢基于接口做事。你现在不需要深挖，先知道这是行业常见写法即可。

## 6. Spring 是怎么知道用哪个实现类的

关键看两个地方。

Controller 里：

```java
@Autowired
private SourceService sourceService;
```

实现类上：

```java
@Service
public class SourceServiceImpl implements SourceService
```

可以这样理解：

`@Service` 告诉 Spring：

```text
这个类是一个服务类，请帮我创建对象并管理起来。
```

`@Autowired` 告诉 Spring：

```text
我这里需要一个 SourceService，请从你管理的对象里找一个能用的塞进来。
```

Spring 一看：

```java
SourceServiceImpl implements SourceService
```

就知道：

```text
SourceServiceImpl 可以当 SourceService 用。
```

于是运行时，Controller 里的 `sourceService` 表面类型是：

```text
SourceService
```

但真实对象是：

```text
SourceServiceImpl
```

## 7. 一个好理解的类比

接口像“车”这个概念：

```text
车可以启动
车可以刹车
车可以转向
```

具体实现类像某个具体品牌：

```text
比亚迪
丰田
大众
```

你平时说“给我一辆车”，不一定关心品牌。

但是修车时，你就要知道具体是哪辆车。

追代码也是这样：

```text
Controller 只知道我要一个 SourceService。
我们排查问题时，要找到真正的 SourceServiceImpl。
```

## 8. IDEA 追代码常用快捷键

以后你看 Java 后端，常用这几个就够了。

```text
Ctrl + 点击
跳到定义，常常会跳到接口、类、方法声明。
```

```text
Ctrl + Alt + B
跳到实现类。看到 interface 时尤其有用。
```

```text
Alt + F7
查这个方法或类在哪里被调用。
```

```text
Ctrl + H
看继承关系，比如接口有哪些实现类。
```

```text
Ctrl + Alt + 左箭头
回到刚才看的地方。
```

如果跳出来多个实现类，优先看：

```text
类名带 Impl 的
类上有 @Service 的
包路径和当前业务一致的
没有 test、mock、demo 字样的
```

## 9. 当前这个接口的代码链路

你现在看的接口链路大概是：

```text
SourceController
    ↓ 调用
SourceService 接口
    ↓ 实际实现
SourceServiceImpl
    ↓ 里面调用其他服务
SchemeFeignService
SourceFeignService
WorkflowFeignClientService
```

也就是说：

```text
Controller 只是入口。
接口只是能力说明。
SourceServiceImpl 才是真正业务逻辑。
```

## 10. 后端接口的一般结构

一个普通后端接口通常长这样：

```text
Controller：接请求
Service：写业务逻辑
Mapper / Feign：拿数据
DTO / VO：装数据
Result：统一返回格式
```

套到这个接口上：

```text
SourceController
接收 SourceWfInfoQuery 参数
        ↓
SourceService
定义“根据方案查工作流信息”这个能力
        ↓
SourceServiceImpl
真正查方案、查报名、查澄清、查工作流
        ↓
Feign 调其他服务
比如 source 服务、workflow 服务
        ↓
SourceWfInfo
把查到的数据装好
        ↓
Result.success
统一返回给前端
```

## 11. 学习 Java 后端的追代码心法

不要一上来试图看懂所有文件。

先追一条线，问自己五个问题：

```text
1. 请求入口在哪里？
2. 它调了哪个 Service？
3. Service 的实现类在哪里？
4. 实现类里面查了哪些表，或者调了哪些服务？
5. 最后返回了什么对象？
```

这五个问题能答出来，一个接口你就基本看懂一半了。

以后看到 `interface`，你脑子里直接翻译成：

```text
这只是能力说明书，我要找 implements 它的类。
```

然后在 IDEA 里按：

```text
Ctrl + Alt + B
```

去实现类。

