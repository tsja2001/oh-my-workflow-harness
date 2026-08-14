# 命令手册（脚本没封装的那部分）

> **先查 `ai-docs/工具箱.md`。** 查库/查 ES/调接口/找前端页面/字段体检/隔离编译/本地起服务都已经有脚本了，
> 本手册**只收脚本封不住的东西**：需要按场景现拼的 SQL 侦察、样板搜索、Maven 私服解封、git 分支治理序列。
>
> 环境的两个坑（UNC 全树搜索超时、内联命令变量被 wsl 边界吞掉）见 `AGENTS.md §4`。
> 敏感信息永远不写进本手册、代码或提交。

## 目录

1. 数据库配置侦察（Phase 4.5）：字典核查法 / 导出模板核查法
2. 样板搜索（Phase 1/5）
3. Maven 私服解封（Phase 6，只在必须用 mvn 时）
4. git 分支治理序列（Phase 7）

---

## 1. 数据库配置侦察（Phase 4.5）

通用起手式——**不凭页面名称猜表名**：

```sql
SHOW DATABASES;  -- 认库名规律：<系统>_<模块>_<环境>，新表建在对应模块的 _test 库
-- 找同类表：
SELECT table_name, table_comment FROM information_schema.tables
 WHERE table_schema='<库>' AND (table_name LIKE '%<关键词1>%' OR table_name LIKE '%<关键词2>%');
-- 抄通用字段规范（字符集/主键类型/审计列/删除标记）：
SHOW CREATE TABLE <库>.<同类表>;
-- 定位配置表在哪个库：
SELECT table_schema, table_name FROM information_schema.tables WHERE table_name IN ('<字典表>','<模板表>');
```

### 1.1 字典配置核查法

字典至少三层：分组(group) → 类型(type) → 值(value)。**不要只看页面名称相似就复用**，必须确认编码、业务域和启用状态。

```sql
-- 1) 找字典相关表
SELECT table_schema, table_name FROM information_schema.tables
WHERE table_schema LIKE '%<模块或环境关键词>%' AND table_name LIKE '%dict%';

-- 2) 目标字典类型是否已存在（字段名按真实表结构替换）
SELECT * FROM <库>.<字典类型表>
WHERE <类型编码字段> = '<typeCode>' OR <类型名称字段> LIKE '%<中文名>%';

-- 3) 查字典值，确认 value / name / status / delete_sign / sort
SELECT * FROM <库>.<字典值表>
WHERE <类型关联字段> = '<typeId或typeCode>' ORDER BY <排序字段>;

-- 4) 判断唯一性，不猜"全库唯一"还是"类型内唯一"
SHOW CREATE TABLE <库>.<字典值表>;
```

判定规则：

- 类型编码明确匹配 + 所属分组业务域匹配 → 优先复用；只是名称相似但业务域不同 → **不复用**。
- 字典值编码要和已有业务数据、驾驶舱、报表对齐时，**优先沿用业务数据里已经在用的编码**。
- 是否全库唯一看唯一索引；没有证据时默认只要求同一字典类型下唯一。
- 页面新增后从库里反查：类型存在、值完整、状态启用、`delete_sign` 有效。

> 本项目实测：`scm_ubm_test.ubm_dict` **没有** `dict_value` 字段；真实字段是 `dict_code`（值）/ `dict_name`（显示名）/ `dict_status`（状态）/ `dict_type_code`（类型）。

### 1.2 Excel 导出模板核查法

遇到 Excel 导出，先完整读取同目录的 `export-template-playbook.md`。它是字段、ID、审计、SQL、跨环境和验收的唯一详细规范；本节只保留最初的定位命令。

普通列表/台账导出默认使用“导出模板配置 + 分页接口导出注解 + 前端传 exportRequest”，不要默认新增导出接口。

```bash
rg -n -g '*.java' 'ExportRequestTransfer|exportTemplateCode|exportRequest|DataRequestTransfer' <模块目录> | head -50
bash scripts/export-template.sh inspect test <templateCode>
```

```sql
SELECT table_schema, table_name FROM information_schema.tables WHERE table_name LIKE '%template%';
SHOW CREATE TABLE <库>.<模板主表>;      -- 字段长度、状态字段、唯一索引
SHOW CREATE TABLE <库>.<模板明细表>;
SELECT * FROM <库>.<模板主表>   WHERE <模板编码字段> = '<templateCode>';
SELECT * FROM <库>.<模板明细表> WHERE <模板关联字段> = '<templateId或templateCode>' ORDER BY <排序字段>;
```

定位完成后把模板写成需求 `sql/00-导出模板定义.json`，运行 `scripts/export-template.sh validate/verify/diff`；新建时再按环境授权运行 `apply`。不要在本手册复制一份字段规则，避免和专项规范分叉。

> 本项目实测：导出模板不在 `scm_source_test`，在 `scm_ubm_test.scm_simple_template` / `_sub`；
> 明细排序字段叫 `sort_name`，主表分组字段叫 `group_code`（不是 `sort_number`/`group_id`）。

## 2. 样板搜索（Phase 1/5）

```bash
# 按业务关键词找同类功能
grep -rli --include="*.java" "<业务词如 ledger/台账>" <模块目录> | head
# 找分页 + 导出样板
grep -rn "DataRequestTransfer\|queryPageList" --include="*.java" <目录> | head
# 找编号生成样板
ls <模块>/src/main/java/**/seq/ 2>/dev/null; grep -rn "createId\|Sequence" --include="*.java" <目录> | head
# 找定时任务样板
grep -rl --include="*.java" "@XxlJob\|@Scheduled" <目录>
# 找 AIM 注册点（跨服务调用/XXL-JOB 入口）
grep -rn "@TypeMapping\|@MethodMapping" --include="*.java" <目录> | head
# 确认引用的每个样板文件真的存在（写进文档前必做）
ls -1 <完整路径1> <完整路径2> ...
```

前端样板不要用 grep 找，用 `bash scripts/fe.sh find <中文关键词>`（52 个仓，硬搜必踩错仓）。

## 3. Maven 私服解封（只在必须用 mvn 时）

平时验证代码用 `bash scripts/jc.sh` 就够了。只有要 `mvn -pl <模块> install` / `package`（例如给 `srun.sh` 重打 fat jar）时才需要这段。

本机 Maven 3.8.7 默认封锁 http 仓库，公司私服是 http。写一份**临时** settings，用 `-s` 传入，**绝不改用户全局配置**：

```xml
<!-- /tmp/tz/settings.xml：把封锁镜像的 mirrorOf 改成无效值使其失效，并声明公司私服 -->
<settings>
  <mirrors><mirror>
    <id>maven-default-http-blocker</id><mirrorOf>dummy-block-nothing</mirrorOf>
    <name>neutralized</name><url>http://0.0.0.0/</url>
  </mirror></mirrors>
  <profiles><profile><id>company-nexus</id>
    <repositories><repository><id>scm-jdsn</id><url>http://nexus.jdsn.com.cn/repository/maven-public/</url>
      <releases><enabled>true</enabled></releases><snapshots><enabled>true</enabled></snapshots>
    </repository></repositories>
    <pluginRepositories><pluginRepository><id>scm-jdsn</id><url>http://nexus.jdsn.com.cn/repository/maven-public/</url>
      <releases><enabled>true</enabled></releases><snapshots><enabled>true</enabled></snapshots>
    </pluginRepository></pluginRepositories>
  </profile></profiles>
  <activeProfiles><activeProfile>company-nexus</activeProfile></activeProfiles>
</settings>
```

注意：`mvn -pl <模块> -am compile` 在本项目**必失败**——反应堆兄弟模块没发布到 Nexus，依赖解析走不通。
不要试图修好它，那是 `jc.sh` 存在的原因（`ai-docs/本地运行手册.md §2`）。

## 4. git 分支治理序列（Phase 7）

分支策略与提交格式见 `ai-docs/团队规矩.md §1~2`。这里是具体命令顺序。

```bash
# 0) 侦察真实分支习惯（决定用 merge 还是 cherry-pick）
git fetch --all --prune
git status --short --branch
git branch -vv
git log --first-parent --oneline origin/test -30
git log --first-parent --oneline origin/uat  -30
git log --first-parent --oneline origin/prod -30

# 1) 操作前备份
git branch backup/<说明> HEAD
git diff --output=/tmp/<说明>.patch -- <自己的文件>

# 2) 在 feature 分支提交
git checkout <基线分支或原功能分支>
git pull --ff-only origin <分支名>
git checkout -b feature/<需求代号>-yang      # 一个大需求一个长期分支，不要一个小改动开一个
git add <逐个列出自己的文件>                  # 不要 git add .
git commit -m "feat: <简短表述>"              # 只写这一行
# push 要用户当次点头（红线 1）

# 3) 进入 test 前先模拟 merge
git checkout test && git pull --ff-only origin test
git merge --no-commit --no-ff feature/<需求代号>-yang
git status --short && git diff --stat HEAD && git diff --check
```

模拟之后的决策：

```bash
# A. merge 只带自己的改动 → 按团队习惯保留 merge commit
git commit -m "feat: 合入<需求简称>"

# B. merge 会带入无关历史 → 撤销，精准挑提交
git merge --abort
git cherry-pick -x <自己的提交号>
git log --oneline origin/test..test && git diff --stat origin/test..test

# C. 已经推到受保护 test 才发现历史不美观 → 不强推，用普通 merge/revert 修正
git revert <有问题的提交号>        # 代码要回退时
git merge --no-ff feature/<需求代号>-yang   # 只是补上开发分支关系时
```

**查别的分支的代码永远用 `git show <分支>:<路径>` 或 `git grep <模式> <分支> -- ...`，
严禁 `git checkout <分支> -- .`**（会把整个分支写进当前工作区，见 `ai-docs/安全红线.md §5`）。
