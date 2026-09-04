# 物料树研究工具 · 开发交接

> 日期：2026-09-04
> 工具：codex
> 当前状态：独立 React 工具已完成并通过 test/UAT 真实数据与浏览器验收；未部署远端。
> 下一阶段：用户在 WSL 运行 `bash scripts/material-tree.sh dev`，浏览器打开 `http://127.0.0.1:4317` 使用。

> 目录调整：2026-09-04 按用户要求，需求文档、交接文档和 React 工程已统一放入当前 `物料树/` 目录；根目录启动脚本继续保留，方便一条命令运行。

## 1. 本次改了什么

新增了一个只在本机运行的“物料全景树”。页面能看完整一至四级类目、末级和停用节点，能按类目继续查具体物料，也能对比 test/UAT 的缺失、改名和状态差异。

登录由本地 Node 服务调用现有 `scripts/api.sh` / `scripts/auth.sh` 完成，浏览器里没有密码、token 或公司网关配置。公司现有 Vue 页面、Java 后端、数据库和环境配置均未改动。

| 文件/目录 | 新增/修改 | 用途 |
|---|---|---|
| `物料树/material-tree-explorer/` | 新增 | React + TypeScript + Vite + Ant Design 前端，以及只读 Node 本地服务 |
| `scripts/material-tree.sh` | 新增 | 一条命令安装、检查、构建、启动 |
| `ai-docs/工具箱.md` | 修改 | 登记新工具入口 |
| `物料树/13-物料树研究工具需求定稿-开发基线-codex.md` | 新增 | 需求范围、真实接口、安全边界和验收标准 |

## 2. 分支与提交

- 仓库：顶层文档/工具仓 `/home/t/projects/work-wsl`
- 本地分支：`feature/material-tree-yang`
- 功能提交：`ca95a795f8e77763dbf7808eb65c31cf57951d16`（`feat: 增加物料树研究工具`）
- 远程 Git：未 fetch、未 push、未创建 MR
- 回退：在确认没有后续依赖后，对上述提交执行 `git revert ca95a795f8e77763dbf7808eb65c31cf57951d16`

## 3. 启动方式

```bash
cd /home/t/projects/work-wsl
bash scripts/material-tree.sh dev
```

浏览器打开：`http://127.0.0.1:4317`

其他命令：

```bash
bash scripts/material-tree.sh check   # 类型 + 单测 + 构建
bash scripts/material-tree.sh build   # 只构建
bash scripts/material-tree.sh start   # 启动已构建版本
```

## 4. 验证证据

| 验证项 | 结果 |
|---|---|
| `bash scripts/material-tree.sh check` | TypeScript 通过；Vitest 1 个文件、4 条用例全过；Vite 构建成功 |
| test 自动登录状态 | credentials / gateways configured，token 有效；未输出 token 内容 |
| UAT 自动登录状态 | 自动刷新登录后有效；未输出 token 内容 |
| 完整类目 | test 1475 条（6 位 623、8 位 558）；UAT 1445 条（6 位 626、8 位 562） |
| 具体物料 | `15010112 螺纹钢`：test 83 条、UAT 48 条；首条均为 `150101120001` |
| prod 防护 | `environment=prod` 返回 HTTP 400：“环境只能是 test 或 uat” |
| 浏览器验收 | Firefox 1920×1080；树搜索后只保留 4 节祖先链；test/UAT 切换、物料页、差异页均正常 |
| 页面质量 | 控制台 0 error / 0 warning；文档宽度 1920 = 视口宽度 1920，无整页横向溢出 |

## 5. 真实接口选择

- 文档曾记录的 `/c/business/mdm/materialClassQuery/queryMaterialClassTreeFull`，本轮在 test/UAT 当前部署上实测均为 HTTP 404。
- 现有页面使用的 `/c/business/mdm/productClassQuery/queryProductClassTreeFull` 会按老产品要求主动砍掉 6/8 位节点。
- 本工具因此使用已部署且实测可用的 `/c/business/mdm/productClassQuery/queryProductClassPage`，一次拿平铺数据后本地组树；物料使用 `/c/business/mdm/productQuery/queryProductPageList`。

## 6. 风险与边界

- test 里 `1501` 当前名称是脏数据“黑色金属814”，工具按接口原样展示；UAT 是正常“黑色金属”。这不是前端拼错。
- 类目数据缓存 5 分钟，点“刷新数据”会绕过缓存重新查。
- Vite 构建提示主 JS 约 1.04 MB（gzip 约 330 KB）；这是 Ant Design 本地工具的首屏体积提示，不影响内网本地使用，后续需要公网部署时再做按页拆包。
- npm 安全审计请求受当前 npm 网络长时间无响应，本轮中止；依赖安装、锁文件和全部构建测试正常。网络稳定后可补跑 `npm audit`。
- 本工具只读且不支持 prod，不代替正式集采台账维护页面。
