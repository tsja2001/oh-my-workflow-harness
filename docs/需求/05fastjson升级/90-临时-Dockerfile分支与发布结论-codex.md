# Fastjson SafeMode Dockerfile 分支与发布结论

> 日期：2026-07-29  
> 工具：codex  
> 当前状态：两个 03 启动仓均已从 `origin/test` 创建本地 `feature/fastjson-yang`，22 份目标 Dockerfile 已修改并分别本地提交；尚未推送、合入 test 或部署。  
> 下一阶段：用户按本文第 7 节命令推送两个 feature、合入各自 test；随后分批点击对应 `*-web-test`。

## 1. 先说结论

1. **需要改 Dockerfile 的两个仓都分环境。**
   - `03zhaocai-start/scm-cloud-starters-web`
   - `03zhaocai-start/scm-cloud-starters-wfproduct`
   - 两个仓都有 `dev/test/uat/prod` 远程分支。
   - Jenkins 的 `*-web-dev/test/uat` 任务也分别拉同名的 `dev/test/uat` 分支。

2. **这次 test 改造都从 `origin/test` 开 feature 分支。**
   - 最终代码要进入 `test`，但不要直接在 `test` 上开发。
   - 建议两个独立仓都使用同名分支：`feature/fastjson-yang`。

3. **不要按“哪个分支提交日期最新”来选。**
   - 应当看准备部署哪个环境，以及对应 Jenkins 实际拉哪个分支。
   - DPS 仓的 `uat` 提交日期比 `test` 新，但 `*-web-test` 明确只拉 `test`；在 `uat` 或 `main` 改都不会进入 test 镜像。

4. **`scm-assemblies-all` 不加 SafeMode。**
   - 它发布的是供其他项目引用的公共 jar，不是当前运行中的容器。
   - `mvn deploy` 只是把 jar 发到 Nexus，不会制作镜像，也不会替换 K8s Pod。
   - SafeMode 要加在真正启动 JVM 的 03 Dockerfile 中。

5. **本轮只做 test。**
   - 当前 Jenkins 有 web 的 dev/test/uat 任务，但没有任何 `*-web-prod`。
   - UAT 等 test 验证通过再处理；生产入口继续等运维确认。

## 2. 两个 Dockerfile 仓怎么开分支

| 仓库 | 当前本地状态 | Jenkins test 拉取 | 本次开发基线 | 最终进入 |
|---|---|---|---|---|
| `03zhaocai-start/scm-cloud-starters-web` | `feature/fastjson-yang`，工作区干净 | `test` | `origin/test@64dfc8f` | `test` |
| `03zhaocai-start/scm-cloud-starters-wfproduct` | `feature/fastjson-yang`，工作区干净 | `test` | `origin/test@42cf9d9` | `test` |

推荐做法：

```text
scm-cloud-starters-web
origin/test → feature/fastjson-yang → 本地提交 → 合入 test → 点各 scm-*-web-test

scm-cloud-starters-wfproduct
origin/test → feature/fastjson-yang → 本地提交 → 合入 test → 点 3 个 DPS web-test
```

注意：

- `scm-cloud-starters-wfproduct` 开工前本地在 `main`，但 `main@bca1026` 是 2023 年的旧线；本次已正确改为从 `origin/test` 开 feature。
- Source 的 SafeMode 提交目前只在 `scm-cloud-starters-web` 的 `test`，因此剩余服务继续基于 `origin/test` 最稳妥。
- 这两个仓互相独立，所以要各开一次分支、各有一个本地提交；分支名可以相同。

本地提交：

- `scm-cloud-starters-web`：`2f51dc1 fix: 完善fastjson安全模式配置`
- `scm-cloud-starters-wfproduct`：`58e8358 fix: 增加fastjson安全模式配置`

## 3. Jenkins 分支证据

2026-07-29 在线只读汇总了 66 个 `scm-*-web-*` 任务；下表两个业务启动仓共 65 个，另外 1 个是本轮排除的 Elasticsearch dev 任务：

| 启动仓 | dev 任务 | test 任务 | uat 任务 | prod 任务 |
|---|---:|---:|---:|---:|
| `scm-cloud-starters-web` | 18 个，全部拉 `dev` | 19 个，全部拉 `test` | 19 个，全部拉 `uat` | 0 |
| `scm-cloud-starters-wfproduct` | 3 个，全部拉 `dev` | 3 个，全部拉 `test` | 3 个，全部拉 `uat` | 0 |

抽查最近实际构建参数也一致：

- `scm-source-web-test #1688`：`GIT_BRANCH=test`
- `scm-source-web-uat #444`：`GIT_BRANCH=uat`
- `scm-dps-service-web-test #14`：`GIT_BRANCH=test`
- `scm-dps-service-web-uat #2`：`GIT_BRANCH=uat`

所以这里不是“找提交最靠前的分支”，而是：

> 要发 test，就让改动进入 `test`；要发 UAT，就让改动进入 `uat`。

## 4. 本次具体改动和 test 部署

### 4.1 主启动仓

仓库：`03zhaocai-start/scm-cloud-starters-web`

- 本地 feature 已给剩余 18 个 Java 服务 Dockerfile 增加 SafeMode。
- Source 已经生效，本次已清理两处重复配置，最终只保留一处 `JAVA_TOOL_OPTIONS`。
- 合入 test 后直接点对应的 `scm-<模块>-web-test`。
- **不用点 `*-all-test`**，因为本次没有修改 01 业务 jar。

### 4.2 DPS 启动仓

仓库：`03zhaocai-start/scm-cloud-starters-wfproduct`

本地 feature 已修改这 3 份：

- `scm-cloud-dps-service/Dockerfile`
- `scm-cloud-dps/Dockerfile`
- `scm-cloud-dpscore/Dockerfile`

合入 test 后点击：

- `scm-dps-service-web-test`
- `scm-dps-web-test`
- `scm-dpscore-web-test`

完整的 22 份更新/排除清单仍以同目录
`90-临时-Dockerfile更新与重新部署清单-codex.md` 为准。

## 5. 为什么 `scm-assemblies-all` 不处理 SafeMode

`scm-assemblies-all` 是“公共零件仓”：

- `scm-common-all/pom.xml:14` 的打包类型是 `pom`，负责聚合子模块。
- `scm-common-all/pom.xml:39-49` 配置的是发布到 Nexus。
- `scm-common-all/pom.xml:92` 包含 `scm-common-json`。
- `scm-common-json/pom.xml:8-14` 表明它是依赖 Fastjson 的公共 jar 模块。

所以昨天执行：

```text
mvn deploy
```

实际含义只是：

```text
公共代码 → 编译成 jar → 上传 Nexus
```

它不等于：

```text
构建 Docker 镜像 → 推 Harbor → 更新 K8s Pod
```

因此要分清两件事：

- **公共日期兼容修复**：需要先 `mvn deploy` 发新 jar，再重建使用它的 `*-web-test` 镜像，运行中的 Pod 才会拿到新代码。
- **Fastjson SafeMode**：不是写进公共 jar 的功能，而是每个运行中 JVM 的启动开关，所以只改 03 的运行 Dockerfile。

`scm-assemblies-all` 里虽然搜到一份 Dockerfile，但它属于 XXL Job 示例执行器：

- `scm-scheduling-all/pom.xml:14` 已把该 sample 模块注释掉。
- Jenkins 中没有 assemblies 构建任务，只有 `scm-scheduling-web-dev/test/uat`。
- 当前真正的调度中心启动包在
  `03zhaocai-start/scm-cloud-starters-web/scm-cloud-scheduling`：
  其 `pom.xml:127-130` 引用 assemblies 发布的 `xxl-job-web-jar`，
  运行镜像则由该目录的 Dockerfile 构建。

所以调度中心需要 SafeMode，但改的是：

```text
03zhaocai-start/scm-cloud-starters-web/scm-cloud-scheduling/Dockerfile
```

不是：

```text
01zhaocai-end/scm-assemblies-all/.../xxl-job-executor-sample-springboot/Dockerfile
```

## 6. UAT 和生产以后怎么处理

- 两个仓的 `test` 与 `uat` 历史并不完全一致。
- test 验证通过后，不要为了一个安全开关盲目把整条 test 历史灌进 UAT。
- 应从 `origin/uat` 开分支，把本次 SafeMode 提交单独 `cherry-pick -x` 过去，确认差异后再进入 `uat`。
- 生产没有 `*-web-prod`，暂时不切 prod、不部署，等运维给正式入口。

## 7. 下一步执行单

1. 用户推送两个仓的 `feature/fastjson-yang`。
2. 分别更新本地 `test`，再用 `merge --no-ff` 合入 feature。
3. 检查 test 相对远程只多出本次 merge 后再推送。
4. 用户分批点击对应 `*-web-test`；每批由 AI 核对新镜像、新 Pod 和 SafeMode 启动日志。

主启动仓命令：

```bash
cd /home/t/projects/work-wsl/03zhaocai-start/scm-cloud-starters-web
git push -u origin feature/fastjson-yang
git fetch origin
git switch test
git pull --ff-only origin test
git merge --no-ff feature/fastjson-yang -m "fix: 合入fastjson安全模式配置"
git log --oneline origin/test..test
git diff --stat origin/test..test
git push origin test
```

DPS 启动仓命令：

```bash
cd /home/t/projects/work-wsl/03zhaocai-start/scm-cloud-starters-wfproduct
git push -u origin feature/fastjson-yang
git fetch origin
git switch test
git pull --ff-only origin test
git merge --no-ff feature/fastjson-yang -m "fix: 合入fastjson安全模式配置"
git log --oneline origin/test..test
git diff --stat origin/test..test
git push origin test
```

任一步出现冲突或 `git pull --ff-only` 失败就停下，不要自行强推；把终端输出发给 AI 处理。

`scm-assemblies-all` 当前 `dev` 工作区还有未提交的
`JsonTransferUtil.java` 修改和未跟踪的 `.idea/`，本轮不碰，也不要把 `.idea/` 带入任何提交。
