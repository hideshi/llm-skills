#!/usr/bin/env python3
"""プロファイルの工程と遷移が、流れ図と形式モデルの写しとずれていないかを確かめる。

正本は、各プロファイルの SKILL.md の工程の表（1列目の工程の識別子）と、「### 遷移」の表（元・先・条件）。
これを次の二つと突き合わせる。

1. 流れ図（docs/dev-skills-flows.md）の mermaid の矢印
2. 形式モデル（tests/formal/profile-<名前>/*.tla）を TLC で流したときに、実際に起きた工程の移り変わり

どちらも、工程でない点（判定のひし形、人の決定、入口、終わり）を通る道はたたんで、
工程から工程への矢印だけにして比べる。

あわせて、工程の識別子の決まり（docs/dev-skills-conventions.md の「工程の識別子」と付録の対応表）を
確かめる。形と重なり、人の工程の接尾辞、文の中の参照の実在、番号の残り、付録と工程の表の食い違い。

モデルの突き合わせには TLC（tla2tools.jar）と Java が要る。jar の場所を TLA2TOOLS_JAR か
--tla-jar で渡す。渡さなければ、モデルとの突き合わせは飛ばし、そのことを表示する。

使い方: python3 -I scripts/check_dev_flows.py [--tla-jar PATH] [リポジトリのルート]
"""
import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

# 工程の識別子の形。表ではバッククォートで囲み、流れ図ではラベルの1行目に裸で書く
STEP_ID = re.compile(r'[a-z][a-z0-9]*(?:-[a-z0-9]+)*')


def parse_args(argv):
    jar = os.environ.get("TLA2TOOLS_JAR")
    rest = []
    it = iter(argv)
    for a in it:
        if a == "--tla-jar":
            jar = next(it, None)
        else:
            rest.append(a)
    root = Path(rest[0]) if rest else Path(__file__).resolve().parent.parent
    return root, jar


def section_table(text, heading_re):
    """見出し（正規表現）の直後の表の行（見出し行を除く）を、セルのリストで返す。"""
    m = re.search(heading_re, text, re.M)
    if not m:
        return None
    rows = []
    for line in text[m.end():].splitlines():
        s = line.strip()
        if s.startswith("#"):
            break
        if not s.startswith("|"):
            if rows:
                break
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if all(re.fullmatch(r":?-+:?", c) for c in cells):
            continue
        rows.append(cells)
    return rows[1:] if rows else None


def step_id(cell):
    """表のセル（`識別子`）から工程の識別子を取り出す。形が合わなければ None。"""
    m = re.fullmatch(r'`([^`]+)`', cell.strip())
    return m.group(1) if m and STEP_ID.fullmatch(m.group(1)) else None


def label_step(label, steps):
    """流れ図のラベルの1行目が、そのプロファイルの工程の識別子なら返す。"""
    first = re.split(r'<br\s*/?>', label, maxsplit=1)[0].strip()
    return first if first in steps else None


def profile_flow(path):
    text = path.read_text(encoding="utf-8")
    steps = []
    for row in section_table(text, r"^## 工程\s*$") or []:
        sid = step_id(row[0])
        if sid:
            steps.append(sid)
    rows = section_table(text, r"^### 遷移\s*$")
    edges = None
    if rows is not None:
        edges = set()
        for row in rows:
            if len(row) >= 2:
                edges.add((row[0].strip().strip("`"), row[1].strip().strip("`")))
    return steps, edges


def collapse(adj, is_step):
    """工程でない点を通る道をたたみ、工程から工程への矢印の集合を返す。"""
    out = set()
    for s in list(adj):
        if not is_step(s):
            continue
        seen, stack = set(), list(adj[s])
        while stack:
            n = stack.pop()
            if n in seen:
                continue
            seen.add(n)
            if is_step(n):
                out.add((s, n))
            else:
                stack.extend(adj.get(n, ()))
    return out


def mermaid_flow(doc_text, profile_name, steps):
    m = re.search(rf"^## .*`{re.escape(profile_name)}`.*$", doc_text, re.M)
    if not m:
        return None
    block = re.search(r"```mermaid\n(.*?)```", doc_text[m.end():], re.S)
    if not block:
        return None
    body = block.group(1)
    labels = {}
    for nm, lab in re.findall(r'^\s*(\w+)\s*[\[\(\{]+\s*"([^"]*)"', body, re.M):
        labels[nm] = lab
    adj = defaultdict(set)
    for a, b in re.findall(r'^\s*(\w+)\s*-\.?-?>\s*(?:\|[^|]*\|\s*)?(\w+)\s*$', body, re.M):
        adj[a].add(b)
    node_step = {nm: label_step(lab, steps) for nm, lab in labels.items()}
    edges = collapse(adj, lambda n: node_step.get(n) is not None)
    return {(node_step[a], node_step[b]) for a, b in edges}


def model_flow(model_dir, jar):
    tla = sorted(model_dir.glob("*.tla"))
    if not tla:
        return None, None, "モデルが無い"
    tla = tla[0].resolve()
    cfg = tla.with_suffix(".cfg")
    src = tla.read_text(encoding="utf-8")
    m = re.search(r"^Steps\s*==\s*\{(.*?)\}", src, re.M | re.S)
    steps = set(re.findall(r'"([^"]+)"', m.group(1))) if m else set()
    excl = re.search(r"表さない工程:\s*(.*)$", src, re.M)
    excluded = set()
    if excl and excl.group(1).strip() not in ("なし", ""):
        excluded = set(re.findall(r"`([^`]+)`", excl.group(1).split("。")[0]))
    if not jar:
        return steps, excluded, None
    if "EdgeProbe" not in src:
        return steps, excluded, "モデルに EdgeProbe が無い（tests/formal/README.md を見る）"
    with tempfile.TemporaryDirectory() as tmp:
        # 工程の移り変わりは、モデルの EdgeProbe が初めて見た組だけを書き出す。
        # 状態の図をまるごと書き出すと、依頼の違いが増えたときに大きくなりすぎる
        # TLC は設定を仕様と同じ場所で探すので、両方を一時の場所に写す（モデルは1ファイル）
        probe_tla = Path(tmp) / tla.name
        probe_tla.write_text(src, encoding="utf-8")
        probe_cfg = probe_tla.with_suffix(".cfg")
        probe_cfg.write_text(cfg.read_text(encoding="utf-8")
                             + "\nACTION_CONSTRAINT EdgeProbe\n", encoding="utf-8")
        # 手元の機械を使い切らないよう、メモリと並びの数と時間に上限を付ける
        heap = os.environ.get("TLC_HEAP", "1g")
        workers = os.environ.get("TLC_WORKERS", "2")
        cmd = ["java", f"-Xmx{heap}", "-XX:+UseParallelGC", "-cp", jar, "tlc2.TLC",
               "-workers", workers, "-metadir", str(Path(tmp) / "states"),
               "-config", str(probe_cfg), str(probe_tla)]
        try:
            res = subprocess.run(cmd, cwd=tmp, capture_output=True, text=True,
                                 timeout=int(os.environ.get("TLC_TIMEOUT", "600")))
        except subprocess.TimeoutExpired:
            return steps, excluded, "TLC が時間の上限までに終わらなかった（TLC_TIMEOUT）"
        if res.returncode != 0 or "Model checking completed" not in res.stdout:
            tail = "\n".join(res.stdout.splitlines()[-15:])
            return steps, excluded, f"TLC が誤りで終わった（終了コード {res.returncode}）:\n{tail}"
    pc_adj = defaultdict(set)
    edge_re = re.compile(r'^<<"EDGE", "([^"]+)", "([^"]+)">>\s*$')
    for line in res.stdout.splitlines():
        e = edge_re.match(line.strip())
        # 同じ工程にとどまる組は、Next の中で状態を変えるもの（監査の「条件付き」など）だけが
        # 書き出される。終わりの足踏み（Done → Done）は工程でないので collapse で落ちる
        if e:
            pc_adj[e.group(1)].add(e.group(2))
    edges = collapse(pc_adj, lambda n: n in steps)
    return steps, excluded, edges


def fmt(edges):
    return "、".join(f"{a}→{b}" for a, b in sorted(edges)) or "なし"


# 工程の識別子の検査（規約の「工程の識別子」と付録の対応表）
HUMAN_SUFFIX = ("-ok", "-ask")
RESERVED = {"start"}
COUNTERS = r"(?:つ|回|問|件|個|本|か所|行|段|人|日)"
# 「工程5」「工程 5b」。「工程3つ」のような数え方は除く
OLD_STEP_REF = re.compile(rf"工程 ?[0-9]+[a-z]?(?![0-9a-z]|{COUNTERS})")
# 「工程」の後に識別子（バッククォート）でない英数字が来る書き方（「工程 baseline-update」）
UNTICKED_REF = re.compile(r"工程 (?=[A-Za-z0-9])")
BARE_NUMBER = re.compile(r"(?<![0-9A-Za-z.#\-])[0-9]+[a-z]?(?![0-9A-Za-z])")
# 「5d」「7b」の形の裸の語と、「・」で並んだ数字（「7・7b」「6a・6d」）
BARE_STEP = re.compile(r"(?<![0-9A-Za-z_.#/\-:])[0-9]{1,2}[a-f](?![0-9A-Za-z_\-])")
DOT_NUMBERS = re.compile(rf"(?<![0-9A-Za-z\-])[0-9]{{1,2}}[a-f]?・[0-9]{{1,2}}[a-f]?(?![0-9]|{COUNTERS})")
# 識別子に続く範囲・以降・以前
RANGE_REF = re.compile(r"`[a-z][a-z0-9-]*`\s*(?:〜|～|以降|以前)")
QUALIFIED_REF = re.compile(r"`(dev-profile-[a-z0-9-]+)` の工程 `([^`]+)`((?:・`[^`]+`)*)")
RECORD_HEADING = re.compile(r"^#+ .*記録")


def number_errors(where, text, errors, ticked_ids=True):
    """番号で工程を指す書き方と、識別子の範囲・以降を探す（記録は呼ぶ側で除く）。

    ticked_ids: 識別子をバッククォートで囲む文書か（モデルのコメントは囲まない）。
    """
    pats = [(OLD_STEP_REF, "番号で工程を指している"),
            (BARE_STEP, "番号の形の語が残っている"),
            (DOT_NUMBERS, "番号を並べている")]
    if ticked_ids:
        pats += [(UNTICKED_REF, "「工程」の後が識別子でない"),
                 (RANGE_REF, "識別子で範囲・以降を書いている")]
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("|---"):
            continue
        plain = re.sub(r"`[^`\n]*`", "``", s)
        for pat, what in pats:
            if pat.search(plain if pat is not RANGE_REF else s):
                errors.append(f"{where}: {what}: {s[:80]}")


def step_rows(text):
    """工程の表の行を、(1列目のセル, 単位の列) で返す。"""
    return [(row[0], row[2] if len(row) > 2 else "")
            for row in section_table(text, r"^## 工程\s*$") or []]


def ticked(text):
    """バッククォートで囲んだ語のうち、dev- で始まらないものを (語, 位置) で返す。"""
    return [(m.group(1), m.start()) for m in re.finditer(r"`([^`\n]+)`", text)
            if not m.group(1).startswith("dev-")]


def check_refs(where, text, allowed, all_steps, errors):
    """文の中の工程の参照が実在するかを見る。所属を書いた参照はそのプロファイルで引く。

    allowed: 所属を書かない参照の引き先（工程の識別子の集合）。all_steps: プロファイルごとの工程。
    """
    qualified = set()
    for m in QUALIFIED_REF.finditer(text):
        prof = m.group(1)
        items = [(m.group(2), m.start(2) - 1)]
        base = m.start(3)
        for mm in re.finditer(r"`([^`]+)`", m.group(3)):
            items.append((mm.group(1), base + mm.start()))
        for sid, pos in items:
            qualified.add(pos)
            if prof not in all_steps:
                errors.append(f"{where}: 所属に書いたプロファイル {prof} が無い")
            elif sid not in all_steps[prof]:
                errors.append(f"{where}: {prof} の工程に `{sid}` が無い")
    for word, pos in ticked(text):
        if pos in qualified:
            continue
        if word not in allowed:
            errors.append(f"{where}: `{word}` が工程の識別子に無い（工程でない語はバッククォートで囲まない）")


def split_sections(text, level="## "):
    """見出し（level）ごとに (見出しの行, 本文) を返す。最初の見出しより前は除く。"""
    parts = re.split(rf"^(?={re.escape(level)})", text, flags=re.M)
    return [(p.splitlines()[0], p) for p in parts if p.startswith(level)]


def without_records(text):
    """記録の節（見出しに「記録」を含む節）と、記録の表の行（日付で始まる行）を除く。"""
    out, skip, depth = [], False, 0
    for line in text.splitlines():
        h = re.match(r"^(#+) ", line)
        if h:
            if skip and len(h.group(1)) <= depth:
                skip = False
            if RECORD_HEADING.match(line):
                skip, depth = True, len(h.group(1))
        if skip or re.match(r"^\| 20[0-9]{2}-", line):
            continue
        out.append(line)
    return "\n".join(out)


def check_step_ids(root, profiles, doc):
    errors = []
    all_steps = {}
    for p in profiles:
        name = p.name
        text = (p / "SKILL.md").read_text(encoding="utf-8")
        body = text.split("\n---\n", 1)[-1]
        ids = []
        for cell, unit in step_rows(text):
            sid = step_id(cell)
            if sid is None:
                errors.append(f"{name}: 工程の表の1列目「{cell}」が識別子の形でない（`[a-z][a-z0-9]*(-[a-z0-9]+)*` をバッククォートで囲む）")
                continue
            ids.append(sid)
            if sid in RESERVED:
                errors.append(f"{name}: `{sid}` は予約の語で、工程の識別子に使えない")
            human = unit.strip().startswith("（人")
            if sid.endswith(HUMAN_SUFFIX) and not human:
                errors.append(f"{name}: `{sid}` は -ok・-ask で終わるが、人の工程でない")
            if human and not sid.endswith(HUMAN_SUFFIX) and sid != "intake":
                errors.append(f"{name}: 人の工程 `{sid}` は -ok・-ask で終える（受付の intake を除く）")
        for sid in sorted({s for s in ids if ids.count(s) > 1}):
            errors.append(f"{name}: 工程の識別子 `{sid}` が重複している")
        all_steps[name] = set(ids)
        number_errors(name, without_records(body), errors)
        for title, table in (("遷移", r"^### 遷移\s*$"), ("振り分け", r"^## 振り分け\s*$")):
            for row in section_table(text, table) or []:
                cells = row[:2] if title == "遷移" else row[-1:]
                for c in cells:
                    plain = re.sub(rf"[0-9]+{COUNTERS}", "", re.sub(r"`[^`]*`", " ", c))
                    if BARE_NUMBER.search(plain):
                        errors.append(f"{name}: {title}の表に番号が残っている: {c[:60]}")

    for p in profiles:
        name = p.name
        body = (p / "SKILL.md").read_text(encoding="utf-8").split("\n---\n", 1)[-1]
        check_refs(name, without_records(body), all_steps[name], all_steps, errors)

    # 流れ図: 節ごとにプロファイルを決めて引く
    for head, sec in split_sections(doc):
        profs = re.findall(r"`(dev-profile-[a-z0-9-]+)`", head)
        if len(profs) != 1:
            continue
        prof = profs[0]
        steps = all_steps.get(prof, set())
        prose = re.sub(r"```mermaid\n.*?```", "", sec, flags=re.S)
        check_refs(f"流れ図 {prof}", prose, steps, all_steps, errors)
        number_errors(f"流れ図 {prof}", prose, errors)
        for block in re.findall(r"```mermaid\n(.*?)```", sec, re.S):
            # 矢印のラベルは見ず、節点の定義のラベルだけを見る
            for lab in re.findall(r'^\s*\w+\s*[\[\(\{]+\s*"([^"]*)"', block, re.M):
                first = re.split(r"<br\s*/?>", lab, maxsplit=1)[0].strip()
                if STEP_ID.fullmatch(first) and first not in steps:
                    errors.append(f"流れ図 {prof}: ラベルの識別子 {first} が工程の表に無い")
                if re.match(r"^[0-9]+[a-z]?\. ", first):
                    errors.append(f"流れ図 {prof}: ラベルが番号で始まっている: {first[:40]}")

    # 起動の試験: 節の見出しに書いたプロファイルで「期待する工程」の列を引く
    # 見出しに2つ以上のプロファイルがあれば、所属なしで書けるのはそのすべてにある識別子だけ
    cases = root / "docs" / "dev-skills-trigger-cases.md"
    if cases.exists():
        ctext = without_records(cases.read_text(encoding="utf-8"))
        number_errors("起動の試験", "\n".join(l for l in ctext.splitlines() if not l.startswith("|")), errors)
        for head, sec in split_sections(ctext):
            profs = [x for x in re.findall(r"`(dev-profile-[a-z0-9-]+)`", head) if x in all_steps]
            rows = section_table(sec, r"^## .*$")
            if not rows:
                continue
            header = [l for l in sec.splitlines() if l.startswith("|")][0]
            if "期待する工程" not in header:
                continue
            allowed = set.intersection(*(all_steps[x] for x in profs)) if profs else set()
            for row in rows:
                cell = row[-1]
                check_refs(f"起動の試験 {row[0]}", cell, allowed, all_steps, errors)
                if BARE_NUMBER.search(QUALIFIED_REF.sub("", cell).replace("`", " ")):
                    errors.append(f"起動の試験 {row[0]}: 期待する工程に番号が残っている: {cell[:60]}")

    # 形式モデル: 工程の値に番号の文字列を使わない。README は記録を除いて番号で指さない
    for p in profiles:
        mdir = root / "tests" / "formal" / p.name.replace("dev-", "", 1)
        for tla in mdir.glob("*.tla"):
            full = tla.read_text(encoding="utf-8")
            src = re.sub(r"\\\*.*$", "", full, flags=re.M)
            for lit in sorted(set(re.findall(r'"([0-9]+[a-z]?)"', src))):
                errors.append(f"{tla.relative_to(root)}: 番号の文字列 \"{lit}\" が残っている")
            comments = re.findall(r"\\\*(.*)$", full, re.M) + re.findall(r"\(\*(.*?)\*\)", full, re.S)
            number_errors(str(tla.relative_to(root)), "\n".join(comments), errors, ticked_ids=False)
        readme = mdir / "README.md"
        if readme.exists():
            number_errors(str(readme.relative_to(root)),
                          without_records(readme.read_text(encoding="utf-8")), errors)

    # 起動の試験の定義の注記（バッククォートの無い JSON の文）
    cjson = root / "tests" / "trigger" / "cases.json"
    if cjson.exists():
        for note in re.findall(r'"note":\s*"((?:[^"\\]|\\.)*)"', cjson.read_text(encoding="utf-8")):
            for pat, what in ((OLD_STEP_REF, "番号で工程を指している"), (BARE_STEP, "番号の形の語が残っている"),
                              (DOT_NUMBERS, "番号を並べている")):
                if pat.search(note):
                    errors.append(f"tests/trigger/cases.json の注記: {what}: {note[:80]}")

    # 付録の対応表: 表の識別子は今の工程の表にあるか、消した識別子の一覧にある。消した識別子を使い回さない
    conv = (root / "docs" / "dev-skills-conventions.md").read_text(encoding="utf-8")
    m = re.search(r"^## 付録: 工程の識別子の対応表\s*$(.*?)(?=^## |\Z)", conv, re.M | re.S)
    if not m:
        errors.append("規約に「## 付録: 工程の識別子の対応表」が無い")
        return errors
    appendix = m.group(1)
    retired_line = re.search(r"^消した識別子（使い回さない）:(.*)$", appendix, re.M)
    if not retired_line:
        errors.append("付録に「消した識別子（使い回さない）:」の行が無い")
        retired = set()
    else:
        retired = {(prof, sid) for prof, sid, _ in
                   QUALIFIED_REF.findall(retired_line.group(1).replace("` の `", "` の工程 `"))}
    rows = re.findall(r"^\| `(dev-profile-[a-z0-9-]+)` \| (.*) \|$", appendix, re.M)
    seen = [prof for prof, _ in rows]
    for prof in sorted(set(seen)):
        if seen.count(prof) > 1:
            errors.append(f"付録: {prof} の行が重複している")
    for prof in sorted(set(all_steps) - set(seen)):
        errors.append(f"付録: {prof} の行が無い（発行した識別子の台帳を兼ねる）")
    for prof, sids in rows:
        if prof not in all_steps:
            errors.append(f"付録: プロファイル {prof} が無い")
            continue
        items = re.findall(r"(?:^|、)\s*([0-9]+[a-z]?|—) → `([^`]+)`", sids)
        if len(items) != len(re.findall(r"→", sids)):
            errors.append(f"付録: {prof} の行に「番号 → `識別子`」か「— → `識別子`」の形でない項目がある")
        listed = [sid for _, sid in items]
        for sid in sorted({s for s in listed if listed.count(s) > 1}):
            errors.append(f"付録: {prof} の `{sid}` が重複している")
        for sid in listed:
            if sid not in all_steps[prof] and (prof, sid) not in retired:
                errors.append(f"付録: {prof} の `{sid}` が工程の表にも、消した識別子の一覧にも無い")
        for sid in sorted(all_steps[prof] - set(listed)):
            errors.append(f"付録: {prof} の工程 `{sid}` が付録に無い（足した工程は「— → `{sid}`」で足す）")
    for prof, sid in sorted(retired):
        if sid in all_steps.get(prof, set()):
            errors.append(f"付録: 消した識別子 {prof} の `{sid}` を使い回している")
    return errors


def main():
    root, jar = parse_args(sys.argv[1:])
    errors, notes = [], []
    doc = (root / "docs" / "dev-skills-flows.md").read_text(encoding="utf-8")
    profiles = sorted(p for p in (root / "skills").glob("dev-profile-*") if (p / "SKILL.md").exists())
    for p in profiles:
        name = p.name
        steps, edges = profile_flow(p / "SKILL.md")
        if edges is None:
            errors.append(f"{name}: 「### 遷移」の表が無い")
            continue
        sset = set(steps)
        for a, b in sorted(edges):
            for x in (a, b):
                if x not in sset:
                    errors.append(f"{name}: 遷移の表の「{x}」が工程の表に無い")
        targets = {b for _, b in edges}
        sources = {a for a, _ in edges}
        for s in steps[1:]:
            if s not in targets:
                notes.append(f"{name}: 工程 {s} へ入る遷移が無い（入口の工程なら問題ない）")
        for s in steps[:-1]:
            if s not in sources:
                errors.append(f"{name}: 工程 {s} から出る遷移が無い（行き止まり）")

        mer = mermaid_flow(doc, name, sset)
        if mer is None:
            errors.append(f"{name}: 流れ図に mermaid の図が無い")
        else:
            if edges - mer:
                errors.append(f"{name}: 流れ図に無い遷移: {fmt(edges - mer)}")
            if mer - edges:
                errors.append(f"{name}: 流れ図にだけある遷移: {fmt(mer - edges)}")

        model_dir = root / "tests" / "formal" / name.replace("dev-", "", 1)
        if not model_dir.is_dir():
            notes.append(f"{name}: 形式モデルが無い（{model_dir.relative_to(root)}）")
            continue
        msteps, excluded, medges = model_flow(model_dir, jar)
        if msteps is not None:
            if (sset - excluded) != msteps:
                errors.append(f"{name}: モデルの工程が違う。モデルに無い: {sorted(sset - excluded - msteps)}、"
                              f"モデルにだけある: {sorted(msteps - sset)}")
        if isinstance(medges, str):
            errors.append(f"{name}: {medges}")
        elif medges is None:
            notes.append(f"{name}: TLC の jar が渡されていないので、モデルの遷移との突き合わせは飛ばした")
        else:
            pe = {(a, b) for a, b in edges if a not in excluded and b not in excluded}
            if pe - medges:
                errors.append(f"{name}: モデルで起きない遷移: {fmt(pe - medges)}")
            if medges - pe:
                errors.append(f"{name}: モデルにだけある遷移: {fmt(medges - pe)}")

    errors.extend(check_step_ids(root, profiles, doc))

    for n in notes:
        print("注意", n)
    for e in errors:
        print("NG", e)
    print(f"プロファイル {len(profiles)}、問題 {len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
