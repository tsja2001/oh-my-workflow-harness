---
name: diagnose-scm-project
description: >-
  招采平台线上/测试环境排查模式（只读）。触发信号是用户描述症状而不是提需求——
  「线上报错了」「页面 404/502」「打不开」「没数据」「数据不对」「定时任务没跑」
  「昨天还好好的」「test 和 uat 不一样」「发版了但没生效」「镜像是旧的」「配置怎么不一样」
  「这个接口属于哪个服务」「这个页面在哪个仓库」，以及任何 CrashLoopBackOff / 环境漂移 / 配置对不上的情况。
  本 skill 是**脚本型**：先跑命令拿证据，不要先猜原因。
  正在推需求、写代码、聊行业时不要用本 skill——那是 enterprise-dev-workflow / industry-perspective 的地盘。
---

本文件只是**项目级加载器**，正史在仓库里（便于所有 AI 工具共享和 git 管理）。触发后立即：

1. 读 `skills/diagnose-scm-project/SKILL.md`（相对仓库根）——完整排查流程、安全边界、脚本清单。
2. **先跑 `bash skills/diagnose-scm-project/scripts/project.sh doctor`，别先猜。** 这个 skill 的全部价值就在"先拿证据"。
3. 需要环境地址、服务归属、中间件位置时，查 `ai-docs/系统地图.md`；需要仓库分层时查 `ai-docs/代码库地图.md`。

**硬边界（正史里有完整版，这里只列最要命的）**：
本 skill **严格只读**。禁止触发 Jenkins 构建、重启/伸缩/删除 K8s 资源、进容器、发布 Nacos 配置、
启停定时任务、写 MySQL/ES。禁止绕过 `scripts/browser/readonly-guard.js`。
禁止输出 cookie、token、authorization 头、密码、密钥。

`AGENTS.md` 的红线依然生效（尤其红线 3「生产环境 AI 不碰」、红线 5「核实，不猜」）。

不要只凭本加载器的描述行动；一切以正史文件为准。
