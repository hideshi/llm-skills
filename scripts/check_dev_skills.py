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
12. 単位の references/ の埋めた例（-example.md の全体と、別紙の見出しが「例」の節）の頭の2行が、
    形の正しい型の宣言と決まり文句で、その型が型の一覧と単位の出力の表にある。例に、チェックボックス、
    空のセル・埋め草、列の数の違い、3行を超える一覧の表、「工程」に続く工程の識別子が無い。SKILL.md の
    入力か出力の節からリンクされている。「型: なし（…）」は型の外の文書の例で、型の検査の代わりに型の外の
    決まり文句と、原典の参照を入力に持つ単位かを見る。範囲が取れない例、単位の直下や examples/ の例、
    プロファイルと dev-shared の例も落とす。コードブロックと HTML のコメントの中は見ない。
    Markdown のすべての書き方は見ない（書く形は規約で決める）。例の見出しが型の欄に合うか、
    識別子が実在するかは見ない。案件の成果物には当てない

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
EXAMPLE_PHRASE_OUTSIDE = "形の一例。型の外の文書で、正本は案件の文書。形式・節名・置き場所は任意で、案件に既に形があればその形に従う。値はすべて作り物。"
EXAMPLE_OUTSIDE = "なし"
EXAMPLE_DECL = re.compile(r"^型: (\S.*)$", re.M)
LOOSE_DECL = re.compile(r"^[ \t]*(?:[-*+][ \t]+|\d+\.[ \t]+)?型[ \t]*[:：]", re.M)
CHECKBOX = re.compile(r"(?:^|[\s|>(（])\[[ xX\u3000]\](?!\()|[\u2610-\u2612]", re.M)
HTML_COMMENT = re.compile(r"<!--.*?-->", re.S)
MD_HEADING = re.compile(r"^(#{1,6})[ \t]+(.*?)[ \t]*$", re.M)
TABLE_SEP = re.compile(r"\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*")
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


def blank_code(text):
    """コードブロック（字下げしたもの、4つ以上のバッククォートを含む）と HTML のコメントの中身を
    空行に置き換える（行の数は保つ）。閉じは、開きと同じ文字で同じ長さ以上の行。"""
    out, fence = [], None
    for line in text.split("\n"):
        if fence is None:
            m = re.match(r"^\s*(`{3,}|~{3,})", line)
            if m:
                fence = m.group(1)
                out.append("")
                continue
            out.append(line)
        else:
            m = re.match(r"^\s*(`{3,}|~{3,})\s*$", line)
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence):
                fence = None
            out.append("")
    text = "\n".join(out)
    return HTML_COMMENT.sub(lambda m: "\n" * m.group(0).count("\n"), text)


def blank_inline_code(text):
    """行の中のコード（同じ数のバッククォートで囲んだ所）を、同じ長さの空白に置き換える。"""
    def repl(m):
        return " " * len(m.group(0))
    return re.sub(r"(`+)(?!`).+?(?<!`)\1(?!`)", repl, text)


def example_regions(text, whole):
    """例の範囲を返す。-example.md はファイル全体。ほかは見出しが「例」の節で、次の同じ深さか浅い
    見出しの前まで。例の範囲の中にある「例」の見出しは、別の例として数えない。"""
    if whole:
        return [text]
    regions, covered_until = [], -1
    heads = list(MD_HEADING.finditer(text))
    for i, h in enumerate(heads):
        # 見出しが「例」だけか、「例（…）」「例: …」の節（「例外」「手順の例」などは含めない）
        if h.start() < covered_until or not re.fullmatch(r"例(?:[（(:：\s].*)?", h.group(2)):
            continue
        end = len(text)
        for h2 in heads[i + 1:]:
            if len(h2.group(1)) <= len(h.group(1)):
                end = h2.start()
                break
        covered_until = end
        regions.append(text[h.end():end])
    return regions


def example_head(part):
    """例の範囲の頭の2行（見出しを除いた最初の空でない行と、その次の行）を返す。"""
    lines = part.split("\n")
    for i, ln in enumerate(lines):
        if ln.strip() and not MD_HEADING.match(ln):
            return ln, (lines[i + 1] if i + 1 < len(lines) else "")
    return "", ""


def is_filler(value):
    """空、記号だけ、または埋め草の語か。"""
    s = re.sub(r"<br\s*/?>", "", value)
    s = s.strip("*_~` \t　")
    if not re.search(r"\w", s):
        return True
    return bool(re.fullmatch(r"(?i)(tbd|tba|todo|n/?a|xxx|未定|未記入)[。.]?", s))


def split_cells(line):
    """表の行をセルに分ける。外枠の縦棒は片側1つだけ外す。`\\|` とバッククォートの中の縦棒は区切らない。"""
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|") and not s.endswith("\\|"):
        s = s[:-1]
    cells, buf, i = [], "", 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            buf += s[i:i + 2]
            i += 2
            continue
        if c == "`":
            # 同じ数のバッククォートで閉じるまでを、行の中のコードとして読み飛ばす
            n = len(re.match(r"`+", s[i:]).group(0))
            close = re.compile(r"(?<!`)" + "`" * n + r"(?!`)").search(s, i + n)
            if close:
                buf += s[i:close.end()]
                i = close.end()
                continue
            buf += s[i:i + n]
            i += n
            continue
        if c == "|":
            cells.append(buf.strip())
            buf = ""
        else:
            buf += c
        i += 1
    cells.append(buf.strip())
    return cells


def md_tables(region):
    """(見出しのセル, データの行の文字列のリスト) を返す。外枠の無い表も拾う。"""
    lines = region.splitlines()
    out, i = [], 0
    while i + 1 < len(lines):
        if "|" in lines[i] and "|" in lines[i + 1] and TABLE_SEP.fullmatch(lines[i + 1]):
            header = split_cells(lines[i])
            rows, j = [], i + 2
            while j < len(lines) and "|" in lines[j] and lines[j].strip():
                rows.append(lines[j])
                j += 1
            out.append((header, rows))
            i = j
        else:
            i += 1
    return out


def link_targets(text):
    """Markdown のリンク先（./ と #節 を外したもの）と、そのリンクがある「## 」の節の名前。
    コードブロック、コメント、行の中のコードにあるものは数えない。題つき、<> で囲んだ形、参照の形も読む。"""
    targets = {}
    plain = blank_inline_code(blank_code(text))
    section = ""
    for line in plain.split("\n"):
        h = re.match(r"^##[ \t]+(.+?)\s*$", line)
        if h:
            section = h.group(1)
        found = re.findall(r"\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)", line)
        found += re.findall(r"^\s*\[[^\]]+\]:\s*<?([^\s>]+)>?", line)
        for t in found:
            t = t.split("#", 1)[0]
            if t.startswith("./"):
                t = t[2:]
            targets.setdefault(t, set()).add(section)
    return targets


def looks_like_example(f, text):
    """例を置いたつもりのファイルか（名前、決まり文句、「例」の節、行頭の「型:」の行のどれか）。"""
    return ("example" in f.name.lower() or EXAMPLE_PHRASE in text or EXAMPLE_PHRASE_OUTSIDE in text
            or bool(example_regions(text, False)) or bool(LOOSE_DECL.search(text)))


def check_examples(name, path, skill_text, types, inputs, outputs, step_ids):
    """単位の埋めた例を見る（検査 12）。"""
    errors = []
    for f in sorted(path.rglob("*")):
        rel = f.relative_to(path).as_posix()
        if f.is_dir() and f.name == "examples":
            errors.append(f"{name}: {rel}: examples/ は作らない（例は references/ に置く）")
        elif f.is_file() and f.name.endswith("-example.md") and not rel.startswith("references/"):
            errors.append(f"{name}: {rel}: 例は references/ に置く")
    refs = path / "references"
    if not refs.is_dir():
        return errors
    targets = link_targets(skill_text)
    for f in sorted(refs.rglob("*.md")):
        text = blank_code(f.read_text(encoding="utf-8"))
        rel = f.relative_to(path).as_posix()
        where = f"{name}: {rel}"
        whole = f.name.endswith("-example.md")
        regions = example_regions(text, whole)
        if not regions:
            if "example" in f.name.lower() or EXAMPLE_PHRASE in text or EXAMPLE_PHRASE_OUTSIDE in text:
                errors.append(f"{where}: 例の範囲が取れない（ファイル名を <名前>-example.md にするか、見出しが「例」の節に置く）")
            continue
        sections = targets.get(rel)
        if not sections:
            errors.append(f"{where}: 例が SKILL.md からリンクされていない")
        elif not sections & {"入力", "出力"}:
            errors.append(f"{where}: 例へのリンクが、入力か出力の表の直後に無い")
        for part in regions:
            first, second = example_head(part)
            m = EXAMPLE_DECL.fullmatch(first)
            if not m:
                if LOOSE_DECL.match(first):
                    errors.append(f"{where}: 型の宣言の形が違う（行頭に半角の「型: 」）: {first.strip()[:40]}")
                else:
                    errors.append(f"{where}: 例の頭に型の宣言が無い")
                continue
            dm = re.fullmatch(r"(.+?)\s*(（.+）)?", m.group(1).strip())
            type_name, paren = dm.group(1).strip(), dm.group(2)
            if type_name == EXAMPLE_OUTSIDE:
                if not paren:
                    errors.append(f"{where}: 型の外の例に「（何の文書の例か）」が無い")
                if second.strip() != EXAMPLE_PHRASE_OUTSIDE:
                    errors.append(f"{where}: 型の外の例の宣言の次の行に、型の外の決まり文句が無い")
                if "原典の参照" not in inputs:
                    errors.append(f"{where}: 型の外の例は、原典の参照を入力に持つ単位に置く")
            else:
                if type_name not in types:
                    errors.append(f"{where}: 例の型「{type_name}」が型の一覧に無い")
                elif type_name not in outputs:
                    errors.append(f"{where}: 例の型「{type_name}」が単位の出力の表に無い")
                if second.strip() != EXAMPLE_PHRASE:
                    errors.append(f"{where}: 例「{type_name}」の宣言の次の行に決まり文句が無い")
            plain = blank_inline_code(part)
            if CHECKBOX.search(plain):
                errors.append(f"{where}: 例「{type_name}」にチェックボックスがある")
            for header, rows in md_tables(part):
                if header and header[0] not in ("欄", "項目") and len(rows) > 3:
                    errors.append(f"{where}: 例「{type_name}」の表の行が3つを超える: {' | '.join(header)[:40]}")
                for row in rows:
                    cells = split_cells(row)
                    if len(cells) != len(header):
                        errors.append(f"{where}: 例「{type_name}」の表の列の数が見出しと違う: {row.strip()[:50]}")
                    elif any(is_filler(c) for c in cells):
                        errors.append(f"{where}: 例「{type_name}」の表に空のセルか埋め草がある: {row.strip()[:50]}")
            for lm in re.finditer(r"^\s*[-*+]\s+[^:：\n|`]{1,30}[:：][ \t]*(.*)$", part, re.M):
                if is_filler(lm.group(1)) and lm.group(1).strip():
                    errors.append(f"{where}: 例「{type_name}」の箇条書きの値が埋め草: {lm.group(0).strip()[:50]}")
            for tok in sorted(set(re.findall(r"工程[ \t　]*[`「『]?([a-z][a-z0-9-]*)", part)) & step_ids):
                errors.append(f"{where}: 例「{type_name}」が工程の識別子 `{tok}` を書いている")
    return errors


def stray_examples(path):
    """プロファイルと dev-shared に置かれた例を探す。"""
    found = []
    for f in sorted(path.rglob("*")):
        rel = f.relative_to(path).as_posix()
        if f.is_dir() and f.name == "examples":
            found.append(f"{path.name}: {rel}: 例は単位の references/ に置く")
        elif f.is_file() and f.suffix == ".md" and rel.startswith("references/"):
            if looks_like_example(f, blank_code(f.read_text(encoding="utf-8"))):
                found.append(f"{path.name}: {rel}: 例は単位の references/ に置く")
    return found


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
    # 例が工程を名指ししていないかを見るために、全プロファイルの工程の識別子を集める
    step_ids = set()
    for path in profiles.values():
        for row in table_rows((path / "SKILL.md").read_text(encoding="utf-8"), "工程") or []:
            step_ids.update(re.findall(r"`([a-z][a-z0-9-]*)`", row[0]))
    for path in [*profiles.values(), SKILLS / SHARED]:
        errors.extend(stray_examples(path))

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
        errors.extend(check_examples(name, path, text, types, io["入力"], io["出力"], step_ids))
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
