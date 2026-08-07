# 自动登录获取 Token · 工具接口文档

> 日期：2026-08-04
> 工具：codex
> 当前状态：命令接口已实现并通过 test/UAT 真实验证。
> 下一阶段：其他 AI 直接照本文调用，不要自行读取或打印 token 缓存。

## 1. 登录管理命令

| 功能 | 命令 | 输出 |
|---|---|---|
| 全量体检 | `bash scripts/auth.sh doctor` | 四种组合是否配置、缓存是否有效；不显示秘密 |
| 查单项状态 | `bash scripts/auth.sh status test admin` | 账号/网关/缓存状态 |
| 强制重新登录 | `bash scripts/auth.sh login uat supplier` | 成功提示；token 只写缓存，不输出 |

环境只允许 `test|uat`，账号只允许 `admin|supplier`。prod 当前会明确拒绝。

## 2. 业务 API 命令

```bash
bash scripts/api.sh [--env test|uat] \
  [--platform procurement|cloud] \
  [--account admin|supplier] \
  METHOD /接口路径 ['JSON请求体']
```

默认值：`--env test --platform procurement --account admin`。

平台也支持短别名：`zc` = procurement（招采），`yc` = cloud（云采）。

## 3. 可直接复制的安全示例

```bash
# 旧命令兼容：test 招采管理员
bash scripts/api.sh GET '/c/business/ubm/memberCore/getLoginSuccUrl'

# UAT 云采管理员
bash scripts/api.sh --env uat --platform cloud --account admin \
  GET '/c/business/ubm/memberCore/getLoginSuccUrl'

# test 招采供应商
bash scripts/api.sh --env test --platform procurement --account supplier \
  GET '/c/business/ubm/memberCore/getLoginSuccUrl'

# 正常 POST 业务请求
bash scripts/api.sh --env test --platform cloud --account admin \
  POST '/e/business/source/xxx' '{"example":"value"}'
```

## 4. 自动行为

1. 优先复用对应 `环境 + 账号` 的有效缓存；招采/云采共享它。
2. 无有效缓存时调用 `authUnity` 登录。
3. 遇到 HTTP 401、`900301`、`ERROR_JWT_INVALIDITY`、`ERROR_JWT_401` 时强制登录并重试一次。
4. 第二次响应不再重试，原样输出，方便定位“权限问题”而不是误判 token。
5. 多个 AI 同时刷新时由文件锁合并为一次登录。

## 5. 禁止事项

- 不运行 `cat ai-docs/creds.env` 或 `cat ai-docs/.auth-cache/*.json`。
- 不用 `bash -x scripts/auth.sh`、`bash -x scripts/api.sh`。
- 不把 token 拼进命令、文档、Postman 集合或 Git 提交。
- 不绕过 prod 拦截直接拼生产 URL。
