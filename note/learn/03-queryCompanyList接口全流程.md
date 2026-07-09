# queryCompanyList 接口全流程学习

这一节我们真正进入一个接口。

选择这个接口：

```text
POST /scm-srm-web/s/business/srm/company/queryCompanyList
```

它的业务含义是：查询供应商简单信息列表。

这个接口很适合作为第一个完整样例，因为它包含了后端接口里最常见的结构：

```text
Controller 接请求
  -> Service 定义业务能力
  -> ServiceImpl 写业务逻辑
  -> Mapper 查数据库
  -> Model 映射数据库表
  -> VO 返回给前端
```

## 1. 先看总流程

```text
前端传分页和查询条件
  -> CompanyController.queryCompanyList
  -> CompanyReadService.queryCompanyList
  -> CompanyReadServiceImpl.queryCompanyList
  -> companyMapper.selectPage
  -> 查询 srm_company 表
  -> 再查供应商产品目录
  -> 组装 CompanyListVO
  -> PageList 包装分页
  -> Result.success 返回前端
```

你先不要追每一行。先记住它是一个标准的“查询列表接口”。

## 2. 这一条链路涉及哪些文件

| 顺序 | 文件 | 作用 | 你现在重点看什么 |
| --- | --- | --- | --- |
| 1 | `CompanyController.java` | HTTP 接口入口 | `@PostMapping`、参数、返回值、调用哪个 Service |
| 2 | `CompanyReadService.java` | Service 接口 | 定义了 `queryCompanyList` 这个业务能力 |
| 3 | `CompanyReadServiceImpl.java` | Service 实现 | 真正查询和组装数据 |
| 4 | `CompanyMapper.java` | 数据库 Mapper | 继承 `BaseMapper<Company>`，提供查表能力 |
| 5 | `Company.java` | 数据库实体 | 对应表 `srm_company` |
| 6 | `CompanyListAO.java` | 查询参数对象 | 前端可传哪些查询条件 |
| 7 | `CompanyListVO.java` | 返回对象 | 返回给前端哪些字段 |

## 3. Controller：接口入口

文件：

```text
01zhaocai-end/scm-srm-all/scm-srm-company/src/main/java/com/pcitc/scm/srm/company/controller/CompanyController.java
```

接口方法：

```text
@PostMapping("s/business/srm/company/queryCompanyList")
queryCompanyList(@RequestBody DefaultPageBean<CompanyListAO> pageBean)
```

这段说明三件事：

| 点 | 含义 |
| --- | --- |
| `@PostMapping` | 这个接口只能用 POST 请求 |
| `s/business/srm/company/queryCompanyList` | Controller 内部路径 |
| `@RequestBody` | 参数从请求体 JSON 里来 |

结合 SRM 的 `context-path`：

```text
/scm-srm-web
```

完整接口路径就是：

```text
POST /scm-srm-web/s/business/srm/company/queryCompanyList
```

Controller 里实际做的事情很少：

```text
接收 pageBean
调用 companyService.queryCompanyList(pageBean)
把结果 Result.success(...) 返回
```

为什么 Controller 要这么薄？

因为 Controller 是“门口接待员”。它负责接请求、转交业务、返回结果。真正的业务逻辑不应该堆在 Controller 里，否则接口一多，Controller 会变成又长又乱的文件。

## 4. 请求参数：前端传什么

这个接口参数是：

```text
DefaultPageBean<CompanyListAO>
```

可以先简单理解成：

```text
DefaultPageBean = 分页外壳
CompanyListAO = 具体查询条件
```

`CompanyListAO` 文件：

```text
01zhaocai-end/scm-srm-all/scm-srm-company-api/src/main/java/com/pcitc/scm/srm/company/api/ao/CompanyListAO.java
```

里面能看到这些查询字段：

| 字段 | 含义 |
| --- | --- |
| `companyId` | 公司 ID |
| `companyName` | 企业名称 |
| `companyCode` | 供应商编码 |
| `productCateName` | 产品目录名称 |
| `serviceCompanyCode` | 服务供应商编码 |

所以前端大概会传这种结构：

```json
{
  "currentPage": 1,
  "limit": 10,
  "model": {
    "companyName": "测试供应商",
    "companyCode": "SUP001",
    "productCateName": "钢材"
  }
}
```

不一定完全就是这些字段名，但理解方向是：外层管分页，`model` 里放查询条件。

为什么要用 `DefaultPageBean<CompanyListAO>`？

因为查询列表接口几乎都需要分页。如果每个接口都自己定义 `pageNum`、`pageSize`、查询条件，会很乱。统一用分页外壳后，前端和后端都能按同一种格式处理列表查询。

## 5. Service 接口：定义业务能力

文件：

```text
01zhaocai-end/scm-srm-all/scm-srm-company/src/main/java/com/pcitc/scm/srm/company/service/read/CompanyReadService.java
```

里面有：

```text
PageList<CompanyListVO> queryCompanyList(DefaultPageBean<CompanyListAO> pageBean)
```

这表示：

```text
输入：分页查询参数
输出：供应商简单信息分页列表
```

为什么还要有 Service 接口？

它像一份“业务合同”：

```text
Controller 只知道有 queryCompanyList 这个能力。
至于这个能力怎么实现，由 CompanyReadServiceImpl 负责。
```

好处是分层清楚：

```text
Controller 不关心查询细节。
ServiceImpl 可以改业务逻辑。
Controller 调用方式不用变。
```

## 6. Service 实现：真正干活

文件：

```text
01zhaocai-end/scm-srm-all/scm-srm-company/src/main/java/com/pcitc/scm/srm/company/service/impl/read/CompanyReadServiceImpl.java
```

方法：

```text
queryCompanyList(...)
```

它的大概逻辑是：

```text
1. 打印请求日志
2. 从 pageBean 里取出查询条件 model
3. 创建 MyBatis-Plus 分页对象 Page
4. 创建查询条件 QueryWrapper
5. 如果 companyCode 不为空，加 company_code like 条件
6. 如果 companyName 不为空，加 company_name like 条件
7. 调 companyMapper.selectPage(...) 查 srm_company 表
8. 遍历查出的 Company 列表
9. 把 Company 复制成 CompanyListVO
10. 根据 companyId 再查产品目录
11. 把产品目录名称拼到 productCateName
12. 返回 PageList
```

这段逻辑可以用伪代码理解：

```text
queryParams = pageBean.model

分页对象 = 当前页 + 每页条数

查询条件 = new QueryWrapper
if companyCode 不为空:
  查询条件加 company_code like companyCode

if companyName 不为空:
  查询条件加 company_name like companyName

公司分页结果 = companyMapper.selectPage(分页对象, 查询条件)

for 每个公司:
  复制成 CompanyListVO
  查这个公司的产品目录
  拼接产品目录名称
  加入返回列表

return PageList(返回列表, 总条数, 分页参数)
```

你现在看这段代码时，不要先纠结每个工具类。先抓住两个核心：

```text
先查供应商公司。
再按公司查产品目录并补充返回字段。
```

## 7. Mapper：真正查数据库

文件：

```text
01zhaocai-end/scm-srm-all/scm-srm-company/src/main/java/com/pcitc/scm/srm/company/repositories/CompanyMapper.java
```

它继承：

```text
BaseMapper<Company>
```

`BaseMapper` 是 MyBatis-Plus 提供的通用数据库操作接口。你可以理解成“常用 SQL 工具箱”。

它自带很多常用方法：

```text
selectById
selectOne
selectList
selectPage
insert
updateById
deleteById
```

在这个接口里，Service 调的是：

```text
companyMapper.selectPage(...)
```

意思是：

```text
按分页对象和查询条件，查询 Company 对应的数据库表。
```

它为什么知道查哪张表？

因为 `Company` 实体类上写了表名。

## 8. Model：实体和数据库表的对应关系

文件：

```text
01zhaocai-end/scm-srm-all/scm-srm-company/src/main/java/com/pcitc/scm/srm/company/model/Company.java
```

关键注解：

```text
@TableName("srm_company")
```

这说明：

```text
Company 这个 Java 类对应数据库表 srm_company。
```

里面字段也有映射，例如：

| Java 字段 | 数据库字段 | 含义 |
| --- | --- | --- |
| `companyId` | `company_id` | 公司 ID |
| `companyName` | `company_name` | 企业名称 |
| `companyCode` | 代码中查询用 `company_code` | 供应商编码 |
| `businessScope` | `business_scope` | 经营范围 |
| `contactorMobile` | `contactor_mobile` | 联系电话 |

所以当 Service 调：

```text
companyMapper.selectPage(...)
```

实际查的是：

```text
srm_company
```

## 9. VO：返回给前端的数据

文件：

```text
01zhaocai-end/scm-srm-all/scm-srm-company-api/src/main/java/com/pcitc/scm/srm/company/api/vo/CompanyListVO.java
```

它包含：

| 字段 | 含义 |
| --- | --- |
| `companyId` | 公司 ID |
| `companyName` | 企业名称 |
| `companyCode` | 供应商编码 |
| `productCateName` | 产品目录名称 |

为什么不直接把 `Company` 返回给前端？

因为 `Company` 是数据库实体，字段很多，很多字段前端不需要，也不一定适合直接暴露。

`VO` 是 View Object，可以理解成“专门给前端看的对象”。

这样设计的好处：

```text
数据库表怎么设计，不直接绑死前端返回格式。
前端只拿需要的字段。
后端可以隐藏敏感字段或无关字段。
```

## 10. 返回包装：`Result` 和 `PageList`

Controller 返回：

```text
Result<PageList<CompanyListVO>>
```

可以拆开看：

```text
Result = 统一响应外壳
PageList = 分页结果
CompanyListVO = 每一条供应商数据
```

也就是返回结构大概是：

```json
{
  "code": "成功码",
  "message": "成功信息",
  "data": {
    "total": 100,
    "currentPage": 1,
    "limit": 10,
    "root": [
      {
        "companyId": "xxx",
        "companyName": "某供应商",
        "companyCode": "SUP001",
        "productCateName": "钢材 管材"
      }
    ]
  }
}
```

字段名不一定完全一致，但结构就是：

```text
统一响应外壳
  -> 分页数据
      -> 列表项
```

为什么要统一响应？

因为前端处理接口时，不希望每个接口返回格式都不一样。统一后，前端可以固定按：

```text
判断 code
读取 data
展示列表
```

## 11. 这个接口的几个关键设计点

### 设计点 1：Controller 很薄

Controller 只负责接收请求和返回结果。

好处：

```text
入口清楚。
业务逻辑集中在 Service。
接口多了也不容易乱。
```

### 设计点 2：Service 分接口和实现

`CompanyReadService` 定义能力，`CompanyReadServiceImpl` 实现能力。

好处：

```text
调用方只依赖接口。
实现可以替换。
业务边界更清楚。
```

### 设计点 3：Mapper 专门负责数据库

Service 不直接写底层数据库操作，而是调 Mapper。

好处：

```text
业务逻辑和数据访问分开。
SQL 和表映射更集中。
后续排查数据库问题更方便。
```

### 设计点 4：Model 和 VO 分开

`Company` 是数据库实体，`CompanyListVO` 是返回给前端的视图对象。

好处：

```text
数据库字段不直接暴露给前端。
返回结构可以按页面需要定制。
```

## 12. 你现在该怎么读这段代码

按这个顺序读：

```text
1. CompanyController.queryCompanyList
   看接口路径、参数、返回值、调用哪个 Service。

2. CompanyReadService.queryCompanyList
   看这是一个什么业务能力。

3. CompanyReadServiceImpl.queryCompanyList
   看查询条件怎么组装、查了哪些 Mapper。

4. CompanyMapper
   看是否继承 BaseMapper，有没有自定义 SQL。

5. Company
   看对应哪张表，主要字段是什么。

6. CompanyListAO / CompanyListVO
   看前端传什么、后端返回什么。
```

## 13. 学完这个接口后，你应该能回答

1. 这个接口完整 URL 是什么？
2. 为什么它必须用 POST？
3. 前端查询条件放在哪个对象里？
4. Controller 为什么只写几行？
5. `CompanyReadService` 和 `CompanyReadServiceImpl` 有什么区别？
6. `companyMapper.selectPage` 查的是哪张表？
7. 为什么返回 `CompanyListVO`，而不是直接返回 `Company`？
8. `Result<PageList<CompanyListVO>>` 三层分别代表什么？

能回答这些，就说明你已经真正跑通了一个接口的阅读方式。

下一步我们可以继续看：

```text
ServiceImpl 里每一行查询条件具体是什么意思
```

也可以换一个“新增/保存类接口”，对比查询接口和写入接口的区别。
