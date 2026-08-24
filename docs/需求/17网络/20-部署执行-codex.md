# Cloudflare 家庭私网接入 · 部署执行记录

> 日期：2026-08-22  
> 工具：codex  
> 当前状态：部署进行中；本机 `cloudflared` 程序已安装但未注册服务，Cloudflare与路由器最终提交等待动作前确认。  
> 下一步：确认后创建 `home-lan`、安装 Connector服务、添加 CIDR Route、设置注册权限与最小 Split Tunnel，并逐层回读验证。

## 1. 执行边界

- 依据：`10-拆解规划-codex.md`、`10c-Mac与家庭网络现状侦察-codex.md`、`10d-Cloudflare现状与配置定稿-codex.md`。
- 禁改：旧 `saturate` Tunnel、现有 DNS/VLESS/Clash/Tailscale/ToDesk、两个 VPS。
- 凭据：Tunnel Token、Cookie、密码、MFA、SSH私钥不写入本文、聊天或项目文件。

## 2. 已执行

### 2.1 安装 cloudflared 程序

执行：

```bash
brew install cloudflared
```

结果：

- 安装成功：`cloudflared version 2026.8.2`。
- 安装位置由 Homebrew 管理：`/opt/homebrew/Cellar/cloudflared/2026.8.2`。
- `brew services list` 显示 `cloudflared none`：尚未启动，也没有开机服务。
- 本步骤未取得或使用 Tunnel Token，未建立任何 Cloudflare连接。

## 3. Cloudflare页面准备状态

- Chrome已登录正确账号。
- 新 Tunnel向导已选择 `Cloudflared`，名称已填 `home-lan`。
- 尚未点击 `Save tunnel`，因此尚未创建对象、未生成 Connector Token。
- 旧 `saturate` 仍为 Healthy；没有执行迁移或修改。

## 4. 待执行

1. 保存 `home-lan` 并把新生成的 Connector直接注册为 Mac系统服务；Token不落盘到项目和文档。
2. 等 Dashboard显示 Connector Healthy后，新增 `192.168.5.0/24` → `home-lan` → `default`。
3. 创建仅允许当前用户邮箱通过 One-time PIN注册的 Enrollment策略。
4. Default Profile改为 Traffic only + Include；只加入家庭 CIDR与官方 Team Domain两个地址。
5. 路由器新增 Mac Wi-Fi设备 → `192.168.5.35` 的静态 DHCP绑定。
6. 验证旧 Tunnel无变化、Connector健康、本地 SSH/HA/路由器仍可用。

## 5. 当前可回退项

当前唯一实际变更是安装了 Homebrew formula；如本需求终止，可在确认不再需要后执行：

```bash
brew uninstall cloudflared
```

当前没有 Cloudflare对象、Route、系统服务或路由器绑定需要回退。
