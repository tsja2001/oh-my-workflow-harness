import re
import sys

FENCE = re.compile(r"^\s*(```|~~~)")
BOX = "┌└├┐┘┤┬┴┼─│▼▲►◄↑↓→═║╔╚╠"
MERMAID_PREFIX = re.compile(
    r"^\s*(?:Note\s+(?:over|of|left of|right of)\s+[\w,]+\s*:|"
    r"[\w]+\s*(?:->>|-->>|->|-->|-\)|\.)\s*[\w]*\s*:)\s*"
)

D = "/home/t/projects/work-wsl/docs/harness需求/01流程图改造"
PAIRS = [
    "15_51-集采管控全流程走一遍",
    "15_13c-两周总览与影响范围",
    "18_54-全集团架构全图",
]


def split_blocks(path):
    """把文件切成 (是否在代码块内, 行) 序列。"""
    lines = open(path, encoding="utf-8").read().split("\n")
    inblk, blk, ascii_blocks, other = False, [], [], []
    for ln in lines:
        if FENCE.match(ln):
            if inblk:
                body = "\n".join(blk)
                is_ascii = sum(1 for c in body if c in BOX) >= 12
                (ascii_blocks if is_ascii else other).extend(blk)
            inblk = not inblk
            blk = []
            continue
        (blk if inblk else other).append(ln)
    return other, ascii_blocks


def blob_of(path):
    """整份文件压成一串归一化文本，用来判断内容是否只是挪了位置。"""
    text = open(path, encoding="utf-8").read()
    text = MERMAID_PREFIX.sub("", text)
    text = text.replace("<br/>", "").replace("**", "")
    return re.sub(r"[\s　]+", "", text)


def clauses(line):
    line = MERMAID_PREFIX.sub("", line).replace("<br/>", "").replace("**", "")
    return [c for c in (re.sub(r"[\s　]+", "", x) for x in re.split(r"[。；，]", line)) if c]


bad = 0
for stem in PAIRS:
    old_other, _ = split_blocks(f"{D}/原-{stem}.md")
    new_other, _ = split_blocks(f"{D}/改-{stem}.md")
    newset = set(new_other)
    blob = blob_of(f"{D}/改-{stem}.md")

    kept = [l for l in old_other if l.strip()]
    lost, moved = [], []
    for l in kept:
        if l in newset:
            continue
        parts = clauses(l)
        (moved if parts and all(p in blob for p in parts) else lost).append(l)

    print(f"{stem}: 图外正文 {len(kept)} 行｜真丢失 {len(lost)}｜挪进图内 {len(moved)}")
    for l in lost:
        bad += 1
        print(f"   ✗ 丢失 {l[:110]}")
    for l in moved:
        print(f"   → 挪进图内 {l[:80]}")

print("\n结论：" + ("图外正文零丢失" if bad == 0 else f"{bad} 行正文真丢了，需核对"))
sys.exit(1 if bad else 0)
