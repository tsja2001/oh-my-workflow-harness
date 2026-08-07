# XXL-JOB 集采日统计任务失败问题

> 日期：2026-08-05  
> 工具：Codex  
> 当前状态：✅ XXL-JOB 修复 `18f691cf4` 已部署 test，手动执行成功并写入前一天唯一一条统计记录；分页修复 `9c75b38f3` 已进入 `origin/test`，test 部署状态待确认；两项修复已准备到 UAT 交付分支，尚未推送。  
> 下一阶段：用户推送 `fix/jicai-export-uat-yang` 并向 `uat` 提 MR；确认 test 分页复测通过，部署 UAT 后复测任务和分页；test、UAT 全部通过前禁止在 prod 创建或启用任务。

## 一、结论先说

当前异常不是 Cron 写错、XXL-JOB 执行器故障、order 模块漏部署，也不是 ES 故障。

根因是：**集采日统计业务服务带 `@Transactional`，Spring 把它包装成了 CGLIB 事务代理；公司 AIM 扫描器只查看运行时代理类“直接实现”的接口，因此没有发现原接口上的 `@TypeMapping`，最终没有注册 `centralPurchaseDailyStatisticsService`。**

当前报错修完后还会暴露第二个问题：**定时任务传的是 `{}`，AIM 却要把它直接反序列化成 `Date`，Fastjson 1.2.83 不能把空对象转换成日期。** 因此不能只处理当前 `No Foud methodHandler`，必须同时调整调度入口的参数类型。

本次已经按局部方案修复：**新增一个不带事务的 AIM 调度门面，门面接收 `SyncParam`，再调用现有带事务的日统计业务服务。** 这样保留原事务、保留现有 XXL-JOB 参数，也不改公司公共 AIM 组件。

## 二、现状与影响范围

### 2.1 当前五种状态

| 状态 | 当前事实 |
|---|---|
| 预期 | 每天 `03:03` 调用 order 的集采日统计服务；参数 `{}` 表示按默认规则统计前一天，并把当月截至前一天的数据写入日统计表 |
| 已实现 | 原日统计查询和同步逻辑不变；提交 `18f691cf4` 已把 AIM 注解迁到独立非事务门面，并把任务参数改由 `SyncParam` 接收 |
| 已配置 | test 为任务 240；UAT 交接链接为任务 216；两边都使用 `simpleJobHandler` 和相同任务参数 |
| 已部署 | test 已部署 XXL-JOB 修复 `18f691cf4`；分页修复 `9c75b38f3` 已进入 `origin/test`，部署状态待确认；UAT 仍为修复前版本 |
| 已验证 | test 任务手动执行成功，`2026-08-04 + YC_PLATFORM` 落库恰好1条；分页修复本地编译和分页探针通过，仍待部署后接口复测；UAT 交付分支已编译通过，尚未部署验证 |

### 2.2 当前任务配置

```text
任务描述：集采日统计服务
执行器：订单中心
Cron：0 3 3 * * ?
运行模式：BEAN
JobHandler：simpleJobHandler
任务参数：order-centralPurchaseDailyStatisticsService-syncCloudPurchaseData-{}
```

任务字段本身不用改；修复后仍保留这份参数，避免 test、UAT、prod 三套配置出现差异。

### 2.3 当前错误发生在哪一步

实际链路如下：

```text
XXL-JOB
  -> simpleJobHandler 解析四段任务参数
  -> Feign 调用 order
  -> order 的 AIMEngine 查找 centralPurchaseDailyStatisticsService
  -> 查找结果为空
  -> 抛出 No Foud methodHandler
```

日志中的异常位置是：

```text
Caused by: java.lang.RuntimeException:
No Foud methodHandler:centralPurchaseDailyStatisticsService
```

这个异常发生在查找业务方法和解析 `{}` 之前，所以当前还没有执行：

- `syncCloudPurchaseData` 方法；
- 查询 `to_user_order`、`to_order_product` 的统计 SQL；
- 对 `to_central_purchase_daily_statistics` 的新增或更新；
- 任何 ES 读写。

## 三、根因证据

### 3.1 修复前的服务名和方法名没有写错

修复前的接口版本（提交 `6f15ee11c`）：

`01zhaocai-end/scm-order-all/scm-order-report/src/main/java/com/pcitc/scm/order/report/service/CentralPurchaseDailyStatisticsService.java`

- `@TypeMapping("centralPurchaseDailyStatisticsService")`
- `@MethodMapping("syncCloudPurchaseData")`
- `int syncCloudPurchaseData(Date statisticsDate)`

与任务参数中的第二、三段完全一致，所以不是拼写不一致。

修复后相同的 AIM 名称已迁至 `CentralPurchaseDailyStatisticsJobService.java:13,22`，任务参数主体不变。

### 3.2 服务存在，但因为事务被 Spring 包装

当前实现：

`01zhaocai-end/scm-order-all/scm-order-report/src/main/java/com/pcitc/scm/order/report/service/impl/CentralPurchaseDailyStatisticsServiceImpl.java`

- 第 31～34 行：实现类是 Spring `@Service`，并实现上述业务接口；
- 第 89～114 行：新增、修改、删除方法带事务；
- 第 240～242 行：定时同步方法也带 `@Transactional(rollbackFor = Exception.class)`。

Spring Boot 当前默认采用 CGLIB 事务代理。可以把它理解成：运行时真正放进 Spring 容器的不是原服务本人，而是外面包了一层“事务外壳”。

### 3.3 AIM 扫描器没有拆开这层事务外壳

公共扫描器：

`01zhaocai-end/scm-assemblies-all/scm-share-aim-all/scm-share-aim-spring/src/main/java/com/pcitc/scm/share/aim/spring/impl/MethodHandlerServiceImpl.java`

关键逻辑在第 36～57 行：

```java
cs = object.getClass().getInterfaces();
for (Class<?> c1 : cs) {
    tm = c1.getAnnotation(TypeMapping.class);
    if (tm != null) {
        map.put(tm.value(), new MethodHandler(tm.value(), object, c1));
    }
}
```

它只看运行时类直接实现的接口。CGLIB 代理类直接暴露的是 Spring 代理接口，原来的 `CentralPurchaseDailyStatisticsService` 在其父类上，扫描器没有继续向父类和完整接口层级查找，因此没有把该服务放进 AIM 的 `map`。

随后 `AIMEngine.findMethodHandler` 在这里查不到并抛出当前异常：

`01zhaocai-end/scm-assemblies-all/scm-share-aim-all/scm-share-aim/src/main/java/com/pcitc/scm/share/aim/engine/AIMEngine.java` 第 106～115 行。

test 与 UAT 的上述接口和实现文件没有差异，并且都包含提交 `6f15ee11c`，所以两边出现同一错误符合代码现状。

### 3.4 为什么另一个集采任务 239 能成功

test 任务 239“集采管理业务统计报表-云采”在 2026-08-05 05:01 的 trigger 和 handle 均为成功。

它使用：

`CentralizedProcurementReportService.syncCentralizedOrderToEs(SyncParam)`

对应实现 `CentralizedProcurementReportServiceImpl` 没有 `@Transactional`，运行时仍是普通 Bean，AIM 可以直接看到其业务接口；同时它使用 `SyncParam` 接收 `{}`，不会尝试把空对象转换成 `Date`。

这组同模块、同执行器、同 AIM 链路的对比，进一步排除了 XXL-JOB、order 路由和 ES 连接导致当前异常的可能。

## 四、第二个必须同时处理的问题：`{}` 不能直接转成 `Date`

`AIMEngine.initParameters` 对只有一个参数的方法，会执行：

```java
parameters[0] = jsonService.read(dataJson, methodParameters[0].getType());
```

当前方法只有一个 `Date` 参数，所以它会执行等价于：

```java
JSONObject.parseObject("{}", Date.class);
```

项目使用 Fastjson 1.2.83。其日期反序列化器要求对象形式至少包含日期数值；空对象 `{}` 会抛出 `syntax error`。当前之所以还没看到这个错误，只是因为 AIM 在更早的服务查找阶段已经失败。

因此只修 AIM 扫描或只去掉事务，任务仍不能完整跑通。

## 五、这次和 ES 的关系

任务 240 的 `syncCloudPurchaseData`：

1. 从 MySQL 的 `to_user_order`、`to_order_product` 汇总；
2. 新增或更新 MySQL 的 `to_central_purchase_daily_statistics`；
3. 不读取、不创建、不写入 ES 索引。

任务 239 才是把云采订单写入统一集采报表 ES 的任务，属于前面的需求 03。任务 239 成功与任务 240 失败可以同时存在，两者不要混在一个故障里处理。

本次修复不需要新增：

- ES 索引；
- Nacos ES 配置；
- 数据字典；
- 数据库表或字段；
- 菜单、岗位权限；
- 新的 XXL-JOB 任务。

## 六、已实施的解决方案：新增非事务调度门面

### 6.1 设计目标

把两种职责拆开：

- **调度门面**：只负责让 AIM 找得到、解析任务参数、调用业务服务；不加事务。
- **业务服务**：继续负责查询、写表和事务回滚；现有实现不动。

可以把门面理解成前台：前台本身不办业务，只把正确参数交给里面的业务人员；业务人员原来的事务保护继续保留。

### 6.2 需要修改的文件

#### 修改 1：业务接口移除 AIM 注解

文件：

```text
scm-order-report/src/main/java/com/pcitc/scm/order/report/service/CentralPurchaseDailyStatisticsService.java
```

处理内容：

1. 删除 `MethodMapping`、`TypeMapping` 两个 import；
2. 删除接口上的 `@TypeMapping("centralPurchaseDailyStatisticsService")`；
3. 删除 `syncCloudPurchaseData`、`calculateRates` 上的 `@MethodMapping`；
4. 保留所有业务方法签名，不修改 Controller 和现有调用方。

目的：避免同一个 AIM 类型同时落在旧业务服务和新调度门面上，产生重复、覆盖顺序不确定的问题。

#### 修改 2：新增专用 AIM 调度接口

已新增：

```text
scm-order-report/src/main/java/com/pcitc/scm/order/report/service/CentralPurchaseDailyStatisticsJobService.java
```

实际结构：

```java
@TypeMapping("centralPurchaseDailyStatisticsService")
public interface CentralPurchaseDailyStatisticsJobService {

    @MethodMapping("syncCloudPurchaseData")
    int syncCloudPurchaseData(SyncParam param);

    @MethodMapping("calculateRates")
    CentralPurchaseDailyStatisticsRateVO calculateRates();

    class SyncParam {
        private String statisticsDate;

        public String getStatisticsDate() {
            return statisticsDate;
        }

        public void setStatisticsDate(String statisticsDate) {
            this.statisticsDate = statisticsDate;
        }
    }
}
```

注意点：

- `@TypeMapping` 和 `@MethodMapping` 的字符串保持不变，现有调度配置不需要修改；
- 日期先用字符串接收，格式固定为 `yyyy-MM-dd`，不要让 Fastjson 直接反序列化 `Date`；
- `calculateRates` 一并迁入门面，是为了保留提交 `6f15ee11c` 已经公开的 AIM 方法，防止存在尚未盘点到的调用方。

#### 修改 3：新增不带事务的门面实现

已新增：

```text
scm-order-report/src/main/java/com/pcitc/scm/order/report/service/impl/CentralPurchaseDailyStatisticsJobServiceImpl.java
```

实际核心逻辑：

```java
@Service
public class CentralPurchaseDailyStatisticsJobServiceImpl
        implements CentralPurchaseDailyStatisticsJobService {

    @Autowired
    private CentralPurchaseDailyStatisticsService dailyStatisticsService;

    @Override
    public int syncCloudPurchaseData(SyncParam param) {
        Date statisticsDate = null;

        if (param != null && StringUtils.isNotBlank(param.getStatisticsDate())) {
            try {
                statisticsDate = DateUtils.parseDateStrictly(
                        param.getStatisticsDate(), "yyyy-MM-dd");
            } catch (ParseException e) {
                throw new IllegalArgumentException(
                        "statisticsDate格式必须为yyyy-MM-dd", e);
            }
        }

        return dailyStatisticsService.syncCloudPurchaseData(statisticsDate);
    }

    @Override
    public CentralPurchaseDailyStatisticsRateVO calculateRates() {
        return dailyStatisticsService.calculateRates();
    }
}
```

硬性要求：

- 门面类和门面方法都不能添加 `@Transactional`；
- 真正的事务仍由 `CentralPurchaseDailyStatisticsServiceImpl.syncCloudPurchaseData` 承担；
- 日期非法时必须让任务明确失败，不能悄悄退回“昨天”，否则补跑错日期很难发现；
- 原同步 SQL、默认前一天逻辑、更新/新增逻辑不改。

### 6.3 修复后的参数用法

每天正常自动跑，继续使用：

```text
order-centralPurchaseDailyStatisticsService-syncCloudPurchaseData-{}
```

`{}` 会生成一个 `statisticsDate=null` 的 `SyncParam`，现有业务服务随后按前一天处理。

需要指定日期补跑时可以使用：

```text
order-centralPurchaseDailyStatisticsService-syncCloudPurchaseData-{"statisticsDate":"2026-08-04"}
```

公共执行器使用 `split("-", 4)`，只拆前三个分隔符，第四段 JSON 中日期的连字符会保留。

## 七、为什么不采用其他处理方式

| 方案 | 是否采用 | 原因 |
|---|---|---|
| 删除现有全部 `@Transactional` | 不采用 | 会丢失新增、修改、删除、同步的事务保护，属于业务回归 |
| 只删除同步方法上的事务 | 不采用 | 同一个类的其他方法仍有事务，整个 Bean 仍会被代理，当前问题不会消失 |
| 全局设置 `spring.aop.proxy-target-class=false` | 不采用 | 会改变整个 order 服务的代理方式，可能影响其他 Bean 注入，范围过大 |
| 把 `@TypeMapping` 再加到实现类 | 不采用 | 当前扫描器仍只检查运行时类的接口注解，不能解决代理层级问题 |
| 只把 `{}` 改成 `null` | 不采用 | 只能绕过 Date 解析，不能解决服务未注册 |
| 直接修改公共 AIM 扫描器 | 暂不作为本需求首选 | 长期方向正确，但要发布公共 jar 并回归所有业务服务，范围远大于这一个生产交接问题 |
| 新增非事务调度门面 | **采用** | 只影响 order 日统计任务，保留事务和调度参数，能一次解决注册及参数两个问题 |

## 八、长期公共方案（另立共享组件需求）

公共 AIM 扫描器后续可以考虑使用 Spring 提供的代理工具获取真实业务类和完整接口，例如：

```java
Class<?> targetClass = AopUtils.getTargetClass(object);
Class<?>[] interfaces = ClassUtils.getAllInterfacesForClass(targetClass);
```

但这属于 `scm-assemblies-all/scm-share-aim-spring` 共享组件改造，至少需要：

1. 增加普通 Bean、JDK 代理、CGLIB 代理三类扫描测试；
2. 确认重复 `TypeMapping` 的处理规则；
3. 发布新的公共 AIM jar 到 Nexus；
4. 重建并回归所有使用 AIM 的服务；
5. 再决定是否逐步移除各业务侧门面。

未经公共组件负责人确认，不要把这个共享改造夹进本次 order 补丁。

## 九、开发、部署和验收步骤

### 9.1 开发验证

已完成：

1. ✅ 目标分支 `fix/jicai-export-yang` 开工时与最新 `origin/test@2b358b4d4` 完全一致，工作区干净，没有夹带 UAT 或同事分支改动；
2. ✅ 完成上面 1 个修改文件、2 个新增文件；
3. ✅ 对新旧接口、新门面、原事务实现和原 Controller 共 5 个文件执行隔离编译，全部 0 报错并生成 class；
4. ✅ 使用项目真实的 `AIMEngine` 和 `JsonServiceImpl` 验证：`{}` 正常委托 null 日期，指定 `2026-08-04` 正确传入，非法 `2026-02-30` 明确失败；
5. ✅ 全仓只剩一个 `@TypeMapping("centralPurchaseDailyStatisticsService")`，不存在重复注册；
6. ✅ 原同步 SQL、Controller 方法签名、业务事务、表结构、ES 配置和任务 239 均未修改；
7. ✅ 已本地提交 `18f691cf4 fix: 修复集采日统计任务`；
8. ✅ 开发提交现已进入 `origin/test`；本次 UAT 准备过程未自动推送或操作远程分支。

### 9.2 test 部署后验收

XXL-JOB 修复 `18f691cf4` 已合入并部署，当前结果：

- ✅ 手动执行 test 任务 240 成功，未再出现 `No Foud methodHandler` 或日期解析异常；
- ✅ 接口查询到新记录 `JCRJH-20260804-001`；
- ✅ 数据库反查 `statistics_date=2026-08-04`、`execute_unit_code=YC_PLATFORM` 的有效记录恰好1条，创建时间为 `2026-08-05 16:23:02`；
- ⏳ 同日再次执行的幂等验收尚未记录；
- ⏳ 分页提交 `9c75b38f3` 已进入 `origin/test`，实际部署状态及接口复测结果待确认。

分页修复部署后继续按以下顺序验收：

1. **启动扫描验收**：order 启动日志必须出现类似：

   ```text
   aim scan: centralPurchaseDailyStatisticsService,
   com.pcitc.scm.order.report.service.CentralPurchaseDailyStatisticsJobService
   ```

2. **任务验收**：手动执行 test 任务 240，一次即可；确认调度结果和执行结果均为成功。
3. **日志验收**：日志中不得再出现：

   ```text
   No Foud methodHandler:centralPurchaseDailyStatisticsService
   syntax error
   ```

4. **落库验收**：检查昨天的 `YC_PLATFORM` 记录：

   ```sql
   SELECT id,
          serial_number,
          statistics_date,
          plan_quantity,
          response_quantity,
          executing_quantity,
          completed_quantity,
          delayed_quantity,
          create_time,
          update_time
   FROM scm_order_test.to_central_purchase_daily_statistics
   WHERE delete_sign = 0
     AND execute_unit_code = 'YC_PLATFORM'
     AND statistics_date = DATE_SUB(CURDATE(), INTERVAL 1 DAY);
   ```

   通过标准：目标日期恰好 1 条，数量字段非负；若源订单确实为 0，允许统计值为 0，但必须有记录。

5. **幂等验收**：再次手动执行同一任务，确认目标日期仍为 1 条，不能新增第二条；允许原记录的 `update_time` 更新。
6. **页面验收**：集采日计划统计页面能查询到目标日期，顶部比例与数量字段可以正常展示。

### 9.3 UAT 验收

两项修复已基于最新 `origin/uat@e53318979` 准备到既有交付分支 `fix/jicai-export-uat-yang`：

- `17657f510 fix: 修复集采日统计任务`
- `454b0854f fix: 修复集采日统计分页`

该分支相对 `origin/uat` 仅以上2个提交，4个相关 Java 文件隔离编译0报错，尚未推送。test 验收通过后，由用户推送并向 `uat` 提 MR；合入部署 order 后：

1. 执行 UAT 对应任务（当前交接链接为任务 216）；
2. 重复任务日志、落库、幂等和页面验收；
3. 两次环境验收结果都记录任务 ID、执行时间、目标统计日期和数据库记录 ID。

### 9.4 prod 交付门槛

以下条件全部满足后，才把“集采日统计服务”交给生产运维创建并启用：

- [ ] test 任务执行成功；
- [ ] test 同日重跑不新增重复数据；
- [ ] UAT 任务执行成功；
- [ ] UAT 同日重跑不新增重复数据；
- [ ] test、UAT 页面和数据库数量一致；
- [ ] prod order 已部署包含该修复的版本；
- [ ] 生产任务参数仍为 `order-centralPurchaseDailyStatisticsService-syncCloudPurchaseData-{}`；
- [ ] 生产首次手动执行后立即核对任务日志和 `to_central_purchase_daily_statistics`。

在以上条件满足前，原生产交接清单中的该任务应标记为“阻断，暂不创建/启用”，不能因为任务配置项已经齐全就视为可上线。

## 十、回退方案

如果修复部署后出现新的异常：

1. 先停止继续手动执行该任务，保留失败日志；
2. order 应用回退到部署前镜像或回退本次单独修复提交；
3. 只回退代码不会自动删除已经写入的统计记录；
4. 若产生错误业务数据，先记录目标日期和记录 ID，核对后再使用单独、可回滚的 SQL 处理，禁止直接清空整张表；
5. 回退后该任务会恢复为当前已知失败状态，因此不能当作最终解决方案，只能作为止损。

## 十一、本次证据索引

| 证据 | 位置/结果 |
|---|---|
| 修复前 AIM 类型和方法注解 | 提交 `6f15ee11c` 的 `CentralPurchaseDailyStatisticsService.java` |
| 修复后 AIM 类型和方法注解 | `CentralPurchaseDailyStatisticsJobService.java:13,22,30` |
| 非事务门面委托 | `CentralPurchaseDailyStatisticsJobServiceImpl.java:21-42` |
| 严格日期解析 | `CentralPurchaseDailyStatisticsJobServiceImpl.java:45-54` |
| 同步方法事务 | `CentralPurchaseDailyStatisticsServiceImpl.java:240-242` |
| 默认前一天 | `CentralPurchaseDailyStatisticsServiceImpl.java:243-247` |
| 写 MySQL 日统计表 | `CentralPurchaseDailyStatisticsServiceImpl.java:256-290` |
| AIM 代理不兼容扫描 | `MethodHandlerServiceImpl.java:36-57` |
| 当前异常抛出点 | `AIMEngine.java:106-115` |
| 单参数直接反序列化 | `AIMEngine.java:63-77`、`JsonServiceImpl.java:60-63` |
| 公共参数只拆四段 | `XxlJobExecutorServiceImpl.java:22-40` |
| 同模块成功对照 | test 任务 239，2026-08-05 05:01，trigger/handle 均成功 |
| 当前失败运行证据 | test 任务 240，2026-08-05 15:19，handle 失败；UAT 用户反馈同错误 |
| 修复前 test/UAT 代码一致 | 定位问题时，`origin/test..origin/uat` 对目标接口和实现文件 diff 为空 |

## 十二、当前尚未执行的操作

- 分页提交 `9c75b38f3` 已进入 `origin/test`，是否已部署及第1/2页接口结果待确认；
- UAT 交付分支已在本地准备提交 `17657f510`、`454b0854f`，尚未推送、提 MR、部署和验证；
- prod 尚未部署、建任务或执行任务；
- 未修改 ES、Nacos、菜单、字典和表结构；
- XXL-JOB 本次成功执行产生的统计记录属于正常业务结果，不是人工改库。

## 十三、部署后发现的分页问题及修复

### 13.1 现象

test 当前共有12条数据，每页10条：

- 第1页正常返回10条；
- 第2页请求传 `currentPage=2`、`start=10`，接口 `totalCount=12`，但 `root=[]`；
- 响应中的 `totalPage` 还错误地保持为0。

### 13.2 根因

前端参数没有问题：

- `start=10` 表示跳过前10条，是偏移量；
- `currentPage=2` 才表示第2页。

修复前 `CentralPurchaseDailyStatisticsServiceImpl.java:72` 使用：

```java
new Page<>(page.getStart(), page.getLimit())
```

MyBatis-Plus `Page` 的第一个参数是当前页码，因此后端把 `start=10` 错当成第10页，实际偏移到第90条，总共12条时自然返回空。

原代码还手工组装 `PageList`，先设置 `totalCount`、后设置 `limit`，没有触发正确的总页数计算，所以 `totalPage=0`。

### 13.3 运行证据

2026-08-05 使用自动登录脚本只读调用 test：

| 请求 | 结果 |
|---|---|
| `currentPage=1,start=0,limit=10` | 返回10条，`totalCount=12` |
| `currentPage=2,start=10,limit=10` | 返回0条，复现页面问题 |
| 仅作根因探针：`currentPage=2,start=2,limit=10` | 返回剩余2条，证明旧后端确实把 `start` 当页码 |

第三组只能用于证明根因，不能作为前端修复；前端必须继续按正常语义传 `start=10`。

### 13.4 已实施修复

分支：`fix/jicai-export-yang`  
提交：`9c75b38f3 fix: 修复集采日统计分页`

只修改 `CentralPurchaseDailyStatisticsServiceImpl.queryPage`：

```java
Page<CentralPurchaseDailyStatistics> pageResult =
        new Page<>(page.getCurrentPage(), page.getLimit());

return PageList.createPageList(voList, pageResult.getTotal(), page);
```

影响边界：

- 只影响集采日统计列表分页；
- 不修改前端；
- 不修改筛选条件和排序；
- 不修改定时任务、同步写表、事务、ES任务239或其他 order 页面。

### 13.5 本地验证

- ✅ Controller 和 ServiceImpl 隔离编译0报错，均生成 class；
- ✅ 分页探针：第2页 SQL offset=10；
- ✅ 分页探针：12条、每页10条时第2页2条；
- ✅ 返回元数据：`currentPage=2`、`totalPage=2`、`totalCount=12`；
- ⏳ 部署后仍需用页面原始参数复测。
