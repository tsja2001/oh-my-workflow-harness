# KiwiVM 分步短脚本

> 日期：2026-08-25  
> 工具：codex  
> 当前状态：本文取代 `20b-KVM脚本执行准备-codex.md` 和 `20c-KiwiVM单命令脚本投递-codex.md` 的投递方式；原因是 Interactive 长粘贴和 Base64 文件均未可靠执行。  
> 下一步：严格按 01、02、03 顺序执行，成功后把 03 的脱敏输出交给 Codex。

## 使用方法

每一步都按相同方式操作：

1. 在 KiwiVM `Root shell - advanced` 新建下表中的“VPS 文件”。
2. 复制对应工作区脚本的全部内容并保存。
3. 回到 `Root shell - interactive`，执行表中的一条短命令。

| 顺序 | 工作区脚本 | VPS 文件 | Interactive 命令 |
|---|---|---|---|
| 1 | `01-precheck.sh` | `/root/01-precheck.sh` | `bash /root/01-precheck.sh` |
| 2 | `02-prepare-service.sh` | `/root/02-prepare-service.sh` | `bash /root/02-prepare-service.sh` |
| 3 | `03-token-and-start.template.sh` | `/root/03-token-and-start.sh` | `bash /root/03-token-and-start.sh` |
| 4 | `04-status.sh` | `/root/04-status.sh` | `bash /root/04-status.sh` |
| 5 | `05-rollback.sh` | `/root/05-rollback.sh` | 仅收到回退指示时执行 `bash /root/05-rollback.sh` |

## Token 步骤

只在 KiwiVM Advanced 中，把 03 脚本的：

```text
__PASTE_FULL_EYJ_TOKEN_HERE__
```

替换成完整 `eyJ...` Token。不要把填好 Token 的脚本保存回工作区或发到聊天。

`03-token-and-start.sh` 成功写入限权 Token 文件后会删除自身，避免 Token 长期留在 VPS 脚本文件中。KiwiVM 任务历史仍可能保留提交内容；安全优先时应改用 Interactive 隐藏输入，但本目录按用户明确要求提供 Advanced 占位符方式。

## 成功标志

- 01：`PRECHECK_OK`
- 02：`PREPARE_OK`
- 03：`ActiveState=active`、`SubState=running`、`CONNECTOR_INSTALL_OK`
- 04：用于重复只读检查
- 05：`ROLLBACK_OK`

