#!/bin/bash
# 一键本地跑 scm-source-web（连 test 的 Nacos 配置 / 库 / ES）。把本环境的启动坑封装掉。
# 跟 dbq.sh/esq.sh 一个风格：后续 AI 一句话起停，不用回忆参数。
#
# 用法：
#   bash scripts/srun.sh start        # 启动（★必须经 Bash 工具 run_in_background=true 调，见下方“铁律”）
#   bash scripts/srun.sh wait         # 前台轮询直到 Started/8110（最多 ~150s）
#   bash scripts/srun.sh status       # 在不在跑（端口 + Started 标记）
#   bash scripts/srun.sh logs [n]     # 看日志尾部 n 行（默认 40）
#   bash scripts/srun.sh stop         # 停掉本地实例
#   bash scripts/srun.sh build [模块]  # 改了某模块后：重装该模块到 .m2 + 重打 fat jar（默认 scm-source-chase）
#
# 典型闭环（改完 scm-source-chase 代码，想本地验证）：
#   1) bash scripts/srun.sh build                       # 前台跑，约 2 分钟
#   2) bash scripts/srun.sh start                       # ★用 Bash 工具 run_in_background=true 起
#   3) bash scripts/srun.sh wait                        # 前台等它起来
#   4) bash scripts/api.sh POST /e/business/source/... '{...}'   # 或 curl localhost:8110
#   5) bash scripts/srun.sh stop                        # 测完停掉（别长期挂着连 test）
#
# ★铁律（本环境实测，2026-08-03 cc）：
#   - start 用【前台 exec java】，靠调用方持有的 wsl.exe 进程保活。**不要**改成 `nohup java &`——
#     一次性 `wsl.exe -- bash 脚本` 里后台起的 java，wsl.exe 一返回就被 WSL 回收，日志 0 字节、进程秒死。
#     所以 start 必须经 Bash 工具的 run_in_background=true 调用（wsl.exe 常驻→java 存活）；wait/status/stop 前台调。
#   - 启动参数固定且缺一不可：APP_PROFILE=test + -Dnacos.ip 顶掉集群内 DNS + register-enabled=false（否则本机
#     被登记进 test 服务发现，可能被转发真实流量）+ fastjson safeMode。
#   - 原理与依赖对齐（跨团队 SNAPSHOT 漂移）细节见 ai-docs/本地运行手册.md 与 docs/需求/07开发本地运行java环境/。
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"

ENV="${ENV:-test}"
NACOS_IP="${NACOS_IP:-10.0.54.16:30996}"
PORT="${SRUN_PORT:-8110}"
JAR="$DIR/03zhaocai-start/scm-cloud-starters-web/scm-cloud-source/target/scm-source-web.jar"
LOG="${SRUN_LOG:-/tmp/scm-source-run.log}"
JAR_PATTERN='target/scm-source-web.jar'

is_up() { (ss -ltn 2>/dev/null || netstat -ltn 2>/dev/null) | grep -q ":$PORT\b"; }

case "${1:-}" in
  start)
    [ -f "$JAR" ] || { echo "fat jar 不存在，先 build：$JAR"; exit 1; }
    pkill -f "$JAR_PATTERN" 2>/dev/null && sleep 2
    echo "启动 scm-source-web（env=$ENV, nacos=$NACOS_IP, 日志=$LOG）……"
    cd "$(dirname "$JAR")"
    export APP_PROFILE="$ENV"
    # 前台 exec：由调用方（Bash 工具 run_in_background）持有的 wsl.exe 保活
    exec java \
      -Dnacos.ip="$NACOS_IP" \
      -Dspring.cloud.nacos.discovery.register-enabled=false \
      -Dfastjson.parser.safeMode=true \
      -jar "$JAR" > "$LOG" 2>&1
    ;;
  wait)
    for i in $(seq 1 50); do
      grep -q "Started SourceApp" "$LOG" 2>/dev/null && { echo "STARTED after ~$((i*3))s，端口 $PORT"; is_up && echo "$PORT LISTEN 就绪"; exit 0; }
      grep -qiE "APPLICATION FAILED TO START|Error starting ApplicationContext|ClassNotFoundException|NoSuchBeanDefinition" "$LOG" 2>/dev/null && { echo "启动报错，看日志："; tail -30 "$LOG"; exit 1; }
      sleep 3
    done
    echo "等了 ~150s 仍没看到 Started，日志尾部："; tail -20 "$LOG"; exit 1
    ;;
  status)
    if is_up; then echo "运行中：$PORT LISTEN"; grep -q "Started SourceApp" "$LOG" 2>/dev/null && echo "（日志有 Started 标记）"; else echo "未运行（$PORT 无监听）"; fi
    ;;
  logs)
    tail -n "${2:-40}" "$LOG" 2>/dev/null || echo "无日志：$LOG"
    ;;
  stop)
    if pkill -f "$JAR_PATTERN" 2>/dev/null; then echo "已发停止信号"; else echo "没有在跑的实例"; fi
    ;;
  build)
    MOD="${2:-scm-source-chase}"
    echo "[1/2] 重装模块 $MOD 到 .m2 ……"
    (cd "$DIR/01zhaocai-end/scm-source-all" && mvn -pl "$MOD" install -DskipTests -q) || { echo "模块编译失败"; exit 1; }
    echo "[2/2] 重打 fat jar ……"
    (cd "$DIR/03zhaocai-start/scm-cloud-starters-web" && mvn -pl scm-cloud-source clean package -DskipTests -q) || { echo "打包失败"; exit 1; }
    ls -la "$JAR"
    echo "完成。接着：srun.sh start（run_in_background）→ srun.sh wait"
    ;;
  *)
    echo "用法: bash scripts/srun.sh start|wait|status|logs [n]|stop|build [模块]"
    echo "看脚本头部注释了解铁律与闭环。"; exit 2
    ;;
esac
