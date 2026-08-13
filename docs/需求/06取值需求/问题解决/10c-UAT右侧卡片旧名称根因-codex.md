# UAT 右侧卡片仍显示旧名称 · 根因调查

> 日期：2026-08-12  
> 工具：codex  
> 当前状态：根因已证实；UAT 后端和 Git 代码正确，但 UAT 实际提供的 hpc 静态资源仍是部署前旧包。  
> 下一步：用户重新执行一次指定参数的 UAT 前端构建，完成后再由 AI 只读核对静态资源和页面。

## 结论

**不是字典没生效，也不是右侧卡片代码没合入 UAT，而是 UAT 当前实际运行的 hpc 前端静态包没有更新。**

同一页出现差异的原因是：

- 左侧“二级集团集采率排名”原本就直接展示后端接口的 `group.name`，所以后端部署后立即显示字典值“冀东发展”。
- 右侧金额卡当前服务器仍在运行旧前端包，旧包内还有 `groupMeta`，把 `BU004` 写死为“冀东发展集团”。

## 直接证据

### 1. UAT 后端已生效

实调 UAT：

`POST /e/business/source/centralizedProcurementPortal/overview`

返回：

```json
{"buCode":"BU004","name":"冀东发展","amount":3.43,"rate":0.98}
```

UAT 应用日志同时记录：

```text
[集采门户首页] 板块字典(Owningplate)加载数量: 12
```

因此后端已经按字典返回“冀东发展”。

### 2. UAT Git 分支里的前端代码正确

- `scm-vue-hpc origin/uat@734ef7a` 于 2026-08-12 11:26 合入本次 UAT 分支。
- `origin/uat` 中的 `OfficeTransaction.vue` 已删除 `groupMeta`，右侧卡片使用 `name: group.name || group.buCode`。

因此不是漏合前端代码。

### 3. UAT 服务器仍提供旧 JS

UAT 页面入口实际加载：

`/hpc/js/chunk-76ff5fd3.6b120b5a.js`

该 JS 内仍存在旧代码：

```text
groupMeta: [..., {buCode:"BU004", name:"冀东发展集团"}, ...]
```

同时，该 JS 和 `/hpc/index.html` 的 HTTP 响应均显示：

```text
Last-Modified: Tue, 11 Aug 2026 03:14:16 GMT
```

换算北京时间是 **2026-08-11 11:14:16**，早于今天 11:26 的前端 MR 合入时间。因此今天的正确前端代码不可能已经进入这份静态资源。

### 4. 为什么“静态站 Pod 已更新”仍然是旧页面

UAT `scm-statics-web` Pod 今天确实换成了新镜像，但这是所有前端共用的静态站。任意一个前端项目构建都可能产生新镜像并滚动 Pod；**Pod 新只能证明静态站被发布过，不能证明本次发布的 `PROJECT` 是 hpc。**

目前无法读取 Jenkins 精确构建参数：Jenkins 只读浏览器桥接暂时不可用。因此“当时具体选了哪个 PROJECT”尚未直接取证；但“hpc 文件没有更新”已由服务器实际静态资源完全证实。

## 处理步骤

用户在 Jenkins 重新执行：

| 参数 | 值 |
|---|---|
| 任务 | `scm-vue-statics-uat` |
| `PROJECT` | `hpc` |
| `GIT_BRANCH` | `uat` |

构建完成后先不要只看 Pod 或 Jenkins 绿灯，应核对：

1. `/hpc/index.html` 的 `Last-Modified` 更新为本次构建时间。
2. 页面加载的业务 chunk 文件名发生变化。
3. 新 chunk 中不再包含 `groupMeta` 和写死的 `BU004 → 冀东发展集团`。
4. 再用 `Ctrl+F5` 强制刷新页面，右侧金额卡应显示“冀东发展”。

本次不需要再改代码、不需要重启 source 后端、不需要改字典或重跑 ES 数据。
