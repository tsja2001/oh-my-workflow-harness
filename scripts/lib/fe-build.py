#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""前端页面地图构建器 —— 被 scripts/fe.sh build 调用，不要直接跑。

干的事：把「菜单树接口返回的中文菜单」和「前端仓库里的路由 + .vue 文件」对上号，
生成两张离线表，后续 AI 查页面只 grep 这两张表，不用再登录、不用再全树搜索。

产出：
  ai-docs/前端页面地图.tsv   菜单叶子（中文名 → URL → 仓库 → 路由 → .vue 文件）
  ai-docs/前端路由索引.tsv   全部路由（路由 → 仓库 → .vue 文件），覆盖菜单里没有的详情页

用法：python3 scripts/lib/fe-build.py <menu.json 或 -（无菜单也能只建路由索引）> <前端根目录> <输出目录>
"""
import json
import os
import re
import sys

# 路由定义：path: '/xxx'    组件：component: () => import('../views/xxx')
RE_PATH = re.compile(r"""path\s*:\s*(['"])(.*?)\1""")
RE_IMPORT = re.compile(r"""import\s*\(\s*(['"])(.*?)\1\s*\)""")
RE_COMP_IDENT = re.compile(r"""component\s*:\s*([A-Za-z_$][\w$]*)""")
# import Home from '../views/Home.vue'
RE_TOP_IMPORT = re.compile(r"""^\s*import\s+([A-Za-z_$][\w$]*)\s+from\s+(['"])(.*?)\2""", re.M)

SKIP_DIRS = {"node_modules", "dist", ".git", "public", "static"}


def walk_files(root, suffixes):
    """遍历前端源码，跳过 node_modules/dist（不跳会慢到无法忍受）。"""
    for base, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.endswith(suffixes):
                yield os.path.join(base, f)


def repo_of(path, front_root):
    """把文件路径归到它所属的前端仓库目录（顶层仓 or scm-vue-all/ 下的旧仓）。"""
    rel = os.path.relpath(path, front_root)
    parts = rel.split(os.sep)
    if parts[0] == "scm-vue-all" and len(parts) > 1:
        return os.path.join("scm-vue-all", parts[1])
    return parts[0]


def is_legacy(repo):
    """scm-vue-all/ 是历史聚合仓，和顶层同名仓大量重复，定位时排在后面。"""
    return repo.startswith("scm-vue-all" + os.sep) or repo.startswith("scm-vue-all/")


def resolve_component(router_file, front_root, repo, spec):
    """把 import('../views/xxx') 解析成真实存在的文件，试 .vue / /index.vue 等后缀。"""
    if not spec:
        return ""
    router_dir = os.path.dirname(router_file)
    if spec.startswith("@/"):
        base = os.path.join(front_root, repo, "src", spec[2:])
    elif spec.startswith("."):
        base = os.path.normpath(os.path.join(router_dir, spec))
    else:
        return ""
    for cand in (base, base + ".vue", base + ".js",
                 os.path.join(base, "index.vue"), os.path.join(base, "index.js")):
        if os.path.isfile(cand):
            return os.path.relpath(cand, front_root).replace(os.sep, "/")
    # 文件没找到也把猜测路径吐出来，比空着强（有时是 .vue 大小写不一致）
    return os.path.relpath(base, front_root).replace(os.sep, "/") + "?"


def parse_routes(front_root):
    """扫所有 src/router/*.js，抽出 (路由, 仓库, 定义位置, 组件文件)。"""
    rows = []
    for f in walk_files(front_root, (".js",)):
        if f"{os.sep}src{os.sep}router{os.sep}" not in f:
            continue
        try:
            text = open(f, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        repo = repo_of(f, front_root)
        # 顶部 import 的组件名 → 文件，供 component: Home 这种写法回查
        ident_map = {m.group(1): m.group(3) for m in RE_TOP_IMPORT.finditer(text)}
        rel_router = os.path.relpath(f, front_root).replace(os.sep, "/")
        for m in RE_PATH.finditer(text):
            route = m.group(2)
            if not route.startswith("/"):
                continue
            line = text.count("\n", 0, m.start()) + 1
            # 组件在 path 之后的一小段里找；跨过下一个 path: 就停，免得串到下一条路由
            tail = text[m.end(): m.end() + 600]
            nxt = RE_PATH.search(tail)
            if nxt:
                tail = tail[: nxt.start()]
            spec = ""
            im = RE_IMPORT.search(tail)
            if im:
                spec = im.group(2)
            else:
                ci = RE_COMP_IDENT.search(tail)
                if ci and ci.group(1) in ident_map:
                    spec = ident_map[ci.group(1)]
            rows.append({
                "route": route,
                "repo": repo.replace(os.sep, "/"),
                "router": f"{rel_router}:{line}",
                "comp": resolve_component(f, front_root, repo, spec),
            })
    return rows


def flatten_menu(node, chain, out):
    """菜单树是多层嵌套（trees 字段），压平成「一级/二级/叶子」+ URL。"""
    name = (node.get("name") or "").strip()
    path = node.get("path") or ""
    new_chain = chain + [name] if name else chain
    kids = node.get("trees") or node.get("children") or []
    if kids:
        for k in kids:
            flatten_menu(k, new_chain, out)
    if "index.html#" in path:
        out.append({"chain": " / ".join(new_chain), "name": name, "url": path})


def pattern_regex(route):
    """把 /dynamicPage/:module/:type 这种参数化路由转成正则，好让菜单 URL 对上号。

    这类「动态页面」是全站最常见的坑：菜单上写的是 /dynamicPage/source/cebpubservice，
    但前端根本没有这条路由，只有一个通用壳子 /dynamicPage/:module/:type，
    页面长什么样由后端 JSON 配置决定（见「平台管理 / JSON管理」菜单）。
    """
    parts = []
    for seg in route.strip("/").split("/"):
        if seg.startswith(":"):
            parts.append("/[^/]+" + ("?" if seg.endswith("?") else ""))
        else:
            parts.append("/" + re.escape(seg))
    return re.compile("^" + "".join(parts) + "$")


def name_matches(repo, ctx):
    """仓库目录名和 URL 上下文是不是一回事，如 /procurementScheme/ ↔ scm-vue-all-procurementscheme。"""
    name = repo.split("/")[-1].lower().replace("-", "")
    return ctx.lower().replace("-", "") in name


def pick_exact(cands):
    """精确路由命中时的取舍：顶层新仓优先于 scm-vue-all/ 旧聚合仓（两边大量重复）。"""
    if not cands:
        return None
    return sorted(cands, key=lambda c: (is_legacy(c["repo"]),
                                        bool(c["comp"].endswith("?") or not c["comp"]),
                                        len(c["repo"])))[0]


def pick_shell(cands, ctx, ctx_repo):
    """动态页壳子路由（/dynamicPage/:module/:type）几乎每个仓都有，光看路由分不出仓库。
    只能先信「这个 URL 上下文靠精确路由已经认定的仓库」，再退回仓名匹配。"""
    if not cands:
        return None
    want = ctx_repo.get(ctx)
    for c in cands:
        if c["repo"] == want:
            return c
    named = [c for c in cands if name_matches(c["repo"], ctx)]
    if named:
        return sorted(named, key=lambda c: (is_legacy(c["repo"]), len(c["repo"])))[0]
    return None


def main():
    menu_file, front_root, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    front_root = os.path.abspath(front_root)

    routes = parse_routes(front_root)
    by_route = {}
    for r in routes:
        by_route.setdefault(r["route"], []).append(r)
    patterns = [(pattern_regex(r["route"]), r) for r in routes if ":" in r["route"]]

    route_tsv = os.path.join(out_dir, "前端路由索引.tsv")
    with open(route_tsv, "w", encoding="utf-8") as fh:
        fh.write("路由\t仓库\t路由定义\t组件文件\n")
        for r in sorted(routes, key=lambda x: (is_legacy(x["repo"]), x["repo"], x["route"])):
            fh.write("\t".join([r["route"], r["repo"], r["router"], r["comp"]]) + "\n")

    menus = []
    if menu_file != "-":
        raw = json.load(open(menu_file, encoding="utf-8"))
        for top in raw.get("data") or []:
            flatten_menu(top, [], menus)

    # 第一遍：只认精确路由，这是最硬的证据，用它投票选出「URL 上下文 → 前端仓库」
    seen, leaves = set(), []
    votes = {}
    for m in menus:
        url = m["url"]
        if url in seen:
            continue
        seen.add(url)
        ctx = url.lstrip("/").split("/")[0]
        route = url.split("#", 1)[1] if "#" in url else "/"
        hit = pick_exact(by_route.get(route)) if route != "/" else None
        leaves.append({"chain": m["chain"], "url": url, "ctx": ctx, "route": route, "hit": hit})
        if hit:
            votes.setdefault(ctx, {}).setdefault(hit["repo"], 0)
            votes[ctx][hit["repo"]] += 1

    ctx_repo = {}
    for ctx, cnt in votes.items():
        ctx_repo[ctx] = sorted(cnt.items(),
                               key=lambda kv: (-kv[1], not name_matches(kv[0], ctx),
                                               is_legacy(kv[0])))[0][0]
    # 上下文一条精确路由都没命中（前端仓没克隆 / 全是动态页）→ 只能按仓名猜，标出来别当真
    all_repos = sorted({r["repo"] for r in routes})
    guessed = set()
    for lf in leaves:
        if lf["ctx"] in ctx_repo:
            continue
        named = [r for r in all_repos if name_matches(r, lf["ctx"])]
        if named:
            ctx_repo[lf["ctx"]] = sorted(named, key=lambda r: (is_legacy(r), len(r)))[0]
            guessed.add(lf["ctx"])

    rows, miss = [], 0
    for lf in leaves:
        hit, matched, note = lf["hit"], lf["route"], ""
        if hit is None and lf["route"] != "/":
            # 精确路由没命中，再拿参数化路由（/xxx/:module/:type）套一遍
            cands = [r for rx, r in patterns if rx.match(lf["route"])]
            hit = pick_shell(cands, lf["ctx"], ctx_repo)
            if hit is not None:
                matched = hit["route"]
                note = "动态页(壳子路由,页面内容由后端JSON配置决定)"
        if hit is None and lf["route"] != "/":
            miss += 1
            note = "本地前端仓没有这条路由：仓没克隆，或当前分支不含该页面"
        if lf["ctx"] in guessed and note:
            note += "；仓库是按名字猜的"
        rows.append({
            "chain": lf["chain"], "url": lf["url"], "ctx": lf["ctx"], "route": matched,
            "repo": hit["repo"] if hit else ctx_repo.get(lf["ctx"], ""),
            "router": hit["router"] if hit else "",
            "comp": hit["comp"] if hit else "",
            "note": note,
        })

    menu_tsv = os.path.join(out_dir, "前端页面地图.tsv")
    with open(menu_tsv, "w", encoding="utf-8") as fh:
        fh.write("菜单全路径\t页面URL\t上下文\t路由\t仓库\t路由定义\t组件文件\t备注\n")
        for r in sorted(rows, key=lambda x: x["chain"]):
            fh.write("\t".join([r["chain"], r["url"], r["ctx"], r["route"],
                                r["repo"], r["router"], r["comp"], r["note"]]) + "\n")

    ctx_tsv = os.path.join(out_dir, "前端上下文对照.tsv")
    with open(ctx_tsv, "w", encoding="utf-8") as fh:
        fh.write("URL上下文\t前端仓库\t依据菜单数\t判定\n")
        for ctx in sorted(ctx_repo):
            n = votes.get(ctx, {}).get(ctx_repo[ctx], 0)
            how = "按仓名猜（无精确路由佐证）" if ctx in guessed else "精确路由佐证"
            fh.write(f"{ctx}\t{ctx_repo[ctx]}\t{n}\t{how}\n")
    ctx_map = ctx_repo

    print(f"路由索引：{len(routes)} 条 → {route_tsv}")
    print(f"菜单地图：{len(rows)} 条（其中 {miss} 条在本地前端仓找不到路由）→ {menu_tsv}")
    print(f"上下文对照：{len(ctx_map)} 个 → {ctx_tsv}")


if __name__ == "__main__":
    main()
