#!/usr/bin/env python3
"""開発スキル群（dev-）の組み合わせと書式を検査する。

1. プロファイルが名指しする単位が実在する
2. どのプロファイルからも使われない単位が無い
3. 単位とプロファイルの入出力の型が、型の一覧にある
4. 単位の本文に、ほかの単位とプロファイルの名前が出てこない（型の一覧 dev-shared は参照してよい）
5. プロファイルの工程の受け取る型・渡す型が、名指しした単位の入力・出力の表にある
6. 必須の節がそろい、name がディレクトリ名と一致し、description に日本語がある
7. 「必須」の列が、必須／任意／条件付き のどれかで始まる
8. どの型も、少なくとも一つの単位が入力か出力に使っている
9. 4つの道具向けのディレクトリに、skills/ へのリンクがある
10. プロファイルの中で型がつながっている。工程が受け取る型は、どれかの工程が渡すか、
    「外から受け取る型:」の行にある。工程が渡す型は、どれかの工程が受け取るか、同じ工程の
    中の単位が受け取るか、「外へ渡す型:」の行にある。順序（どの工程が先か）は見ない
11. 単位の根拠の別紙（references/grounding.md）に必須の3節・確かめた日・有効な確かめた水準・
    SKILL.md からの参照がそろい、手順の箇所の節番号と DOI/URL の形式が合っている
12. 単位の references/ にある埋めた例（行頭が「型: 」の行で始まる部分）が、型の一覧にある型で、
    その単位の出力の表にあり、決まり文句があり、チェックボックスと空のセルが無く、SKILL.md から
    リンクされている。例の見出しが型の欄に合うか、識別子が実在するかは見ない。案件の成果物には当てない

使い方: python3 -I scripts/check_dev_skills.py [--grounding-warnings] [リポジトリのルート]
"""
import re
import sys
from pathlib import Path

args = sys.argv[1:]
SHOW_GROUNDING_WARNINGS = False
if "--grounding-warnings" in args:
    SHOW_GROUNDING_WARNINGS = True
    args = [a for a in args if a != "--grounding-warnings"]

ROOT = Path(args[0]) if args else Path(__file__).resolve().parent.parent
SKILLS = ROOT / "skills"
SHARED = "dev-shared"
TYPES_FILE = SKILLS / SHARED / "references" / "artifact-types.md"
TOOL_DIRS = [".cursor/skills", ".claude/skills", ".agent/skills", "codex/skills"]
NON_TYPES = {"—", "-", ""}
REQUIRED_WORDS = ("必須", "任意", "条件付き")
UNIT_SECTIONS = ("入力", "出力", "使わない場面", "手順", "終了条件")
PROFILE_SECTIONS = ("工程", "振り分け", "工程の間の決まり", "終わり方")
GROUNDING_LEVELS = ("原典を読んだ", "書誌と二次資料で確かめた", "未確認")
GROUNDING_SECTIONS = ("先行の手法", "独自の判断", "改善の記録")
EXAMPLE_PHRASE = "形の一例。正本は型の一覧の欄。形式・節名・置き場所は任意で、案件に既に形があればその形に従う。値はすべて作り物。"
EXAMPLE_DECL = re.compile(r"^型: (.+)$", re.M)
FALSIFY_HINTS = ("見直す", "件数", "比べる", "比較", "しきい値", "記録で", "再検討", "差し戻", "推移", "割合", "差分", "実測", "起きなかったか")


def table_rows(text, heading):
    """見出し（## heading）の直後の表の行を、セルのリストで返す。表が無ければ None。"""
    m = re.search(rf"^## {re.escape(heading)}\s*$", text, re.M)
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


def first_table_keys(text):
    """文書の最初の表の1列目（見出し行を除く）を集める。"""
    keys, in_table = [], False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("|"):
            cells = [c.strip() for c in s.strip("|").split("|")]
            if not in_table:
                in_table = True  # 見出し行
                continue
            if all(re.fullmatch(r":?-+:?", c) for c in cells):
                continue
            keys.append(cells[0])
        elif in_table:
            break
    return set(keys)


def split_types(cell):
    cell = re.sub(r"[（(][^）)]*[）)]", "", cell)
    return [t.strip() for t in re.split(r"[、,]", cell) if t.strip() not in NON_TYPES]


def frontmatter(text):
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not m:
        return {}
    fm = {}
    for line in m.group(1).splitlines():
        k, _, v = line.partition(":")
        fm[k.strip()] = v.strip()
    return fm


def has_heading(text, heading):
    return re.search(rf"^## {re.escape(heading)}\s*$", text, re.M) is not None


def declared_types(text, label):
    """「label: 型、型」の行の型を返す。行が無ければ None。"""
    m = re.search(rf"^{re.escape(label)}[:：]\s*(.*)$", text, re.M)
    return None if m is None else split_types(m.group(1))


def extract_dois(text):
    """文中の DOI 文字列を抽出する。Elsevier 等の括弧入り DOI を壊さず、外側の閉じ括弧だけ除く。"""
    dois = []
    for raw in re.findall(r"DOI[:\s]*([^\s（）、。,→`]+)", text):
        while raw.endswith(")") and raw.count(")") > raw.count("("):
            raw = raw[:-1]
        if raw:
            dois.append(raw)
    return dois


def check_grounding(name, path, skill_text):
    """単位ごとの references/grounding.md の構造と形式を検査し、(errors, warnings, counts) を返す。"""
    g_errors, g_warnings = [], []
    counts = {"原典を読んだ": 0, "書誌と二次資料で確かめた": 0, "未確認": 0, "existence_only": 0}
    g_path = path / "references" / "grounding.md"
    if not g_path.exists():
        return [f"{name}: references/grounding.md が無い"], g_warnings, counts
    if "references/grounding.md" not in skill_text:
        g_errors.append(f"{name}: SKILL.md に references/grounding.md への参照が無い")

    gt = g_path.read_text(encoding="utf-8")
    for h in GROUNDING_SECTIONS:
        if not has_heading(gt, h):
            g_errors.append(f"{name}: grounding.md に「## {h}」の節が無い")
    if not re.search(r"^- 確かめた日:\s*\d{4}-\d{2}-\d{2}\s*$", gt, re.M):
        g_errors.append(f"{name}: grounding.md に「- 確かめた日: YYYY-MM-DD」が無い")

    heading_nums = set(re.findall(r"^#{2,4}\s+(\d+)\.", skill_text, re.M))
    valid_nums = heading_nums or set(re.findall(r"^(\d+)\.", skill_text, re.M))

    prior_rows = table_rows(gt, "先行の手法")
    if prior_rows is None:
        g_errors.append(f"{name}: grounding.md に「## 先行の手法」の表が無い")
    else:
        for row in prior_rows:
            if len(row) != 6:
                g_errors.append(f"{name}: grounding.md「先行の手法」の列数が 6 でない: {row[:1]}")
                continue
            part, _, src, lvl = row[:4]
            matched_lvl = next((x for x in GROUNDING_LEVELS if lvl.startswith(x)), None)
            if matched_lvl is None:
                g_errors.append(f"{name}: grounding.md の確かめた水準「{lvl}」が規約の3値でない")
            else:
                counts[matched_lvl] += 1
                if matched_lvl == "未確認" and src not in ("—", "-"):
                    g_errors.append(f"{name}: 水準が「未確認」の行に出典が書かれている: {src}")
                if matched_lvl != "未確認" and src in ("", "—", "-"):
                    g_errors.append(f"{name}: 水準が「{matched_lvl}」の行に出典が無い: {part}")

            part_clean = re.sub(r"（[^）]*）|\([^)]*\)|`[^`]+`|INV-[0-9〜・]+|問い\s*[0-9〜・]+", "", part)
            for num in re.findall(r"(?:^|[/／・、〜~\s])(\d+)\.", part_clean):
                if num != "0" and valid_nums and num not in valid_nums:
                    g_errors.append(f"{name}: grounding.md が SKILL.md に無い手順番号「{num}.」を指している（{part}）")

            for doi in extract_dois(src):
                if not re.match(r"^10\.\d{4,9}/[^\s（）、。→]+$", doi):
                    g_errors.append(f"{name}: grounding.md の DOI 形式が不正: {doi}")
            for url in re.findall(r"https?://[^\s）)）、。>`]+", src):
                if not re.match(r"^https?://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(?:/\S*)?$", url):
                    g_errors.append(f"{name}: grounding.md の URL 形式が不正: {url}")

    judge_rows = table_rows(gt, "独自の判断")
    if judge_rows is None:
        g_errors.append(f"{name}: grounding.md に「## 独自の判断」の表が無い")
    else:
        for row in judge_rows:
            if len(row) != 3 or any(c in ("", "—", "-") for c in row):
                g_errors.append(f"{name}: grounding.md「独自の判断」の行が不正または空欄あり: {row[:1]}")
                continue
            how = row[2]
            if re.search(r"(?:を見る|を確認する|か確かめる)。?$", how) and not any(k in how for k in FALSIFY_HINTS):
                counts["existence_only"] += 1
                g_warnings.append(f"{name}: 存在確認型の確かめ方「{how}」")

    rec_match = re.search(r"^## 改善の記録\s*$", gt, re.M)
    if rec_match and not re.search(r"^- \d{4}-\d{2}-\d{2}:", gt[rec_match.end():], re.M):
        g_errors.append(f"{name}: grounding.md の「## 改善の記録」に日付付きの記録が無い")

    return g_errors, g_warnings, counts


def check_examples(name, path, skill_text, types, outputs):
    """単位の references/ の埋めた例を見る（検査 12）。例の部分は「型: 」の行から、次の「型: 」の行か
    ファイルの終わりまで。"""
    errors = []
    refs = path / "references"
    if not refs.is_dir():
        return errors
    for f in sorted(refs.rglob("*.md")):
        text = f.read_text(encoding="utf-8")
        decls = list(EXAMPLE_DECL.finditer(text))
        if not decls:
            continue
        rel = f.relative_to(path).as_posix()
        where = f"{name}: {rel}"
        if f"]({rel})" not in skill_text:
            errors.append(f"{where}: 例が SKILL.md からリンクされていない")
        for i, m in enumerate(decls):
            part = text[m.start():decls[i + 1].start() if i + 1 < len(decls) else len(text)]
            type_name = re.split(r"[（(]", m.group(1), maxsplit=1)[0].strip()
            if type_name not in types:
                errors.append(f"{where}: 例の型「{type_name}」が型の一覧に無い")
            elif type_name not in outputs:
                errors.append(f"{where}: 例の型「{type_name}」が単位の出力の表に無い")
            if EXAMPLE_PHRASE not in part:
                errors.append(f"{where}: 例「{type_name}」に決まり文句が無い")
            if re.search(r"^\s*[-*] \[[ xX]\]", part, re.M):
                errors.append(f"{where}: 例「{type_name}」にチェックボックスがある")
            for line in part.splitlines():
                s = line.strip()
                if not s.startswith("|") or re.fullmatch(r"\|[\s:|-]+\|", s):
                    continue
                cells = [c.strip() for c in s.strip("|").split("|")]
                if any(c == "" for c in cells):
                    errors.append(f"{where}: 例「{type_name}」の表に空のセルがある: {s[:60]}")
    return errors


def main():
    errors = []
    types = first_table_keys(TYPES_FILE.read_text(encoding="utf-8"))
    dirs = sorted(p for p in SKILLS.glob("dev-*") if p.is_dir())
    for p in dirs:
        if p.name != SHARED and not (p / "SKILL.md").exists():
            errors.append(f"{p.name}: SKILL.md が無い")
    skill_dirs = [p for p in dirs if (p / "SKILL.md").exists()]
    units = {p.name: p for p in skill_dirs if not p.name.startswith("dev-profile-")}
    profiles = {p.name: p for p in skill_dirs if p.name.startswith("dev-profile-")}
    all_names = set(units) | set(profiles)
    unit_io = {}
    used_units, used_types = set(), set()
    grounding_warnings = []
    grounding_totals = {"原典を読んだ": 0, "書誌と二次資料で確かめた": 0, "未確認": 0, "existence_only": 0}

    for name, path in {**units, **profiles}.items():
        text = (path / "SKILL.md").read_text(encoding="utf-8")
        fm = frontmatter(text)
        if fm.get("name") != name:
            errors.append(f"{name}: name「{fm.get('name')}」がディレクトリ名と違う")
        if not re.search(r"[぀-ヿ一-鿿]", fm.get("description", "")):
            errors.append(f"{name}: description に日本語が無い")
        for heading in PROFILE_SECTIONS if name in profiles else UNIT_SECTIONS:
            if not has_heading(text, heading):
                errors.append(f"{name}: 「## {heading}」の節が無い")
        for d in TOOL_DIRS:
            link = ROOT / d / name
            if not link.is_symlink() or link.resolve() != path.resolve():
                errors.append(f"{name}: {d} に skills/ へのリンクが無い")

    for name, path in units.items():
        text = (path / "SKILL.md").read_text(encoding="utf-8")
        io = {}
        for heading in ("入力", "出力"):
            rows = table_rows(text, heading)
            if rows is None:
                errors.append(f"{name}: 「## {heading}」の直後に表が無い")
                io[heading] = set()
                continue
            io[heading] = {row[0] for row in rows}
            for row in rows:
                if row[0] not in types:
                    errors.append(f"{name}: {heading}の型「{row[0]}」が型の一覧に無い")
                used_types.add(row[0])
                if heading == "入力" and (len(row) < 2 or not row[1].startswith(REQUIRED_WORDS)):
                    errors.append(f"{name}: 入力「{row[0]}」の必須の列が規約の語でない")
        unit_io[name] = io
        errors.extend(check_examples(name, path, text, types, io["出力"]))
        g_errs, g_warns, g_counts = check_grounding(name, path, text)
        errors.extend(g_errs)
        grounding_warnings.extend(g_warns)
        for k in grounding_totals:
            grounding_totals[k] += g_counts[k]
        for f in sorted(path.rglob("*.md")):
            found = set(re.findall(r"\bdev-[a-z0-9-]+", f.read_text(encoding="utf-8")))
            for other in sorted((found & all_names) - {name}):
                errors.append(f"{name}: {f.relative_to(path)} がほかの名前 {other} を名指ししている")

    for name, path in profiles.items():
        text = (path / "SKILL.md").read_text(encoding="utf-8")
        rows = table_rows(text, "工程")
        if rows is None:
            errors.append(f"{name}: 「## 工程」の直後に表が無い")
            continue
        flow_given, flow_passed = {}, {}
        for row in rows:
            # 1列目は工程の識別子（バッククォート付き）、2列目は工程の名前
            if len(row) < 6:
                errors.append(f"{name}: 工程の表の列が足りない: {row}")
                continue
            step, _, unit_cell, req, given, passed = row[:6]
            for t in split_types(given):
                flow_given.setdefault(t, []).append(step)
            for t in split_types(passed):
                flow_passed.setdefault(t, []).append(step)
            # 同じ工程の中で、ある単位が渡した型を別の単位が受け取るもの（依頼文 → レビューなど）
            row_units = [u for u in re.findall(r"`(dev-[a-z0-9-]+)`", unit_cell) if u in unit_io]
            if len(row_units) > 1:
                ins_r = set().union(*(unit_io[u]["入力"] for u in row_units))
                for t in split_types(passed):
                    if t in ins_r:
                        flow_given.setdefault(t, []).append(step)
            if not req.startswith(REQUIRED_WORDS):
                errors.append(f"{name}: 工程「{step}」の必須の列が規約の語でない")
            named = re.findall(r"`(dev-[a-z0-9-]+)`", unit_cell)
            for unit in named:
                used_units.add(unit)
                if unit not in units:
                    errors.append(f"{name}: 名指しした単位 {unit} が実在しない")
            if not named and "dev-" in unit_cell:
                errors.append(f"{name}: 工程「{step}」の単位名がバッククォートで囲まれていない")
            given_t, passed_t = split_types(given), split_types(passed)
            for t in given_t + passed_t:
                if t not in types:
                    errors.append(f"{name}: 工程「{step}」の型「{t}」が型の一覧に無い")
            known = [u for u in named if u in unit_io]
            if known:
                ins = set().union(*(unit_io[u]["入力"] for u in known))
                outs = set().union(*(unit_io[u]["出力"] for u in known))
                for t in given_t:
                    if t in types and t not in ins:
                        errors.append(f"{name}: 工程「{step}」が渡す「{t}」を、単位の入力が受け取らない")
                for t in passed_t:
                    if t in types and t not in outs:
                        errors.append(f"{name}: 工程「{step}」の「{t}」を、単位の出力が出さない")

        ext_in = declared_types(text, "外から受け取る型")
        ext_out = declared_types(text, "外へ渡す型")
        if ext_in is None or ext_out is None:
            errors.append(f"{name}: 「外から受け取る型:」と「外へ渡す型:」の行が要る（無ければ「—」と書く）")
            ext_in, ext_out = ext_in or [], ext_out or []
        for t in ext_in + ext_out:
            if t not in types:
                errors.append(f"{name}: 外との受け渡しの型「{t}」が型の一覧に無い")
        for t, steps in flow_given.items():
            if t not in flow_passed and t not in ext_in:
                errors.append(f"{name}: 工程 {'、'.join(steps)} が受け取る「{t}」を、どの工程も渡さず、外から受け取る型にも無い")
        for t, steps in flow_passed.items():
            if t not in flow_given and t not in ext_out:
                errors.append(f"{name}: 工程 {'、'.join(steps)} が渡す「{t}」を、どの工程も受け取らず、外へ渡す型にも無い")

    for unit in sorted(set(units) - used_units):
        errors.append(f"{unit}: どのプロファイルからも使われていない")
    for t in sorted(types - used_types):
        errors.append(f"型「{t}」: どの単位の入力にも出力にも無い")

    for e in errors:
        print("NG", e)
    if SHOW_GROUNDING_WARNINGS:
        for w in grounding_warnings:
            print("WARN", w)
    print(f"単位 {len(units)}、プロファイル {len(profiles)}、型 {len(types)}、問題 {len(errors)}")
    print(
        f"根拠の別紙: 原典 {grounding_totals['原典を読んだ']} / "
        f"書誌と二次資料 {grounding_totals['書誌と二次資料で確かめた']} / "
        f"未確認 {grounding_totals['未確認']}、"
        f"存在確認型の確かめ方 {grounding_totals['existence_only']}件"
        + ("" if SHOW_GROUNDING_WARNINGS or not grounding_warnings else "（詳細: --grounding-warnings）")
    )
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
