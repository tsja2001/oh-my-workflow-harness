import os
import re
import subprocess
import sys
import tempfile

D = "/home/t/projects/work-wsl/docs/harness需求/01流程图改造"
MMD = "/home/t/projects/work-wsl/.tmp-mermaid/node_modules/.bin/mmdc"
PPTR = "/home/t/projects/work-wsl/.tmp-mermaid/pptr.json"
FENCE = re.compile(r"^```(\w*)\s*$")

fails = 0
total = 0
for fn in sorted(os.listdir(D)):
    if not fn.startswith("改-") or not fn.endswith(".md"):
        continue
    lines = open(os.path.join(D, fn), encoding="utf-8").read().split("\n")
    blocks, cur, start = [], None, 0
    for i, ln in enumerate(lines):
        m = FENCE.match(ln)
        if m:
            if cur is None and m.group(1) == "mermaid":
                cur, start = [], i + 2
            elif cur is not None:
                blocks.append((start, "\n".join(cur)))
                cur = None
            else:
                cur = None
            continue
        if cur is not None:
            cur.append(ln)
    if cur is not None:
        blocks.append((start, "\n".join(cur)))

    for idx, (start, body) in enumerate(blocks, 1):
        total += 1
        with tempfile.NamedTemporaryFile("w", suffix=".mmd", delete=False, encoding="utf-8") as f:
            f.write(body)
            src = f.name
        out = src + ".svg"
        try:
            r = subprocess.run([MMD, "-i", src, "-o", out, "-p", PPTR],
                               capture_output=True, text=True, timeout=120)
            ok = r.returncode == 0 and os.path.getsize(out) > 500 if os.path.exists(out) else False
            if ok:
                print(f"  OK   {fn}  #{idx} (源文件第 {start} 行)  {len(body.splitlines())} 行")
            else:
                fails += 1
                err = (r.stderr or r.stdout or "").strip().replace("\n", " ")[:300]
                print(f"✗ FAIL {fn}  #{idx} (源文件第 {start} 行)\n       {err}")
        except Exception as e:
            fails += 1
            print(f"✗ ERR  {fn}  #{idx} (源文件第 {start} 行)  {e}")
        finally:
            for p in (src, out):
                if os.path.exists(p):
                    os.unlink(p)

print(f"\n共 {total} 张，失败 {fails} 张")
sys.exit(1 if fails else 0)
