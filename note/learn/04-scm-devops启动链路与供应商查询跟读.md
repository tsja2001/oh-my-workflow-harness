# 04 - scm-devops 启动链路与供应商查询跟读

> 本文基于 `origin/test` 分支。  
> 目标不是一次看懂所有 Java 代码，而是带你在 IDEA 里顺着两条线读源码：
>
> 1. 启动链路：`scm-cloud-devops` -> `DevopsApp` -> `DevopsWebConfig`
> 2. 简单查询：`SupplierController` -> `SrmCompanyServiceImpl` -> `SrmCompanyMapper`

## 0. 先建立一个读代码姿势

你现在看后端源码，最容易被各种类名、注解、泛型吓住。

先不要把目标定成“我必须每一行都懂”。我们先定一个更实际的目标：

```text
我知道请求从哪里进来。
我知道它交给谁处理。
我知道它最终查哪张表。
我知道 IDEA 里怎么跳过去。
```

只要这四点能跑通，你就已经能开始读一个接口了。

可以把后端接口想成一次前端请求：

```text
前端调用接口
    ↓
Controller 接住请求
    ↓
Service 处理业务
    ↓
Mapper 查数据库
    ↓
返回 Result
```

你熟悉一点 Node 的话，可以类比成：

```text
router -> service -> dao/model -> response
```

Java 只是名字和写法更“正式”一点。

## 1. IDEA 中文界面常用动作

先记住这几个。后面跟读会反复用。

### 1.1 全局找文件

快捷键：

```text
Ctrl + Shift + N
```

中文菜单大概是：

```text
导航 -> 文件
```

用途：

```text
你知道文件名，比如 DevopsApp.java，就直接搜它。
```

### 1.2 全局找类

快捷键：

```text
Ctrl + N
```

中文菜单大概是：

```text
导航 -> 类
```

用途：

```text
你知道类名，比如 SupplierController，就直接搜它。
```

### 1.3 全局搜文本

快捷键：

```text
Ctrl + Shift + F
```

中文菜单大概是：

```text
编辑 -> 查找 -> 在文件中查找
```

用途：

```text
你知道接口路径，比如 e/business/devops/company/getRecords，就搜这个字符串。
```

这个在找 Controller 入口时非常好用。

### 1.4 跳到定义

快捷键：

```text
Ctrl + 点击
```

用途：

```text
跳到变量、方法、类的定义。
```

注意：如果点的是接口方法，可能会跳到 interface。

### 1.5 跳到实现

快捷键：

```text
Ctrl + Alt + B
```

中文菜单大概是：

```text
导航 -> 实现
```

用途：

```text
从 interface 跳到真正的实现类。
```

你后面看 `SrmCompanyService` 时会用到。

### 1.6 查哪里调用了它

快捷键：

```text
Alt + F7
```

中文菜单大概是：

```text
查找用法
```

用途：

```text
想知道某个方法、类、接口在哪里被用到了。
```

### 1.7 回到上一个位置

快捷键：

```text
Ctrl + Alt + 左箭头
```

用途：

```text
刚刚跳进去了，想退回上一个文件。
```

这个一定要熟。读源码就是不停地跳进去、跳回来。

## 2. 第一条线：启动链路

这一节先不看业务接口。我们先搞清楚：

```text
scm-devops-web 这个服务是怎么被启动起来的？
```

你要看的启动工程在：

```text
03zhaocai-start/scm-cloud-starters-web/scm-cloud-devops
```

业务源码在：

```text
01zhaocai-end/scm-devops-all
```

先记住这句话：

```text
03 负责启动，01 负责业务代码。
```

## 3. 启动链路第一站：pom.xml

在 IDEA 里按：

```text
Ctrl + Shift + N
```

搜索：

```text
scm-cloud-devops/pom.xml
```

打开后先不要从头到尾读。`pom.xml` 你现在只需要看一个重点：

```xml
<dependency>
    <groupId>com.pcitc</groupId>
    <artifactId>scm-devops-web-jar</artifactId>
    <version>${project.version}</version>
</dependency>
```

这段的意思是：

```text
启动工程 scm-cloud-devops 引入了业务装配包 scm-devops-web-jar。
```

你可以先把 `pom.xml` 类比成 Node 项目的 `package.json`：

```text
Node 里 package.json 写依赖。
Java Maven 里 pom.xml 写依赖。
```

只是 Maven 更啰嗦，XML 看起来比较重。

这里最重要的是：

```text
如果没有 scm-devops-web-jar，启动工程就不知道 devops 业务接口在哪里。
```

所以第一站你只需要记住：

```text
scm-cloud-devops 通过 pom.xml 依赖 scm-devops-web-jar。
```

## 4. 启动链路第二站：DevopsApp

在 IDEA 里按：

```text
Ctrl + N
```

搜索：

```text
DevopsApp
```

打开：

```text
03zhaocai-start/scm-cloud-starters-web/scm-cloud-devops/src/main/java/com/pcitc/scm/devops/starter/DevopsApp.java
```

先看这个方法：

```java
public static void main(String[] args) {
    SpringApplication.run(DevopsApp.class, args);
    log.info("启动成功");
}
```

你可以把它理解成：

```text
Java 后端服务的启动入口。
```

类比 Node：

```js
app.listen(9800)
```

不完全一样，但感觉可以这么理解：

```text
main 方法一跑，Spring Boot 服务就开始启动。
```

再看类上面的几个注解。现在不用深挖，只看意思。

```java
@SpringBootApplication
```

意思：

```text
这是一个 Spring Boot 应用。
```

```java
@EnableDiscoveryClient
```

意思：

```text
这个服务会注册到 Nacos，其他服务可以发现它。
```

```java
@ComponentScan(...)
```

意思：

```text
让 Spring 去扫描一些指定包下的类。
```

```java
@Import({... DevopsWebConfig.class ...})
```

这句最关键。

你先重点看：

```java
@Import({..., DevopsWebConfig.class, ...})
```

它的意思是：

```text
启动的时候，把 DevopsWebConfig 这份配置也加载进来。
```

所以第二站你要记住：

```text
DevopsApp 是启动入口。
DevopsApp 通过 @Import 引入 DevopsWebConfig。
```

## 5. 启动链路第三站：DevopsWebConfig

在 `DevopsApp` 里按住 `Ctrl` 点击：

```java
DevopsWebConfig.class
```

或者按：

```text
Ctrl + N
```

搜索：

```text
DevopsWebConfig
```

打开后会看到：

```java
@ComponentScan(basePackages = {"com.pcitc.scm.devops.**.controller",
        "com.pcitc.scm.devops.**.service.impl",
        "com.pcitc.scm.devops.**.config",
        "com.pcitc.scm.devops.**.mq",
        "com.pcitc.scm.devops.**.service",
})
@MapperScan(basePackages = {"com.pcitc.scm.devops.*.repositories"})
public class DevopsWebConfig {
}
```

这段对新人很重要。

你可以这样理解：

```text
@ComponentScan 是告诉 Spring：去这些包下面找 Controller 和 Service。
@MapperScan 是告诉 MyBatis：去这些包下面找 Mapper。
```

也就是说，Spring 启动时会去找：

```text
com.pcitc.scm.devops...controller
com.pcitc.scm.devops...service
com.pcitc.scm.devops...repositories
```

这就是为什么 `SupplierController`、`SrmCompanyServiceImpl`、`SrmCompanyMapper` 能被系统识别。

如果没有这一步，你写了 Controller 也没用，Spring 不知道它存在。

这一站你记住：

```text
DevopsWebConfig 负责把 devops 业务代码装进 Spring 容器。
```

## 6. 启动链路串起来

现在把刚才三站连起来：

```text
scm-cloud-devops/pom.xml
引入 scm-devops-web-jar
        ↓
DevopsApp
服务启动入口
        ↓
@Import(DevopsWebConfig.class)
加载 devops 业务配置
        ↓
DevopsWebConfig
扫描 Controller / Service / Mapper
        ↓
SupplierController 等接口可以被访问
```

你以后看到一个服务启动不起来、接口找不到、Bean 找不到，就可以先按这条线排查。

## 7. 第二条线：供应商公司查询

现在开始看一个最简单的接口。

目标接口是：

```text
POST e/business/devops/company/getRecords
```

完整访问时还要加服务前缀：

```text
/scm-devops-web/e/business/devops/company/getRecords
```

我们要追这条线：

```text
SupplierController
    ↓
SrmCompanyService
    ↓
SrmCompanyServiceImpl
    ↓
Utils.query
    ↓
SrmCompanyMapper
    ↓
srm_company 表
```

## 8. 供应商查询第一站：找 Controller

在 IDEA 里按：

```text
Ctrl + Shift + F
```

搜索接口路径：

```text
e/business/devops/company/getRecords
```

你会找到：

```text
SupplierController.java
```

里面有：

```java
@PostMapping("e/business/devops/company/getRecords")
public Result<PageList<SrmCompany>> getSrmCompanyList(@RequestBody PageModel model) {
    return Result.success(srmCompanyService.query(model));
}
```

先不要管泛型这一大串：

```java
Result<PageList<SrmCompany>>
```

你先按中文理解：

```text
返回一个 Result。
Result 里面装的是一页供应商公司数据。
每条数据是 SrmCompany。
```

这个方法做的事情很少：

```text
接收 PageModel
调用 srmCompanyService.query(model)
用 Result.success 包起来返回
```

这里很像前端接口 handler：

```js
router.post('/xxx', async (req, res) => {
  const data = await service.query(req.body)
  res.json(success(data))
})
```

你在 Controller 这一站只需要记住：

```text
Controller 不查数据库，它只是把请求转给 Service。
```

## 9. PageModel 是什么

把光标放到：

```java
PageModel
```

按 `Ctrl + 点击`。

你会看到：

```java
public class PageModel extends BasePageBean {
    private List<FilterDTO> filters;
}
```

意思是：

```text
PageModel 是前端传过来的分页 + 筛选条件。
```

它继承了 `BasePageBean`，分页字段大概率在父类里，比如：

```text
currentPage
limit
```

它自己多了一个：

```text
filters
```

也就是筛选条件。

再点进去看 `FilterDTO`：

```java
public class FilterDTO {
    private String field;
    private Integer condition;
    private String value;
}
```

你可以这样理解：

```text
field：要筛选哪个字段
condition：筛选方式，比如等于、包含、大于
value：筛选值
```

前端可能传类似这种结构：

```json
{
  "currentPage": 1,
  "limit": 10,
  "filters": [
    {
      "field": "company_name",
      "condition": 6,
      "value": "北京"
    }
  ]
}
```

这里的 `condition = 6` 在工具类里表示“包含”。

## 10. 从 Controller 跳到 Service

回到 `SupplierController`。

光标放到：

```java
srmCompanyService.query(model)
```

如果你 `Ctrl + 点击`，大概率会跳到接口：

```java
public interface SrmCompanyService extends IService<SrmCompany> {
    PageList<SrmCompany> query(PageModel model);
}
```

这是正常的。

接口只是说明：

```text
SrmCompanyService 有一个 query 能力。
```

现在要看真正实现，按：

```text
Ctrl + Alt + B
```

跳到：

```text
SrmCompanyServiceImpl
```

## 11. Service 实现类看什么

实现类代码很短：

```java
@Service
public class SrmCompanyServiceImpl extends ServiceImpl<SrmCompanyMapper, SrmCompany>
        implements SrmCompanyService {

    @Override
    public PageList<SrmCompany> query(PageModel model) {
        return Utils.query(model, this);
    }
}
```

先看：

```java
@Service
```

意思：

```text
这是一个 Service，Spring 会管理它。
```

再看：

```java
implements SrmCompanyService
```

意思：

```text
它是 SrmCompanyService 接口的具体实现。
```

再看：

```java
extends ServiceImpl<SrmCompanyMapper, SrmCompany>
```

这句看起来复杂，但你现在可以先粗略理解成：

```text
MyBatis-Plus 提供的通用 Service 能力。
它帮你把 SrmCompanyMapper 和 SrmCompany 绑定起来。
```

也就是说，这个类天生就有一些常见查询能力。

真正业务方法只有一行：

```java
return Utils.query(model, this);
```

这句意思是：

```text
把分页筛选参数 model 交给 Utils.query。
this 代表当前这个 Service。
Utils 会用当前 Service 去查数据库。
```

## 12. 进入 Utils.query

按住 `Ctrl` 点击：

```java
Utils.query
```

你会看到：

```java
public static <T> PageList<T> query(PageModel pageModel, IService<T> service){
    QueryWrapper<T> wrapper = getFilter(pageModel.getFilters());
    Page<T> page = new Page<>(pageModel.getCurrentPage(), pageModel.getLimit());
    IPage<T> iPage = service.page(page, wrapper);
    return PageList.createPageList(iPage.getRecords(), iPage.getTotal(), pageModel);
}
```

这段是这条链路里最核心的代码。

不要被 `<T>` 吓到。它只是表示：

```text
这个工具方法不只给 SrmCompany 用，也可以给别的表对象用。
```

我们当前这条链路里，`T` 就是：

```text
SrmCompany
```

逐行理解：

```java
QueryWrapper<T> wrapper = getFilter(pageModel.getFilters());
```

意思：

```text
把前端传来的筛选条件转换成数据库查询条件。
```

```java
Page<T> page = new Page<>(pageModel.getCurrentPage(), pageModel.getLimit());
```

意思：

```text
创建分页对象：第几页、每页多少条。
```

```java
IPage<T> iPage = service.page(page, wrapper);
```

意思：

```text
真正执行分页查询。
```

```java
return PageList.createPageList(iPage.getRecords(), iPage.getTotal(), pageModel);
```

意思：

```text
把查询结果和总数包装成项目统一的分页返回格式。
```

这就像 Node 里：

```js
const where = buildWhere(filters)
const rows = await model.findAndCountAll({ where, limit, offset })
return pageResult(rows)
```

## 13. getFilter 是怎么把筛选变成查询条件的

继续看：

```java
getFilter(pageModel.getFilters())
```

里面有：

```java
switch (condition) {
    case CONTAINS:
        wrapper.like(dto.getField(), dto.getValue());
        break;
    case IS_NULL:
        wrapper.isNull(dto.getField());
        break;
    case GREATER_THAN:
        wrapper.gt(dto.getField(), dto.getValue());
        break;
}
```

你可以这样理解：

```text
condition 决定用哪种查询方式。
```

比如：

```text
condition = 6
```

对应：

```java
wrapper.like(dto.getField(), dto.getValue());
```

也就是 SQL 里的：

```sql
where field like '%value%'
```

所以如果前端传：

```json
{
  "field": "company_name",
  "condition": 6,
  "value": "北京"
}
```

大概会变成：

```sql
where company_name like '%北京%'
```

这里顺手记一个代码阅读点：

```java
case EQUAL:
    wrapper.eq(dto.getField(), dto.getCondition());
```

这里看起来有点可疑。一般“等于”应该用 `dto.getValue()`，但这里用了 `dto.getCondition()`。

也就是说它可能会变成：

```text
field = 0
```

而不是：

```text
field = 前端传来的 value
```

这不一定马上就是线上 bug，但这是你读代码时可以记下的疑点。以后如果遇到“等于筛选不好用”，可以回来验证这里。

## 14. Mapper 是怎么和表关联的

现在从 `SrmCompanyServiceImpl` 里看这句：

```java
extends ServiceImpl<SrmCompanyMapper, SrmCompany>
```

按住 `Ctrl` 点击：

```text
SrmCompanyMapper
```

你会看到：

```java
@DS("srm")
public interface SrmCompanyMapper extends BaseMapper<SrmCompany> {
}
```

这里有两个重点。

第一个：

```java
@DS("srm")
```

意思：

```text
这个 Mapper 查的是 srm 数据源。
```

数据源的数据库地址、账号这些不在代码里，一般在 Nacos 配置里。

第二个：

```java
extends BaseMapper<SrmCompany>
```

意思：

```text
MyBatis-Plus 给这个 Mapper 提供了基础增删改查。
```

所以虽然 `SrmCompanyMapper` 里面没有写 SQL，它仍然可以查 `SrmCompany` 对应的表。

## 15. SrmCompany 是怎么对应数据库表的

按住 `Ctrl` 点击：

```text
SrmCompany
```

你会看到：

```java
@TableName("srm_company")
public class SrmCompany implements Serializable {
```

这句最重要：

```java
@TableName("srm_company")
```

意思：

```text
这个 Java 类对应数据库里的 srm_company 表。
```

再看一个字段：

```java
@TableId(value = "company_id", type = IdType.ASSIGN_UUID)
private String companyId;
```

意思：

```text
Java 里的 companyId 对应表里的 company_id。
它是主键。
```

再看：

```java
@TableField("company_name")
private String companyName;
```

意思：

```text
Java 里的 companyName 对应表里的 company_name。
```

这就是 Java 对象和数据库表之间的映射。

你可以类比成前端或 Node 里的 model：

```text
SrmCompany 类 = srm_company 表的一行数据
```

## 16. 这条查询链路完整串起来

现在把第二条线完整串起来：

```text
前端或调用方请求：
POST /scm-devops-web/e/business/devops/company/getRecords
        ↓
SupplierController.getSrmCompanyList
接收 PageModel
        ↓
SrmCompanyService.query
接口定义能力
        ↓
SrmCompanyServiceImpl.query
真正执行逻辑
        ↓
Utils.query
把 filters 转成 QueryWrapper，创建分页对象
        ↓
service.page(page, wrapper)
MyBatis-Plus 执行分页查询
        ↓
SrmCompanyMapper
使用 srm 数据源
        ↓
SrmCompany
对应 srm_company 表
        ↓
PageList<SrmCompany>
返回分页结果
        ↓
Result.success(...)
返回统一成功响应
```

这条链路是标准的：

```text
Controller -> Service -> Mapper -> Model -> Result
```

以后你看别的简单查询接口，也可以照这个模板追。

## 17. 在 IDEA 里建议你跟着做一遍

下面是你可以实际操作的一遍流程。

### 17.1 找启动类

```text
Ctrl + N
输入 DevopsApp
回车
```

看：

```text
main 方法
@SpringBootApplication
@EnableDiscoveryClient
@Import(DevopsWebConfig.class)
```

### 17.2 跳到 DevopsWebConfig

在 `DevopsWebConfig.class` 上：

```text
Ctrl + 点击
```

看：

```text
@ComponentScan
@MapperScan
```

### 17.3 搜接口入口

```text
Ctrl + Shift + F
搜索 e/business/devops/company/getRecords
```

打开：

```text
SupplierController
```

### 17.4 跳到 Service 接口

在：

```java
srmCompanyService.query(model)
```

上按：

```text
Ctrl + 点击
```

你大概率会到：

```text
SrmCompanyService
```

### 17.5 跳到 Service 实现

在 `query` 方法上按：

```text
Ctrl + Alt + B
```

进入：

```text
SrmCompanyServiceImpl
```

### 17.6 进入 Utils.query

在：

```java
Utils.query(model, this)
```

上：

```text
Ctrl + 点击
```

看分页和筛选逻辑。

### 17.7 找 Mapper 和表

回到 `SrmCompanyServiceImpl`。

在：

```text
SrmCompanyMapper
```

上：

```text
Ctrl + 点击
```

看：

```text
@DS("srm")
extends BaseMapper<SrmCompany>
```

再点：

```text
SrmCompany
```

看：

```text
@TableName("srm_company")
```

到这里，这条接口你就已经追完主线了。

## 18. 读源码时不要被这些东西卡住

### 18.1 不要一开始深究 import

文件顶部一堆：

```java
import ...
```

刚开始不用一行行看。等你看到某个类不知道是什么，再点进去看。

### 18.2 不要被泛型吓住

比如：

```java
Result<PageList<SrmCompany>>
```

先按中文读：

```text
Result 里面装 PageList。
PageList 里面每条是 SrmCompany。
```

### 18.3 不要被 extends 和 implements 吓住

先粗略理解：

```text
implements：实现一个接口。
extends：继承现成能力。
```

### 18.4 不要一上来读完整实体类

`SrmCompany` 字段很多，没必要从头读到尾。

你先只看：

```text
@TableName
@TableId
几个你关心的字段
```

比如：

```text
companyId
companyName
contactorName
contactorMobile
```

## 19. 这两条线你应该形成的理解

启动链路你要能说出：

```text
scm-cloud-devops 是启动工程。
DevopsApp 是启动类。
DevopsApp 引入 DevopsWebConfig。
DevopsWebConfig 扫描 devops 的 Controller、Service、Mapper。
```

供应商查询链路你要能说出：

```text
接口从 SupplierController 进来。
Controller 调 SrmCompanyService。
真正实现是 SrmCompanyServiceImpl。
它调用 Utils.query 做分页筛选。
底层 Mapper 是 SrmCompanyMapper。
Mapper 使用 srm 数据源。
实体 SrmCompany 对应 srm_company 表。
```

能说到这个程度，就已经不是“看不懂代码”，而是在建立后端源码地图了。

## 20. 下一步建议

你跟着本文在 IDEA 里走完后，可以继续做两个练习。

第一个练习：

```text
用同样方式追：
e/business/devops/mdmApply/getRecords
```

你会发现它和 `company/getRecords` 非常像。

第二个练习：

```text
用同样方式追：
e/business/devops/applyDataRecords/getRecords
```

这个会复杂一点，因为它不是简单 `Utils.query`，而是写了自定义 SQL。

等这两个练习做完，再看 `SourceController -> OpsApplyServiceImpl` 的运维流程，就不会那么突兀。

