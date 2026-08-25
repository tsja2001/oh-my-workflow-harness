# 洛杉矶 VPS SSH · Cloudflare 与搬瓦工 KVM 实施手册

> 日期：2026-08-25  
> 工具：codex  
> 当前状态：实施手册已完成；尚未登录搬瓦工、未创建 Cloudflare 对象，也未改 VPS/SSH/Clash/DNS。  
> 下一步：用户从本文“第 1 步”开始，每一步回读成功再继续；遇到与文档不同的页面、命令报错或旧服务异常立即停止。

## 0. 最终要得到什么

```text
Windows / WSL：ssh la-vps-access
  → Windows cloudflared.exe
  → Cloudflare Access（仅本人）
  → ssh-vps.tttthappy1111.org
  → 新 Tunnel：la-vps-admin
  → VPS 上新的独立 systemd 服务
  → localhost:22
  → 现有 SSH 密钥认证
```

新旧对照：

| 对象 | 回家方案中已有 | 本次 VPS 新建 | 要求 |
|---|---|---|---|
| Tunnel | `home-lan` | `la-vps-admin` | 两者独立 |
| Access 应用 | `home-mac-ssh` | `la-vps-ssh` | 两者独立 |
| SSH 域名 | `ssh-home.tttthappy1111.org` | `ssh-vps.tttthappy1111.org` | 不复用旧域名 |
| 源站 | Mac `localhost:22` | VPS `localhost:22` | 只发布 SSH |
| 旧 Clash/CDN | `saturate` + `cdn.tttthappy1111.org` | **不新建、不修改** | 绝不迁移/重启 |

### 为什么不执行 Cloudflare 页面给的默认命令

Cloudflare 向导通常会给出：

```text
sudo cloudflared service install <TUNNEL_TOKEN>
```

**本 VPS 上不能直接运行这条。** 旧 `saturate` 很可能已经使用默认 `cloudflared.service`；再安装会同名冲突或覆盖旧服务。本文会改用：

- 独立程序副本：`/usr/local/lib/cloudflared-la-vps/cloudflared`；
- 独立 Token 文件：`/etc/cloudflared-la-vps-admin/token`；
- 独立服务：`cloudflared-la-vps-admin.service`；
- 官方支持的 `--token-file`，不把 Token 显示在进程参数中。

## 1. 先在 Cloudflare 网页确认进对了账号

登录 Cloudflare Dashboard，进入之前配置回家方案的同一个 Zero Trust 组织和 `tttthappy1111.org` Zone。

你应该能看到之前的记录：

1. `Zero Trust → Access controls → Applications`：有 `home-mac-ssh`。
2. `Zero Trust → Networking → Tunnels`：有 `home-lan`，正常时为 `Healthy`。
3. 打开 `home-lan → Routes`：有 `ssh-home.tttthappy1111.org → ssh://localhost:22`。
4. 普通 `DNS → Records`：有由 Tunnel 自动管理的 `ssh-home`。
5. Tunnel 列表还可能看到旧 `saturate`；只看状态，**不打开迁移、不点 Start migration、不改 Routes**。

如果看不到 `home-lan` 和 `home-mac-ssh`，说明进错了 Cloudflare 账号、Zone 或 Zero Trust 组织；到此停止，不在新账号里重复创建。

再在 DNS 页搜索 `ssh-vps`：

- 预期：没有记录；
- 如果已有同名记录：停止，先查清它的用途，不覆盖。

## 2. Cloudflare 第一步：先建 Access 保护

必须先建 Access 应用，再发布 Tunnel 路由，避免主机名先发布、身份保护后补上。

页面路径：

```text
Zero Trust
→ Access controls
→ Applications
→ Add an application
→ Self-hosted
```

> 部分新界面显示为 `Self-hosted and private`，语义相同。

应用填写：

| 字段 | 填写值 |
|---|---|
| Application name | `la-vps-ssh` |
| Session duration | `8 hours`；如只有预设值，选不超过 `24 hours` 且能覆盖一个工作时段的最短值 |
| Public hostname / Application domain | `ssh-vps.tttthappy1111.org` |
| Path | 留空 |
| Browser rendering | Off |
| App Launcher visibility | 可关闭；不影响 OpenSSH |

新增并关联策略：

| 字段 | 填写值 |
|---|---|
| Policy name | `allow-la-vps-owner-only` |
| Action | `Allow` |
| Include selector | `Emails` |
| Value | 你当前的 Cloudflare 登录邮箱；不发给 AI、不写进文档 |

不要选：

- `Everyone`；
- `Bypass`；
- `Service Auth` / Service Token；
- 任意邮箱域名通配。

如果你已在 Cloudflare Independent MFA 中注册了 TOTP、Windows Hello 或安全密钥，可在该应用的 `Authentication → MFA` 启用。如果尚未注册，先不强制，等基本 SSH 通路成功后按第 10 节再开，避免首次就锁住自己。

保存后重新打开 `la-vps-ssh`，确认主机名和 owner-only 策略仍在。

## 3. Cloudflare 第二步：创建独立 Tunnel，暂不执行安装命令

页面路径：

```text
Zero Trust
→ Networking
→ Tunnels
→ Create a tunnel
→ Cloudflared
```

填写：

| 字段 | 填写值 |
|---|---|
| Tunnel name | `la-vps-admin` |
| Environment | Linux |
| Architecture | 暂按 KVM 第 5.1 节 `uname -m` 结果选；大概率为 64-bit AMD/Intel |

点 `Create tunnel` 后页面会给带 Token 的安装命令。

- 保留这个页面；
- 不把 Token 发到聊天或文档；
- **不执行 `cloudflared service install`**；
- 不先添加 Published application；
- 切到搬瓦工 KVM 执行下一节。

## 4. 打开搬瓦工 KiwiVM/KVM 控制台

1. 登录 BandwagonHost 客户中心。
2. 进入这台 VPS 的 KiwiVM Control Panel。
3. 确认 VPS 状态为 `Running`。
4. 如套餐有 Snapshot 且当前有可用名额，先建一个动作前快照；不覆盖已知可用的恢复点。
5. 打开 `Interactive Console`；不同版本可能放在 `Root shell → Interactive` 或 `Emergency Console`。
6. 使用 VPS 自身的 root 账号登录。密码只输入 KVM，不发给 AI。
7. KVM/noVNC 如有 Clipboard 侧栏，通过它粘贴命令；一次只粘贴本文一个代码块。

不要点：

- OS reinstall；
- Mount ISO；
- Force stop；
- Reset root password（除非你确实已无法登录）。

在新 Access SSH 完成外部重连以前，**不要关闭 KVM 窗口**。

## 5. KVM Bash：只读盘点和备份

### 5.1 只读现状

粘贴：

```bash
bash <<'BASH'
set -eu

echo '=== basic ==='
date -Is
id
uname -m
if [ -r /etc/os-release ]; then
  . /etc/os-release
  printf 'os=%s version=%s\n' "${ID:-unknown}" "${VERSION_ID:-unknown}"
fi
command -v systemctl >/dev/null || { echo 'STOP: systemd not found'; exit 1; }

echo '=== cloudflared binary ==='
if command -v cloudflared >/dev/null 2>&1; then
  command -v cloudflared
  cloudflared --version
else
  echo 'cloudflared not found in PATH'
fi

echo '=== cloudflared services ==='
systemctl list-unit-files --type=service --no-legend 2>/dev/null \
  | awk 'tolower($1) ~ /cloudflared/ {print $1, $2}' || true
systemctl list-units --all --type=service --no-legend 2>/dev/null \
  | awk 'tolower($1) ~ /cloudflared/ {print $1, $3, $4}' || true

echo '=== cloudflared processes, token redacted ==='
ps -eo pid,etimes,args \
  | grep '[c]loudflared' \
  | sed -E 's/(--token(=|[[:space:]]+))[^[:space:]]+/\1[TOKEN-REDACTED]/g; s/eyJ[A-Za-z0-9._=-]+/[TOKEN-REDACTED]/g' \
  || true

echo '=== ssh effective settings ==='
SSHD_BIN=$(command -v sshd || true)
[ -n "$SSHD_BIN" ] || { echo 'STOP: sshd not found'; exit 1; }
"$SSHD_BIN" -T \
  | awk '$1 ~ /^(port|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitrootlogin)$/ {print}'

echo '=== ssh listeners ==='
ss -lntp 2>/dev/null | awk 'NR == 1 || /:22[[:space:]]/'
BASH
```

停止条件：

- 不是 root；
- 没有 systemd；
- `sshd` 不存在或实际端口不是 22；
- Cloudflare 页面上旧 `saturate` 不是 Healthy，或 VPS 内找不到对应的旧 cloudflared 进程/容器；
- 输出显示的旧结构与本文预期明显不同。

不要把完整服务配置、Token、UUID 或私钥粘贴到聊天。需要 AI 判断时，只提供上面已脱敏的输出。

### 5.2 备份现有 cloudflared 和 SSH 配置

只有 5.1 无异常才粘贴：

```bash
bash <<'BASH'
set -eu
BACKUP_DIR="/root/la-vps-admin-backup-$(date +%Y%m%d-%H%M%S)"
install -d -m 700 "$BACKUP_DIR"

for ITEM in /etc/cloudflared /root/.cloudflared /etc/ssh; do
  if [ -e "$ITEM" ]; then
    cp -a --parents "$ITEM" "$BACKUP_DIR"
  fi
done

for BASE in /etc/systemd/system /usr/lib/systemd/system /lib/systemd/system; do
  [ -d "$BASE" ] || continue
  while IFS= read -r UNIT_FILE; do
    cp -a --parents "$UNIT_FILE" "$BACKUP_DIR"
  done < <(find "$BASE" -maxdepth 2 -type f -iname '*cloudflared*.service' -print)
done

systemctl list-unit-files --type=service --no-legend \
  | awk 'tolower($1) ~ /cloudflared/ {print $1, $2}' \
  > "$BACKUP_DIR/cloudflared-units-before.txt" || true
systemctl list-units --all --type=service --no-legend \
  | awk 'tolower($1) ~ /cloudflared/ {print $1, $3, $4}' \
  > "$BACKUP_DIR/cloudflared-state-before.txt" || true
ss -lntp > "$BACKUP_DIR/listeners-before.txt" 2>/dev/null || true

chmod -R go-rwx "$BACKUP_DIR"
printf '%s\n' "$BACKUP_DIR" > /root/la-vps-admin-last-backup.txt
chmod 600 /root/la-vps-admin-last-backup.txt
printf 'backup=%s\n' "$BACKUP_DIR"
BASH
```

必须看到一个明确的 `backup=/root/la-vps-admin-backup-...` 路径才继续。备份中可能含旧 Tunnel 凭据，所以它仅保存在 VPS `/root`，不下载、不进 Git、不发到聊天。

## 6. KVM Bash：安装独立 cloudflared 副本

这段优先复制 VPS 已有且支持 `--token-file` 的 cloudflared，不修改旧程序；只有旧版太老或不存在时，才从 Cloudflare 官方 GitHub Release 下载一份独立二进制。

```bash
bash <<'BASH'
set -eu
TARGET_DIR=/usr/local/lib/cloudflared-la-vps
TARGET_BIN="$TARGET_DIR/cloudflared"
install -d -m 755 "$TARGET_DIR"

SOURCE_BIN=$(command -v cloudflared || true)
if [ -n "$SOURCE_BIN" ] && "$SOURCE_BIN" tunnel run --help 2>&1 | grep -q -- '--token-file'; then
  echo "copying existing supported binary: $SOURCE_BIN"
  install -m 0755 "$SOURCE_BIN" "$TARGET_BIN"
else
  command -v curl >/dev/null 2>&1 || { echo 'STOP: curl not installed'; exit 1; }
  case "$(uname -m)" in
    x86_64|amd64) CF_ARCH=amd64 ;;
    aarch64|arm64) CF_ARCH=arm64 ;;
    *) echo "STOP: unsupported architecture $(uname -m)"; exit 1 ;;
  esac
  TEMP_DIR=$(mktemp -d /tmp/cloudflared-la-vps.XXXXXX)
  trap 'rm -rf "$TEMP_DIR"' EXIT
  curl --fail --location --retry 3 \
    --output "$TEMP_DIR/cloudflared" \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}"
  install -m 0755 "$TEMP_DIR/cloudflared" "$TARGET_BIN"
fi

"$TARGET_BIN" --version
"$TARGET_BIN" tunnel run --help 2>&1 | grep -q -- '--token-file' \
  || { echo 'STOP: target binary lacks --token-file'; exit 1; }
sha256sum "$TARGET_BIN"
BASH
```

成功标准：打印 cloudflared 版本和 SHA-256，最后没有 `STOP`。本步没有启动进程，旧 Tunnel 不应受影响。

## 7. KVM Bash：隐藏输入 Token，创建独立 systemd 服务

### 7.1 从 Cloudflare 页面取 Token

回到第 3 节保留的 `la-vps-admin` Tunnel 页面。如页面已关：

```text
Networking → Tunnels → la-vps-admin → Add a replica
```

页面安装命令最后有一段很长的、通常以 `eyJ` 开头的 Tunnel Token。只把这一段放入 KVM/noVNC 剪贴板；不在聊天中转发。

### 7.2 将 Token 写入限权文件

粘贴下面代码块后，终端会显示 `Paste Tunnel Token` 提示。此时再通过 KVM 剪贴板粘贴 Token 并按回车；**屏幕不会回显 Token**。

```bash
bash <<'BASH'
set -eu
SERVICE_USER=cloudflared-la-vps
SERVICE_GROUP=cloudflared-la-vps
TOKEN_DIR=/etc/cloudflared-la-vps-admin
TOKEN_FILE="$TOKEN_DIR/token"

if ! getent group "$SERVICE_GROUP" >/dev/null; then
  groupadd --system "$SERVICE_GROUP"
fi
if ! id "$SERVICE_USER" >/dev/null 2>&1; then
  NOLOGIN_SHELL=$(command -v nologin || printf '/usr/sbin/nologin')
  useradd --system --gid "$SERVICE_GROUP" --home-dir /nonexistent \
    --shell "$NOLOGIN_SHELL" "$SERVICE_USER"
fi

install -d -m 0750 -o root -g "$SERVICE_GROUP" "$TOKEN_DIR"
umask 077
read -r -s -p 'Paste Tunnel Token, then press Enter: ' CF_TUNNEL_TOKEN < /dev/tty
printf '\n'
case "$CF_TUNNEL_TOKEN" in
  eyJ*) ;;
  *) unset CF_TUNNEL_TOKEN; echo 'STOP: token format unexpected'; exit 1 ;;
esac
printf '%s\n' "$CF_TUNNEL_TOKEN" > "$TOKEN_FILE"
unset CF_TUNNEL_TOKEN
chown root:"$SERVICE_GROUP" "$TOKEN_FILE"
chmod 0640 "$TOKEN_FILE"
printf 'token_file=%s bytes=%s mode=%s owner=%s\n' \
  "$TOKEN_FILE" \
  "$(wc -c < "$TOKEN_FILE")" \
  "$(stat -c '%a' "$TOKEN_FILE")" \
  "$(stat -c '%U:%G' "$TOKEN_FILE")"
BASH
```

成功回读应是：

- 路径 `/etc/cloudflared-la-vps-admin/token`；
- 权限 `640`；
- 所有者 `root:cloudflared-la-vps`；
- 只显示字节数，不显示 Token 内容。

### 7.3 写入并启动新服务

```bash
bash <<'BASH'
set -eu
UNIT=/etc/systemd/system/cloudflared-la-vps-admin.service
[ ! -e "$UNIT" ] || { echo "STOP: $UNIT already exists"; exit 1; }

tee "$UNIT" >/dev/null <<'UNITFILE'
[Unit]
Description=Cloudflare Tunnel - LA VPS Admin SSH
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
User=cloudflared-la-vps
Group=cloudflared-la-vps
ExecStart=/usr/local/lib/cloudflared-la-vps/cloudflared tunnel --no-autoupdate --loglevel info run --token-file /etc/cloudflared-la-vps-admin/token
Restart=on-failure
RestartSec=5s
TimeoutStartSec=0
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true

[Install]
WantedBy=multi-user.target
UNITFILE

chmod 0644 "$UNIT"
systemd-analyze verify "$UNIT"
systemctl daemon-reload
systemctl enable --now cloudflared-la-vps-admin.service
sleep 5

if ! systemctl is-active --quiet cloudflared-la-vps-admin.service; then
  echo 'STOP: new service failed; old service was not changed'
  systemctl disable --now cloudflared-la-vps-admin.service 2>/dev/null || true
  journalctl -u cloudflared-la-vps-admin.service -n 80 --no-pager \
    | sed -E 's/(--token(=|[[:space:]]+))[^[:space:]]+/\1[TOKEN-REDACTED]/g; s/eyJ[A-Za-z0-9._=-]+/[TOKEN-REDACTED]/g'
  exit 1
fi

systemctl show cloudflared-la-vps-admin.service \
  -p ActiveState -p SubState -p MainPID -p FragmentPath
journalctl -u cloudflared-la-vps-admin.service -n 40 --no-pager \
  | sed -E 's/(--token(=|[[:space:]]+))[^[:space:]]+/\1[TOKEN-REDACTED]/g; s/eyJ[A-Za-z0-9._=-]+/[TOKEN-REDACTED]/g'

echo '=== all cloudflared units after ==='
systemctl list-units --all --type=service --no-legend \
  | awk 'tolower($1) ~ /cloudflared/ {print $1, $3, $4}'
BASH
```

成功标准：

1. `cloudflared-la-vps-admin.service` 为 `active/running`。
2. Cloudflare 页面上 `la-vps-admin` 出现 Connected Connector，Tunnel 为 `Healthy`。
3. 旧 cloudflared/`saturate` 对应服务仍是执行前的 active 状态。
4. 本步没有重启、停止或改写旧服务。

只有这四项都满足才继续。

## 8. Cloudflare 第三步：发布 VPS SSH

回到：

```text
Zero Trust
→ Networking
→ Tunnels
→ la-vps-admin
→ Routes
→ Add route
→ Published application
```

填写：

| 字段 | 填写值 |
|---|---|
| Subdomain | `ssh-vps` |
| Domain | `tttthappy1111.org` |
| Path | 留空 |
| Service type | `SSH` |
| Service URL / URL | `localhost:22` |
| Origin advanced settings | 保持默认 |

如页面询问是否自动创建 Access 保护，不要再创建第二个应用；本文第 2 节的 `la-vps-ssh` 已经保护同一精确主机名。

保存后回查：

1. `la-vps-admin` 仍为 `Healthy`。
2. Routes 显示 `ssh-vps.tttthappy1111.org → ssh://localhost:22`。
3. `Access controls → Applications` 只有一个本次应用 `la-vps-ssh`，策略为 owner-only。
4. 普通 DNS 页自动出现 `ssh-vps`，类型可显示为 `Tunnel` 或 Proxied CNAME，指向 `la-vps-admin`。
5. `home-lan`、`home-mac-ssh`、`ssh-home`、`saturate`、`cdn` 都没有变。

如果 DNS 没有自动出现，停止并记录页面报错；不手工猜 Tunnel UUID 建 CNAME。

## 9. Windows 客户端：新增 `la-vps-access`

已核实现有 Windows 环境：

- `cloudflared.exe`：`C:\Users\29455\AppData\Local\Programs\cloudflared\cloudflared.exe`；
- 现有 VPS 别名：`LA-ipv4`；
- 现有私钥引用：`C:\Users\29455\.ssh\thinkpad-t14-windows_ed25519`；
- 现有登录用户：`root`。

首次建通时不同时改 Linux 用户和密钥，避免把“Tunnel 问题”和“SSH 授权问题”混在一起。建通后再分开迁移普通管理用户。

在 Windows PowerShell 执行：

```powershell
$sshConfig = "$env:USERPROFILE\.ssh\config"
$backup = "$sshConfig.bak-la-vps-access-$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $sshConfig -Destination $backup

if (Select-String -LiteralPath $sshConfig -SimpleMatch 'Host la-vps-access' -Quiet) {
    throw 'STOP: la-vps-access already exists; do not append a duplicate block'
}

if (-not (ssh-keygen.exe -F 64.64.252.58 -f "$env:USERPROFILE\.ssh\known_hosts" 2>$null)) {
    throw 'STOP: 现有VPS主机指纹未在known_hosts中，不能盲目accept-new'
}

@'

# BEGIN la-vps-cloudflare-access-ssh
Host la-vps-access
    HostName ssh-vps.tttthappy1111.org
    User root
    Port 22
    ProxyCommand C:\Users\29455\AppData\Local\Programs\cloudflared\cloudflared.exe access ssh --hostname %h
    IdentityFile C:\Users\29455\.ssh\thinkpad-t14-windows_ed25519
    IdentitiesOnly yes
    HostKeyAlias 64.64.252.58
    StrictHostKeyChecking yes
    ConnectTimeout 20
    ServerAliveInterval 30
    ServerAliveCountMax 3
# END la-vps-cloudflare-access-ssh
'@ | Add-Content -LiteralPath $sshConfig

ssh.exe -G la-vps-access | Select-String 'hostname|user |proxycommand|identityfile|hostkeyalias|stricthostkeychecking'
Write-Host "backup=$backup"
```

这只备份并追加 SSH 别名，不会主动联网。

### 9.1 首次连接

保持 KVM 窗口打开，另开 Windows PowerShell：

```powershell
ssh la-vps-access 'hostname; id -un'
```

预期：

1. `cloudflared` 打开 Cloudflare Access 登录页。
2. 你本人完成登录/OTP/MFA；不让 AI 输入。
3. Access 通过后，OpenSSH 使用现有私钥。
4. `HostKeyAlias` 强制复用现有 VPS IPv4 主机指纹；指纹不一致时必须停止，不删 `known_hosts`。
5. 返回 VPS 主机名和 `root`。

然后连续三次：

```powershell
1..3 | ForEach-Object { ssh la-vps-access 'printf "access-ok\n"' }
```

WSL 暂时可以直接复用 Windows SSH，不再复制一份私钥：

```bash
/mnt/c/Windows/System32/OpenSSH/ssh.exe la-vps-access 'hostname; id -un'
```

## 10. 完整验收后再做安全收口

### 10.1 先验收，暂不关公网 SSH

必须全部满足：

- `la-vps-admin` Healthy；
- `saturate` 和旧 cloudflared 状态与执行前一致；
- Windows 首次 Access 登录成功；
- 现有 SSH 主机指纹精确匹配；
- 三次独立 `ssh la-vps-access` 成功；
- 新建连接时 KVM 仍能登录；
- 手动选一次 `Daily-CDN-WS` 做真实网页访问，不能只看节点 delay；
- 日常 `Daily-Reality-443` 仍正常。

未满足时保留旧 IPv4 SSH，不进入下一节。

### 10.2 启用 Access MFA

在 Cloudflare Zero Trust 先注册你自己的 TOTP、Windows Hello 或安全密钥，再进入：

```text
Access controls → Applications → la-vps-ssh → Authentication → MFA
```

选 `Custom MFA settings`，只选你已经注册并实测过的方式。保存后用无痕窗口新建一次 `ssh la-vps-access`，确认 MFA 真正被要求，不用旧会话冒充验收。

### 10.3 最终让 sshd 只监听回环地址

这比猜 ufw/nftables/iptables 现有规则更稳：Cloudflare Connector 仍可访问 `localhost:22`，而 IPv4/IPv6 公网都不再有 SSH 监听。

执行前条件：

- KVM 保持打开；
- 新 Access SSH 已连续三次成功；
- `/root/la-vps-admin-last-backup.txt` 指向的备份存在；
- 执行时不同时改防火墙、端口和 Linux 用户。

在 KVM 粘贴：

```bash
bash <<'BASH'
set -eu
DROPIN_DIR=/etc/ssh/sshd_config.d
DROPIN="$DROPIN_DIR/90-cloudflare-local-only.conf"
BACKUP_DIR=$(cat /root/la-vps-admin-last-backup.txt)
[ -d "$BACKUP_DIR" ] || { echo 'STOP: backup directory missing'; exit 1; }
[ ! -e "$DROPIN" ] || { echo "STOP: $DROPIN already exists"; exit 1; }

grep -Eq '^[[:space:]]*Include[[:space:]]+.+/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config \
  || { echo 'STOP: sshd_config does not include drop-in directory'; exit 1; }

EXISTING_LISTEN=$(grep -RinE '^[[:space:]]*ListenAddress[[:space:]]+' \
  /etc/ssh/sshd_config "$DROPIN_DIR" 2>/dev/null || true)
[ -z "$EXISTING_LISTEN" ] \
  || { echo 'STOP: existing explicit ListenAddress found'; printf '%s\n' "$EXISTING_LISTEN"; exit 1; }

install -d -m 0755 "$DROPIN_DIR"
{
  echo 'ListenAddress 127.0.0.1'
  if [ -s /proc/net/if_inet6 ]; then
    echo 'ListenAddress ::1'
  fi
  echo 'PubkeyAuthentication yes'
  echo 'PasswordAuthentication no'
  echo 'KbdInteractiveAuthentication no'
  echo 'PermitEmptyPasswords no'
  echo 'PermitRootLogin prohibit-password'
} > "$DROPIN"
chmod 0644 "$DROPIN"

SSHD_BIN=$(command -v sshd)
if ! "$SSHD_BIN" -t; then
  mv "$DROPIN" "$BACKUP_DIR/"
  echo 'STOP: sshd validation failed; new drop-in moved back to backup'
  exit 1
fi

if systemctl cat ssh.service >/dev/null 2>&1; then
  systemctl reload ssh.service
else
  systemctl reload sshd.service
fi
sleep 3

echo '=== effective authentication ==='
"$SSHD_BIN" -T \
  | awk '$1 ~ /^(passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitrootlogin)$/ {print}'
echo '=== port 22 listeners ==='
ss -lntp | awk 'NR == 1 || /:22[[:space:]]/'
BASH
```

人工检查监听结果只允许：

```text
127.0.0.1:22
[::1]:22    # 开启 IPv6 时才有
```

不得再出现 `0.0.0.0:22`、`*:22`、`[::]:22` 或 VPS 公网地址 `:22`。如仍出现，不要加防火墙规则补救；先保留 KVM，把脱敏监听结果交给 AI 分析。

立即从新 Windows PowerShell 再测：

```powershell
ssh la-vps-access 'printf "private-ssh-ok\n"'
ssh LA-ipv4
```

预期：

- `la-vps-access` 成功；
- `LA-ipv4` 新建公网连接失败；
- 已建立的旧 SSH 会话可能暂时仍存活，不能用它代表公网 22 还开着。

## 11. 日常命令和检查

Windows：

```powershell
ssh la-vps-access
```

WSL 复用 Windows SSH：

```bash
/mnt/c/Windows/System32/OpenSSH/ssh.exe la-vps-access
```

KVM/SSH 内检查新 Connector：

```bash
systemctl status cloudflared-la-vps-admin.service --no-pager
journalctl -u cloudflared-la-vps-admin.service -n 80 --no-pager
```

不要在聊天中粘贴未脱敏的 `systemctl cat`、完整 Token 文件或带 Token 的 Dashboard 安装命令。

## 12. 回退

### 12.1 只回退公网 SSH 收口

如 `la-vps-access` 在收口后失败，在仍打开的 KVM 执行：

```bash
bash <<'BASH'
set -eu
DROPIN=/etc/ssh/sshd_config.d/90-cloudflare-local-only.conf
BACKUP_DIR=$(cat /root/la-vps-admin-last-backup.txt)
[ -f "$DROPIN" ] || { echo 'nothing to rollback'; exit 0; }
mv "$DROPIN" "$BACKUP_DIR/"
SSHD_BIN=$(command -v sshd)
"$SSHD_BIN" -t
if systemctl cat ssh.service >/dev/null 2>&1; then
  systemctl reload ssh.service
else
  systemctl reload sshd.service
fi
ss -lntp | awk 'NR == 1 || /:22[[:space:]]/'
BASH
```

预期公网 `LA-ipv4` 可再次新建 SSH 连接。

### 12.2 回退新 Tunnel，不碰旧 `saturate`

顺序：

1. 如已做 10.3，先按 12.1 恢复公网 SSH，并真实新连接 `LA-ipv4` 成功。
2. Cloudflare `la-vps-admin → Routes` 删除且只删除 `ssh-vps` Published application。
3. KVM 停止并禁用且只禁用新服务：

```bash
systemctl disable --now cloudflared-la-vps-admin.service
systemctl is-active cloudflared-la-vps-admin.service || true
```

4. Cloudflare 删除且只删除 `la-vps-ssh` Access 应用。
5. Cloudflare 删除且只删除 `la-vps-admin` Tunnel。
6. DNS 如残留 `ssh-vps`，只删这一条；不动 `ssh-home`、`cdn` 或其他记录。
7. Windows 用 PowerShell 备份恢复 SSH config，或只删 `BEGIN/END la-vps-cloudflare-access-ssh` 之间的新块。

新服务的 unit、Token 和独立二进制先保留现场，不急着删；确认旧 SSH 和 Clash/CDN 完整恢复后，再单独清理。

### 12.3 任何时候都禁止删除的对象

- `saturate` Tunnel；
- `cdn.tttthappy1111.org`；
- 旧 VLESS/Reality/CDN-WS 服务和配置；
- `home-lan`、家庭 CIDR Route、`home-mac-ssh`、`ssh-home`；
- 搬瓦工整台 VPS、OS 或现有 SSH 主机密钥。

## 13. 本次算成功的标准

| 层 | 成功证据 |
|---|---|
| Cloudflare Access | 无登录不能进；仅 owner-only；最终 MFA 从无痕/新会话实际触发 |
| Tunnel | `la-vps-admin` Healthy，新 Connector Connected |
| 源站 | Route 精确为 `ssh-vps → ssh://localhost:22` |
| SSH 身份 | 复用现有 VPS 主机指纹，现有密钥成功，不使用 `accept-new` |
| 稳定性 | 三次新建连接成功，无循环登录、立即重置或 Tunnel 掉线 |
| 公网暴露 | 最终 `sshd` 只监听 `127.0.0.1`/可选 `::1`，新 `LA-ipv4` SSH 失败 |
| 旧 Clash/CDN | `saturate` 状态未变；Reality 和 CDN-WS 都经真实请求可用 |
| 恢复 | KiwiVM KVM 可登录，`/root/la-vps-admin-last-backup.txt` 指向有效备份 |

`HTTP 200`、Tunnel Healthy、DNS 存在、节点 delay 正常或一次 SSH 成功都不足以单独宣布完成；必须以上表全链路共同满足。

## 14. 依据

工作区现有证据：

- `../回家方案/归档/2026-08-25-收口前完整资料/20j-B通道Cloudflare后台配置-codex.md`：之前 Access 应用、owner-only 策略、SSH Published application 和自动 DNS 的真实页面记录。
- `../回家方案/归档/2026-08-25-收口前完整资料/30e-B通道家庭端验收报告-codex.md`：Access、Tunnel、SSH 握手和主机指纹的验收证据。
- `/home/t/projects/personal/05clash/订阅备份/20-08-25同步服务器配置.yaml:52-89,118-119`：当前 Reality/CDN-WS 及自有域名/VPS 直连规则。
- Windows `C:\Users\29455\.ssh\config:22-27`：当前 `LA-ipv4`、root 和现有私钥引用；本文未读取私钥内容。

官方文档：

- [Cloudflare：从 Dashboard 创建远程管理 Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel/)。
- [Cloudflare：SSH with client-side cloudflared](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/ssh-cloudflared-authentication/)。
- [Cloudflare：`--token-file` 要求与运行参数](https://developers.cloudflare.com/tunnel/advanced/run-parameters/)。
- [Cloudflare：Tunnel Token 获取与旋转](https://developers.cloudflare.com/tunnel/advanced/tunnel-tokens/)。
- [Cloudflare：Independent MFA](https://developers.cloudflare.com/cloudflare-one/access-controls/access-settings/independent-mfa/)。
- [BandwagonHost：KiwiVM 提供 Emergency/Interactive Console 和 Snapshot](https://bandwagonhost.com/)。
- [BandwagonHost：SSH 不可达时使用 KiwiVM Interactive Console 排查](https://bandwagonhost.com/kb.php?action=displayarticle&id=26)。
