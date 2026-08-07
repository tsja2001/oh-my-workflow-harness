# Git 日常操作教程（本项目）

这份教程只讲本项目最常用、最安全的操作。

本文件已放进根仓库的本地排除规则，不会出现在 `git status`，也不会被提交到远程。

## 一、先记住 6 条

1. 一定先进入正确的子仓库，再执行 Git 命令。
2. `commit`、`merge`、`rebase` 都是本地操作，不会直接影响远程。
3. `push` 才会修改远程；本项目的普通 `git push` 已被拦截。
4. 真要推送时，由你本人运行 `git-human-push`，AI 不运行。
5. 新需求通常从 `prod` 建 feature 分支；`test` 只用于合并测试，不直接开发。
6. 不用 `git push --force`、`git reset --hard`、`git add .`。

## 二、每次操作前先确认仓库和分支

先进入 AI 告诉你的仓库，例如：

```bash
cd /home/t/projects/work-wsl/01zhaocai-end/scm-source-all
```

然后执行：

```bash
git rev-parse --show-toplevel
git status --short --branch
git branch --show-current
```

确认两件事：

- 第一条输出的是你要操作的子仓库，不是 `/home/t/projects/work-wsl` 根目录。
- 当前分支是 AI 告诉你的分支。

路径或分支不对就先停，不要继续。

## 三、常用概念

- `prod`：生产基线。新需求通常从这里开始。
- `feature/xxx-yang`：你的开发分支，一个大需求长期使用一个分支。
- `test`：测试环境分支，只接收已经开发好的代码。
- `origin/test`：上次从远程读取到本地的 test 快照，不是另一个正在运行的远程仓库。
- `fetch`：只更新远程快照，不改你的代码。
- `pull --ff-only`：把远程最新代码安全地快进到当前分支；出现分叉就停止，不自动制造合并提交。
- `commit`：保存一个本地版本。
- `push`：把本地版本送到远程，只有这一步会影响同事。

## 四、新需求：从 prod 建 feature 分支

工作区必须是干净的；`git status --short` 有内容时先问 AI。

```bash
git fetch origin
git switch prod
git pull --ff-only origin prod
git switch -c feature/需求拼音-yang
```

例如：

```bash
git switch -c feature/taizhang-yang
```

如果是在尚未上线的旧功能上修补，不要擅自从 `prod` 建新分支。优先继续原 feature 分支；到底基于 feature 还是 test，让 AI 根据代码历史给你明确命令。

## 六、把 feature 分支推到远程

第一次推送前先检查：

```bash
git status --short --branch
git log --oneline origin/prod..HEAD
git diff --stat origin/prod...HEAD
```

确认只有本需求后，由你本人运行：

```bash
git-human-push -u origin feature/需求拼音-yang
git-human-push -u origin feature/report-yang

```

终端会显示仓库和完整命令。确认无误后输入大写：

```text
PUSH
```

同一分支以后已经设置好上游时，可以直接运行：

```bash
git-human-push
```

## 七、把 feature 合入 test

先更新 test，并在本地模拟合并：

```bash
git fetch origin
git switch test
git pull --ff-only origin test
git branch backup/test-before-需求简称 HEAD
git merge --no-commit --no-ff feature/需求拼音-yang
git status --short
git diff --stat HEAD
git diff --check
```

如果出现冲突或混入无关文件，先停下来让 AI 检查。不要凭感觉解决。

如果合并内容正确：

```bash
git commit -m "feat: 合入需求简称"
git status --short --branch
git log --oneline origin/test..test
git diff --stat origin/test..test
git-human-push origin test
```

如果模拟合并不对，而且还没有提交：

```bash
git merge --abort
```

如果 AI 判断完整 merge 会带入无关历史，才改用：

```bash
git merge --abort
git cherry-pick -x 本次提交号
git log --oneline origin/test..test
git diff --stat origin/test..test
git-human-push origin test
```

有多个提交时，提交号和执行顺序必须让 AI 明确列出来。

## 八、拦截器怎么用

普通推送：

```bash
git push
```

会看到“已阻止远程写入”，这是正常现象。

只有你本人需要推送时才使用：

```bash
git-human-push <原来 git push 后面的参数>
```

常见例子：

```bash
# 第一次推送 feature
git-human-push -u origin feature/taizhang-yang

# 推送当前已绑定上游的分支
git-human-push

# 推送 test
git-human-push origin test
```

拦截器只保护 WSL 里的 Git。不要改用 Windows `git.exe`、IDEA 的强推按钮或 GitLab 页面操作来绕过它。

## 九、出错时怎么停下来

合并冲突，放弃本次合并：

```bash
git merge --abort
```

挑提交发生冲突，放弃本次挑选：

```bash
git cherry-pick --abort
```

发现分支、文件、提交号或推送目标不确定时：不要继续，让 AI 重新检查并给完整命令。

已经推错远程时：不要强推、不要删远程分支，立即告诉 AI，让 AI 准备普通 `revert` 回退方案，最后仍由你执行 `git-human-push`。

## 十、让 AI 交给你的推送清单

每次需要你动手前，让 AI 一次性给出：

1. 仓库完整路径。
2. 当前分支和要推送的远程分支。
3. 本次提交号、提交说明。
4. 推送前 `status`、`log`、`diff --stat` 的核对结果。
5. 你需要复制执行的完整 `git-human-push` 命令。
6. 推错后的回退命令。

任何一项不清楚，都先不要输入 `PUSH`。

## 十一、常用只读命令

```bash
# 当前在哪个仓库
git rev-parse --show-toplevel

# 当前分支
git branch --show-current

# 文件和分支状态
git status --short --branch

# 最近 10 个提交
git log --oneline --decorate -10

# 看未暂存改动
git diff

# 看准备提交的改动
git diff --cached

# 更新远程分支快照，不改当前代码
git fetch --all --prune
```

