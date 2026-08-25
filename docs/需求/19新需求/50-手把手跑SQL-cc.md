# 手把手：第一次自己在终端跑 SQL

> 日期：2026-08-24 ｜ 工具：cc
> 当前状态：教学 + 操作手册。**test 代码已部署，SQL 尚未成功执行**（2026-08-24 首次尝试撞 PXC 限制，脚本已修好并实测通过）。
> 下一步：直接跑第 3 步。test 现在正处在"老数据匹配不上、图上缺线"的空窗期，跑完即恢复。

写给第一次手动执行 SQL 的人。只讲这次要用的，不讲 SQL 语法。

---

## 0. 你要用的工具就一个

```bash
bash scripts/dbq.sh "<一句SQL>" <库名>
bash scripts/dbq.sh <某个.sql文件路径> <库名>
```

在 `/home/t/projects/work-wsl` 目录下跑。账号密码它自己从 `ai-docs/creds.env` 读，你不用管、也不要自己去拼 `mysql -h...`。

**两个库名认清楚，别打错：**

| 环境 | 库名 |
|---|---|
| test | `scm_source_test` |
| uat | `scm_source_uat` |

⚠️ **最大的坑**：这个账号是 `admin`，对 test 和 uat **都有完整的增删改权限**。库名打错一个字母，就是在 uat 上执行。每次回车前先扫一眼库名。

（生产库这个账号连不上，也不该由你跑——生产的 `03-prod-指标改名.sql` 是交给运维/DBA 的。）

---

## 1. 先热身：跑一句只读的，认认输出长什么样

```bash
bash scripts/dbq.sh "SELECT indicator_name, delete_sign, COUNT(*) AS cnt FROM sc_price_trend GROUP BY indicator_name, delete_sign;" scm_source_test
```

会打印一张 ASCII 表格。**SELECT 永远是安全的**，想跑几遍跑几遍，不会改任何东西。

（可能会看到一行 `mysql: [Warning] Using a password on the command line interface can be insecure.`——正常，忽略。）

---

## 2. 彩排：看看改完什么样，但不真改

```bash
bash scripts/dbq.sh "docs/需求/19新需求/sql/05-演练-事务预演不落库.sql"
```

这个文件里的 SQL 会**真的执行 UPDATE，然后立刻撤销**。跑完你会看到两张表：
- 第一张：改完的样子（旧名 0 行，新名有行）
- 第二张：撤销之后（又变回旧名）

第二张表变回旧名字，就说明彩排成功、数据库没被动过。

---

## 3. 真跑

```bash
bash scripts/dbq.sh "docs/需求/19新需求/sql/01-test-指标改名.sql"
```

这个文件很短，从上往下就四步，输出也按这个顺序打出来：

| 步 | 干什么 | 你要看什么 |
|---|---|---|
| 【0】 | `SELECT DATABASE()` | `current_db` = **`scm_source_test`**，不对就立刻停 |
| 【1】 | 建备份表 `sc_price_trend_bak_20260824` 并灌数据 | `backup_rows` = **6**（uat 那份是 24） |
| 【2】 | 两句 UPDATE 改名 | 无输出 |
| 【3】 | 列出所有钢材指标 | **列表里不该再出现"螺纹月成交价格""中厚板月成交价格"** |

跑完第【3】步应该长这样：

```
螺纹唐山出厂价      delete_sign=0   5     ← 4 条改名 + 1 条张雨本来就用新名录的
螺纹唐山出厂价      delete_sign=1   1
中厚板唐山出厂价    delete_sign=0   2
钢材月成交价格      delete_sign=0   5     ← 没动
```

⏰ **时机**：必须等 Jenkins 把后端部署完再跑。先跑 SQL 后发代码，test 驾驶舱那两条线会空一段。
（2026-08-24 现状：test 代码**已经部署好了**，所以现在就能跑，跑完缺的线就回来了。）

💡 **好消息：这个文件跑坏了不会跑一半**。`dbq.sh` 用的是 mysql 批处理模式，**遇到第一个错误就整个停下**，后面的语句一句都不会执行。所以第【1】步报错时，第【2】步的 UPDATE 根本没机会跑——2026-08-24 实测就是这样，报了 PXC 的错，库里一个字都没变。

---

## 4. 你问的"备份回滚是啥原理"

先说个前提：**MySQL 的 UPDATE 没有 Ctrl+Z**。默认是自动提交的，回车那一刻就已经改完并且对所有人生效了。所以保险只能事前做。

这次准备了**三层**，从轻到重：

### 第一层：事务预演（`05-演练`）—— 最轻，用来壮胆

```sql
START TRANSACTION;   -- 「接下来的改动先记在草稿纸上」
UPDATE ...;          -- 真改了，但只有你这个连接看得见
SELECT ...;          -- 看看改成什么样
ROLLBACK;            -- 「刚才那些不算」，全部丢弃
```

数据库支持"先改、再决定认不认"。`ROLLBACK` 一执行，草稿纸撕掉，表回到原样，别人全程什么都没看见。

**限制**：必须一次连接内跑完。分成几条命令分别执行就不成立了（每次 `dbq.sh` 都是一次新连接），所以彩排必须整个文件一起跑。

### 第二层：快照备份表（`01` 的第 0 段）—— 主力保险

```sql
CREATE TABLE sc_price_trend_bak_20260824 LIKE sc_price_trend;   -- 先建一张一模一样的空表
INSERT INTO sc_price_trend_bak_20260824
SELECT * FROM sc_price_trend WHERE indicator_name IN ('螺纹月成交价格','中厚板月成交价格');
```

新建一张表，把**要动的那几行原封不动复制进去**。

> 为什么要分两句写？公司这套 MySQL 是 **Percona XtraDB Cluster（集群版）**，而且开了 `pxc_strict_mode=ENFORCING`，
> 它**直接禁止** `CREATE TABLE ... AS SELECT`（一句话同时建表和灌数据）——因为在集群里这个语句的复制行为不安全。
> 拆成"先 `CREATE TABLE ... LIKE` 建空壳、再 `INSERT ... SELECT` 灌数据"就合法了，效果完全一样。
> 2026-08-24 在 test 上实测撞过这个错：`ERROR 1105 (HY000) ... Percona-XtraDB-Cluster prohibits use of CREATE TABLE AS SELECT`。

关键点：
- 这是**照片，不是镜子**。拍完之后原表怎么变，快照都不跟着变——这正是它能救命的原因。
- 表名带日期。跑第二遍会报"表已存在"，那是保护不是错误（防止你把第一次的好备份覆盖成第二次的坏数据）。
- 它只备份**被改的那几行**，不是整张表。因为这次改动范围就这么大，没必要拷全表。

出事了怎么用它救：

```sql
UPDATE sc_price_trend t
JOIN sc_price_trend_bak_20260824 b ON t.trend_id = b.trend_id
SET t.indicator_name = b.indicator_name;
```

意思是"照着快照，按主键一行一行把名字抄回去"。**这是最精确的还原方式**，只碰当初备份过的那几行，不会误伤任何新数据。

### 第三层（原来有，已删掉）：反向 UPDATE

原来准备过"把所有叫新名字的改回旧名字"这种写法。**已经废弃**，因为新代码上线后会有数据**天生就叫新名字**（test 上张雨 2026-08-24 16:55 录的 `JGQS-20260824-003` 就是），反向 UPDATE 会把它凭空改成一个它从没用过的名字。

有了第二层的备份表，回滚就是一句 JOIN，既简单又不会误伤——所以第三层没有存在的必要了。

### 一句话总结

| 层 | 什么时候用 |
|---|---|
| 事务预演（`05`） | 执行前想先看看效果，跑完数据库无变化 |
| 快照备份表（`01`/`02`/`03` 的【1】） | 执行前必做，这是唯一的保险 |
| 照备份表还原（`04`） | 出事时用，一句 JOIN，只碰当初备份过的行 |

---

## 5. 验完之后

test 验收通过、uat 也走完之后，那两张 `sc_price_trend_bak_20260824` 备份表可以删掉：

```bash
bash scripts/dbq.sh "DROP TABLE sc_price_trend_bak_20260824;" scm_source_test
```

**不急着删**，留一两个星期没坏处，它占不了多少空间。生产那张更要多留一阵。

---

## 6. 出错了怎么办

| 报错 | 意思 | 怎么办 |
|---|---|---|
| `No database selected` | 没写库名，SQL 里也没有 `USE` | 命令末尾补库名，或者用我们准备好的 `.sql` 文件（里面自带 `USE`） |
| `Table 'xxx' already exists` | 备份表已经建过了 | 说明你已经跑过第 0 段，别重跑；想重新备份先改个新表名 |
| `Percona-XtraDB-Cluster prohibits use of CREATE TABLE AS SELECT` | 集群版 MySQL 禁止"一句话建表并灌数据" | 拆成 `CREATE TABLE ... LIKE` + `INSERT ... SELECT` 两句。`01`/`02`/`03` 已经改好了 |
| `Unknown column 'xxx'` | 列名打错 | 用 `bash scripts/dbq.sh "SHOW COLUMNS FROM sc_price_trend;" scm_source_test` 看真实列名 |
| 改完发现数字不对 | — | **先别再动手**，把命令和输出发给我，用第二层快照还原 |
