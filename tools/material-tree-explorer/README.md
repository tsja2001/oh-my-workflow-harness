# 物料全景树

独立 React 本地工具，用完整树形界面研究招采 MDM 类目与具体物料。支持 test/UAT 切换、完整四级树、末级/状态/层级筛选、物料组合查询、CSV 导出和环境差异对比。

## 启动

在工作区根目录执行：

```bash
bash scripts/material-tree.sh dev
```

浏览器打开 `http://127.0.0.1:4317`。

开发服务器会复用工作区的 `scripts/api.sh` 和 `scripts/auth.sh`。账号密码仍只在 `ai-docs/creds.env`，不会进入前端代码或浏览器。

## 验证与构建

```bash
bash scripts/material-tree.sh check
bash scripts/material-tree.sh build
bash scripts/material-tree.sh start
```

`npm start` 托管已经构建好的 `dist/`，默认仍只监听 `127.0.0.1:4317`。如端口冲突，可在启动前设置 `MATERIAL_TREE_PORT`。

## 安全边界

- 只支持 test/UAT，不支持 prod。
- 只代理固定的类目和物料只读查询接口。
- 不把 token、Cookie、密码返回给浏览器。
- 不提供任何类目、物料或集采台账写操作。
