#!/usr/bin/env python3
"""lib/ と test/ のファイル間の import 依存を lakos で解析し、1 枚の HTML にまとめる。

使い方:
  python3 tool/deps/build.py <リポジトリのルート> <出力ディレクトリ>   # HTML を作る（Pages 用）
  python3 tool/deps/build.py --check <リポジトリのルート>             # 違反があれば exit 1（PR 用）
前提: lakos（`dart pub global activate lakos`）が PATH にあること。HTML を作るときは graphviz の dot も。
出力: <出力ディレクトリ>/index.html

層の割り当て（LAYERS / SHARED）は仮の設計ルール。lib/ にファイルを足したら、ここに書き足す。
割り当てのないファイルは「未分類」の行に出し、違反（下の層から上の層への import、
共通部品から他のファイルへの import）は赤い矢印で示す。HTML を作るときは警告を出すだけで
失敗させない（サイトのデプロイを止めないため）。--check は違反・循環依存・未割り当てのファイルで
失敗する（未割り当てを許すと、そのファイルが絡む違反を見逃し、ルールが形骸化するため）。
"""

import html
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# 上の層ほど大きい。上の層は下の層を（飛ばしても）使ってよく、逆は違反。
LAYERS = [
    (3, "入口", ["main", "home_page"]),
    (
        2,
        "画面・部品",
        [
            "app_drawer",
            "daily_banner",
            "daily_page",
            "daily_records_page",
            "history_page",
            "calculator_widget",
        ],
    ),
    (
        1,
        "状態・保存・集計",
        [
            "history_repository",
            "history_entry",
            "settings_repository",
            "daily_repository",
            "daily_progress",
            "daily_stats",
            "app_dependencies",
        ],
    ),
    (
        0,
        "純粋ロジック",
        [
            "judge",
            "judge_isolate",
            "trivia",
            "number_style",
            "spoken",
            "daily_puzzle",
            "calculator",
        ],
    ),
]
# どの層からも使ってよい。図には描かず、ここから他のファイルへの import だけを違反として見る。
SHARED = ["language", "date_key", "share", "links", "best_effort"]
UNASSIGNED = -2  # 割り当てのないファイル（新しく足したものなど）


def run(cmd, cwd):
    return subprocess.run(
        cmd, cwd=cwd, check=True, capture_output=True, text=True
    ).stdout


def lakos_json(cwd, *extra):
    # 循環があると lakos 自身が異常終了するので許可し、isAcyclic を見て自分で報告する
    cmd = ["lakos", "-f", "json", "-m", "--cycles-allowed", *extra, "."]
    return json.loads(run(cmd, cwd))


def stage(repo, dest, with_test):
    """解析対象だけを一時ディレクトリにコピーする（build/ や生成ファイルを拾わないため）。"""
    dest.mkdir(parents=True)
    shutil.copy(repo / "pubspec.yaml", dest)
    shutil.copytree(repo / "lib", dest / "lib", ignore=shutil.ignore_patterns("l10n"))
    if with_test:
        shutil.copytree(repo / "test", dest / "test")


def to_svg(dot_source):
    out = subprocess.run(
        ["dot", "-Tsvg"], input=dot_source, check=True, capture_output=True, text=True
    ).stdout
    return theme_svg(out)


def theme_svg(svg):
    """SVG の固定色をページのテーマ色（CSS 変数）に置き換える。"""
    svg = svg[svg.index("<svg") :]
    svg = re.sub(r'<svg width="[^"]*" height="[^"]*"', "<svg", svg, count=1)
    svg = svg.replace('fill="white"', 'fill="var(--bg)"')
    svg = svg.replace('fill="Lavender"', 'fill="var(--node)"')
    svg = svg.replace('fill="black"', 'fill="var(--ink)"')
    svg = svg.replace('stroke="black"', 'stroke="var(--ink)"')
    return svg


def classify(data):
    """各 import を「down / same / violation」に分け、違反と未割り当てのファイルを返す。"""
    names = {k: v["label"] for k, v in data["nodes"].items() if k.startswith("/lib/")}
    level = {}
    for lv, _, members in LAYERS:
        for m in members:
            level[m] = lv
    for m in SHARED:
        level[m] = -1
    unassigned = sorted(n for n in names.values() if n not in level)
    for n in unassigned:
        level[n] = UNASSIGNED

    violations = []
    edges = []
    for e in data["edges"]:
        a = names.get(e["from"])
        b = names.get(e["to"])
        if a is None or b is None or level[b] == -1 or level[a] == UNASSIGNED:
            continue
        if level[b] == UNASSIGNED:
            continue
        # 共通部品（-1）は他のどの層より低いので、他のファイルへの import はここで違反になる
        if level[a] < level[b]:
            violations.append((a, b))
            edges.append((a, b, "violation"))
        elif level[a] == level[b]:
            edges.append((a, b, "same"))
        else:
            edges.append((a, b, "down"))
    return names, level, edges, violations, unassigned


def layered_dot(data):
    names, level, edges, violations, unassigned = classify(data)
    rows = [(lv, label) for lv, label, _ in LAYERS]
    if unassigned:
        rows.append((UNASSIGNED, "未分類（tool/deps/build.py に追記）"))
    shown = {n: level[n] for n in level if level[n] != -1 and n in names.values()}

    out = [
        "digraph G{rankdir=TB;nodesep=0.35;ranksep=0.9;splines=true;"
        'node[shape=box,style="rounded,filled",fillcolor=Lavender,'
        'fontname="Helvetica",fontsize=13];edge[arrowsize=0.7]'
    ]
    for lv, label in rows:
        out.append(f'"_L{lv}"[label="{label}",shape=plaintext,style="",fontsize=12];')
    for (lv, _), (nxt, _) in zip(rows, rows[1:]):
        out.append(f'"_L{lv}"->"_L{nxt}"[style=invis];')
    for lv, _ in rows:
        members = ";".join(f'"{n}"' for n, v in shown.items() if v == lv)
        out.append(f'{{rank=same;"_L{lv}";{members}}}')
    color = {"down": "#8a93a6", "same": "#e0a100", "violation": "#e03131"}
    for a, b, kind in edges:
        width = ",penwidth=2.5" if kind == "violation" else ""
        out.append(f'"{a}"->"{b}"[color="{color[kind]}"{width}];')
    out.append("}")
    return "\n".join(out), violations, unassigned


def fmt(v):
    return f"{v:.2f}" if isinstance(v, float) else str(v)


def metrics_table(lib_m, all_m):
    rows = [
        ("isAcyclic", "isAcyclic"),
        ("ファイル数（numNodes）", "numNodes"),
        ("import の本数（numEdges）", "numEdges"),
        ("avgDegree", "avgDegree"),
        ("ccd", "ccd"),
        ("acd", "acd"),
        ("nccd", "nccd"),
        ("行数（totalSloc）", "totalSloc"),
        ("avgSloc", "avgSloc"),
    ]
    body = "\n".join(
        f"<tr><td>{label}</td><td>{fmt(lib_m[k])}</td><td>{fmt(all_m[k])}</td></tr>"
        for label, k in rows
    )
    orphans = f"<tr><td>孤立ファイル（orphans）</td><td>{len(lib_m['orphans'])}</td><td>{len(all_m['orphans'])}</td></tr>"
    return (
        "<table><thead><tr><th>指標</th><th>lib のみ</th><th>lib と test</th></tr></thead>"
        f"<tbody>{body}\n{orphans}</tbody></table>"
    )


def check(repo):
    """PR 用の検査。依存の向きの違反があれば 1 を返す（graphviz は要らない）。"""
    with tempfile.TemporaryDirectory() as tmp:
        lib_dir = Path(tmp) / "prime_fact"
        stage(repo, lib_dir, with_test=False)
        data = lakos_json(lib_dir)
    _, _, _, violations, unassigned = classify(data)
    for n in unassigned:
        print(f"::error::層が未割り当て: {n}（tool/deps/build.py の LAYERS か SHARED に追記）")
    for a, b in violations:
        print(f"::error::依存の向きの違反: {a} -> {b}")
    cyclic = not data["metrics"]["isAcyclic"]
    if cyclic:
        print(f"::error::循環依存: {data['metrics']['firstCycle']}")
    if violations:
        print(
            f"{len(violations)} 本の違反があります。上の層は下の層を使えますが、"
            "逆（下から上、共通部品から他のファイル）は使えません。"
            "ルールは tool/deps/build.py の LAYERS / SHARED にあります。"
        )
    if violations or cyclic or unassigned:
        return 1
    print(f"OK: {data['metrics']['numNodes']} ファイル、違反なし")
    return 0


def main():
    if sys.argv[1] == "--check":
        sys.exit(check(Path(sys.argv[2]).resolve()))
    repo = Path(sys.argv[1]).resolve()
    out_dir = Path(sys.argv[2]).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    rev = run(["git", "rev-parse", "--short", "HEAD"], repo).strip()

    with tempfile.TemporaryDirectory() as tmp:
        lib_dir = Path(tmp) / "lib_only" / "prime_fact"
        all_dir = Path(tmp) / "all" / "prime_fact"
        stage(repo, lib_dir, with_test=False)
        stage(repo, all_dir, with_test=True)
        lib_json = lakos_json(lib_dir)
        all_json = lakos_json(all_dir)
        lib_svg = theme_svg(to_dot_svg(lib_dir))

    dot, violations, unassigned = layered_dot(lib_json)
    layer_svg = to_svg(dot)

    for a, b in violations:
        print(f"::warning::依存の向きの違反: {a} -> {b}")
    for n in unassigned:
        print(f"::warning::層が未割り当て: {n}（tool/deps/build.py に追記）")

    lib_m, all_m = lib_json["metrics"], all_json["metrics"]
    n_viol = len(violations)
    delta = (
        f"test を足すと、ファイルは {all_m['numNodes'] - lib_m['numNodes']} 本、"
        f"import は {all_m['numEdges'] - lib_m['numEdges']} 本、"
        f"行数は {all_m['totalSloc'] - lib_m['totalSloc']} 行増えます。"
    )

    page = (
        TEMPLATE.replace("@@REV@@", html.escape(rev))
        .replace("@@LAYER_SVG@@", layer_svg)
        .replace("@@LIB_SVG@@", lib_svg)
        .replace("@@TABLE@@", metrics_table(lib_m, all_m))
        .replace("@@DELTA@@", html.escape(delta))
        .replace("@@SHARED@@", " / ".join(SHARED))
        .replace("@@VIOLATIONS@@", str(n_viol))
        .replace("@@NODES@@", str(lib_m["numNodes"]))
    )
    (out_dir / "index.html").write_text(page, encoding="utf-8")
    print(f"wrote {out_dir / 'index.html'} (violations={n_viol}, unassigned={len(unassigned)})")


def to_dot_svg(lib_dir):
    dot = run(["lakos", "-m", "."], lib_dir)
    return subprocess.run(
        ["dot", "-Tsvg"], input=dot, check=True, capture_output=True, text=True
    ).stdout


TEMPLATE = """<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>prime_fact の依存ツリー</title>
<style>
:root{--bg:#fbfbfd;--ink:#1d2330;--muted:#5d6676;--node:#e4e8fb;--line:#d5d9e4;--accent:#2a4bd7;font-family:Inter,"Hiragino Sans","Noto Sans JP",system-ui,sans-serif}
@media (prefers-color-scheme:dark){:root{--bg:#12151c;--ink:#dfe3ee;--muted:#9099ac;--node:#252b44;--line:#2b3140;--accent:#8ea2ff;color-scheme:dark}}
body{background:var(--bg);color:var(--ink);margin:0;padding:20px max(16px,env(safe-area-inset-left,0px))}
h1{font-size:20px;margin:0 0 4px;text-wrap:balance}
p{margin:0 0 14px;color:var(--muted);line-height:1.6;max-width:65ch}
code{font-family:ui-monospace,Menlo,monospace;font-size:.92em}
details{margin-bottom:14px;color:var(--muted)}
summary{cursor:pointer;color:var(--ink)}
dl{display:grid;grid-template-columns:max-content 1fr;gap:4px 16px;margin:10px 0}
dt{font-family:ui-monospace,Menlo,monospace;font-size:.9em;color:var(--ink)}
dd{margin:0}
@media (max-width:560px){dl{grid-template-columns:1fr}dd{margin-bottom:6px}}
.tabs{display:flex;gap:8px;margin-bottom:12px;flex-wrap:wrap}
.tabs button{font:inherit;color:var(--ink);background:none;border:1px solid var(--line);border-radius:6px;padding:6px 12px;cursor:pointer}
.tabs button[aria-pressed="true"]{border-color:var(--accent);color:var(--accent);font-weight:600}
.tabs button:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}
th,td{text-align:left;padding:6px 12px;border-bottom:1px solid var(--line)}
th{color:var(--muted);font-weight:600}
td:nth-child(n+2),th:nth-child(n+2){text-align:right}
.note{margin:12px;max-width:65ch}
.legend{line-height:1.8}
.view{overflow:auto;border:1px solid var(--line);border-radius:8px;padding:8px;max-height:80vh}
.view svg{height:auto;min-width:900px;width:100%;display:block}
.view svg text{fill:var(--ink)}
</style>
</head>
<body>
<h1>prime_fact の依存ツリー</h1>
<p>master（@@REV@@）の import 関係を <code>lakos</code> で描いたものです。マージのたびに自動で更新されます。矢印は「import する側 → される側」です。狭い画面では横にスクロールしてください。</p>
<details><summary>指標の意味</summary>
<dl>
<dt>isAcyclic</dt><dd>true なら循環依存がありません。</dd>
<dt>numNodes / numEdges</dt><dd>ファイル数と import の本数です。</dd>
<dt>avgDegree</dt><dd>1 ファイルあたりの import の本数（本数 ÷ ファイル数）です。</dd>
<dt>orphans</dt><dd>どこにもつながっていない孤立ファイルの数です。</dd>
<dt>ccd</dt><dd>各ファイルが直接・間接に頼っているファイルの数（自分を含む）を、全ファイルで足した値です。</dd>
<dt>acd</dt><dd>ccd ÷ ファイル数です。1 ファイルを変えたとき、平均で何ファイルに影響が及ぶかの目安です。</dd>
<dt>nccd</dt><dd>ccd を、同じ数のファイルを二分木に並べたときの値で割ったものです。1 前後なら依存が整った木に近く、大きいほど密に絡んでいます。</dd>
<dt>totalSloc / avgSloc</dt><dd>コード行数の合計と、1 ファイルあたりの平均です。</dd>
</dl></details>
<div class="tabs">
<button id="b-lay" aria-pressed="true">層で見る</button>
<button id="b-lib" aria-pressed="false">lib のみ（@@NODES@@ ファイル）</button>
<button id="b-met" aria-pressed="false">指標の比較</button>
</div>
<p id="legend" class="legend"><span style="color:#8a93a6">━</span> 上の層から下の層へ（正しい向き。層を飛ばしてもよい） <span style="color:#e0a100">━</span> 同じ層の中 <span style="color:#e03131">━</span> 下の層から上の層へ（違反。現在 @@VIOLATIONS@@ 本）<br>層の分け方は仮です（<code>tool/deps/build.py</code>）。上から、入口 → 画面・部品 → 状態・保存・集計 → 純粋ロジック。共通部品（@@SHARED@@）は、どの層からも使えるので図から省いています。</p>
<div class="view" id="v-lay">@@LAYER_SVG@@</div>
<div class="view" id="v-lib" hidden>@@LIB_SVG@@</div>
<div class="view" id="v-met" hidden>
@@TABLE@@
<p class="note">@@DELTA@@ test から lib への依存は一方向なので、lib 側の構造には影響しません。</p>
</div>
<script>
const ids=['lay','lib','met'];
ids.forEach(k=>document.getElementById('b-'+k).addEventListener('click',()=>{
  ids.forEach(j=>{document.getElementById('v-'+j).hidden=j!==k;document.getElementById('b-'+j).setAttribute('aria-pressed',String(j===k))});
  document.getElementById('legend').hidden=k!=='lay';
}));
</script>
</body>
</html>
"""

if __name__ == "__main__":
    main()
