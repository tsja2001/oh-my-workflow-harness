#!/bin/bash
# 物料全景树本地工具：完整类目树、物料查询、test/UAT 对比。
# 登录复用 scripts/api.sh / auth.sh，浏览器不会接触凭据或 token。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/tools/material-tree-explorer"
command_name="${1:-dev}"

usage() {
  cat <<'USAGE'
用法：bash scripts/material-tree.sh [dev|check|build|start|install]

  dev      启动开发服务器（默认），访问 http://127.0.0.1:4317
  check    类型检查 + 单元测试 + 生产构建
  build    生产构建
  start    启动已构建版本
  install  按 package-lock.json 安装依赖
USAGE
}

need_node() {
  command -v node >/dev/null 2>&1 || { echo '缺少 node，请先安装 Node.js 20.19+ 或 22.12+' >&2; exit 1; }
  command -v npm >/dev/null 2>&1 || { echo '缺少 npm' >&2; exit 1; }
  node -e '
    const [major, minor] = process.versions.node.split(".").map(Number);
    if (major < 20 || (major === 20 && minor < 19) || (major === 22 && minor < 12)) process.exit(1);
  ' || { echo "当前 Node.js $(node -v) 太旧；本工具需要 20.19+ 或 22.12+" >&2; exit 1; }
}

install_if_needed() {
  if [ ! -d "$APP_DIR/node_modules" ]; then
    echo '首次运行，正在安装前端依赖…'
    (cd "$APP_DIR" && npm ci --no-audit --no-fund)
  fi
}

need_node
case "$command_name" in
  install)
    (cd "$APP_DIR" && npm ci --no-audit --no-fund)
    ;;
  dev)
    install_if_needed
    cd "$APP_DIR"
    exec npm run dev
    ;;
  check)
    install_if_needed
    cd "$APP_DIR"
    exec npm run check
    ;;
  build)
    install_if_needed
    cd "$APP_DIR"
    exec npm run build
    ;;
  start)
    install_if_needed
    if [ ! -f "$APP_DIR/dist/index.html" ]; then
      echo '还没有构建产物，先执行：bash scripts/material-tree.sh build' >&2
      exit 1
    fi
    cd "$APP_DIR"
    exec npm start
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "未知命令：$command_name" >&2
    usage >&2
    exit 2
    ;;
esac
