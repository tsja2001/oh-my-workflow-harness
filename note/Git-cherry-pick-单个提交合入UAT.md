# Git cherry-pick：把单个提交合入 UAT

- 日期：2026-08-11
- 工具：Codex
- 当前状态：已确认目标改动适合使用 `cherry-pick` 合入 `uat`
- 下一步：从最新 `uat` 新建个人分支，摘取提交，验证后提 MR

## 一、这次的实际场景

要把下面分支中的一个改动合入 `uat`：

```text
来源分支：fix/jicai-report-umb-yang
目标分支：uat
目标提交：f4e45eeff
提交说明：fix: 云采板块名称按字典统一
```

该提交只修改了一个文件：

```text
scm-order-report/src/main/java/com/pcitc/scm/order/report/service/impl/CentralizedProcurementReportServiceImpl.java
```

本地检查结果：新增 48 行、删除 3 行，补丁可以干净地应用到当时的 `uat`。

## 二、为什么用 cherry-pick

`cherry-pick` 的作用是：把某一个提交的改动复制到当前分支，并生成一个新的提交。

这次不建议直接合并整个来源分支，因为 `fix/jicai-report-umb-yang` 和 `uat` 的历史已经分叉，合并整条分支可能夹带其他无关提交。

也不建议这样复制文件：

```bash
git checkout fix/jicai-report-umb-yang -- 文件路径
```

这种做法会直接拿来源分支上的完整文件覆盖当前版本，可能误伤 `uat` 对该文件已有的改动，而且提交来源不如 `cherry-pick` 清晰。

## 三、推荐操作流程

### 1. 确认工作区干净

```bash
git status --short --branch
```

如果存在未提交改动，先确认它们的归属，不要直接执行后续命令。

### 2. 更新远程分支信息

```bash
git fetch origin
```

### 3. 更新本地 uat

```bash
git switch uat
git pull --ff-only origin uat
```

使用 `--ff-only` 可以避免 `git pull` 意外生成合并提交。如果无法快进，应先检查本地 `uat` 为什么与远程分叉。

### 4. 从最新 uat 新建个人分支

```bash
git switch -c fix/jicai-report-umb-uat-yang
```

不要直接在公共 `uat` 分支上开发，方便审查、验证和回退。

### 5. 摘取目标提交

```bash
git cherry-pick f4e45eeff
```

成功后会在当前分支生成一个新提交。新提交的哈希通常和 `f4e45eeff` 不同，这是正常现象，因为它的父提交变了。

### 6. 检查摘取结果

```bash
git status --short --branch
git show --stat
git diff HEAD^ HEAD
```

重点确认：

- 只改了预期文件；
- 没有混入来源分支的其他改动；
- 业务改动内容与原提交一致。

### 7. 编译相关模块

```bash
mvn -pl scm-order-report -am -DskipTests compile
```

其中：

- `-pl scm-order-report`：编译指定模块；
- `-am`：同时编译它依赖的本项目模块；
- `-DskipTests`：跳过测试执行，但仍会完成编译检查。

### 8. 推送并创建 MR

公司仓库的远程 Git 操作需要先获得用户当次确认。确认后再执行：

```bash
git push -u origin fix/jicai-report-umb-uat-yang
```

然后创建 Merge Request：

```text
fix/jicai-report-umb-uat-yang → uat
```

## 四、发生冲突时怎么处理

如果 `cherry-pick` 报冲突，先查看冲突文件：

```bash
git status
```

手动处理冲突后继续：

```bash
git add <已解决的文件>
git cherry-pick --continue
```

如果发现目标提交不适合当前 `uat`，放弃本次摘取：

```bash
git cherry-pick --abort
```

`--abort` 会回到执行 `cherry-pick` 前的状态。

不要看到空提交提示就直接 `--skip`。空提交可能表示该改动已经通过其他提交进入 `uat`，需要先检查：

```bash
git log --oneline --all --decorate --grep='云采板块名称按字典统一'
git diff uat f4e45eeff -- <目标文件路径>
```

确认改动确实已经存在后，才考虑：

```bash
git cherry-pick --skip
```

## 五、常用检查命令

查看某个提交改了哪些文件：

```bash
git show --stat --name-status f4e45eeff
```

查看提交的完整改动：

```bash
git show f4e45eeff
```

确认提交是否已经是目标分支的祖先：

```bash
git merge-base --is-ancestor f4e45eeff uat
echo $?
```

返回值含义：

- `0`：该提交已经在 `uat` 的历史中；
- `1`：该提交不在 `uat` 的历史中。

检查相同补丁是否可能以另一个提交哈希进入目标分支：

```bash
git cherry -v uat fix/jicai-report-umb-yang
```

输出开头：

- `+`：目标分支中没有发现等价补丁；
- `-`：目标分支中已经存在等价补丁。

## 六、回退方式

如果还处在冲突处理中：

```bash
git cherry-pick --abort
```

如果已经摘取成功，但只存在于新建的本地个人分支，最清晰的方式通常是删除这个临时分支，再从最新 `uat` 重新创建。删除前必须确认没有需要保留的本地改动。

如果提交已经推送或被其他人使用，不要改写公共历史，应对新生成的提交执行：

```bash
git revert <cherry-pick 后的新提交哈希>
```

然后按团队流程提交回退 MR。

## 七、一句话判断

只需要另一个分支上的一个独立提交时，优先使用 `cherry-pick`；需要整条分支的完整开发历史时，才考虑 `merge`。
