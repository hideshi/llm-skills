#!/usr/bin/env python3
"""専門用語の添え方を検査する（試行中。指摘を表示するだけで、落とさない）。

docs/terms.md の対応の表にある専門用語が、「対象」のスキルの各ファイルで初めて出た所で、
「平易な語（専門用語）」の形になっているかを見る。同じ添え書きが2回以上あるときも指摘する。
数え方は docs/terms.md の「決まり」のとおり。

- SKILL.md は、front matter の description と本文を別に数える。references/ と templates/ の
  各 md ファイルは、それぞれ別に数える。
- 数えないもの: フェンスで囲んだコードブロック、バッククォートで囲んだ部分、鉤括弧（「」）の中、
  リンクと素の URL、HTML のコメント。
- 英字の専門用語は、全角と半角、空白の数、表で小文字の字の大文字小文字を区別しない
  （Rebase も rebase と数える）。表で大文字の字は、大文字のときだけ数える（npm ci は CI と数えない）。
  前後に英字かハイフンが続く所（CIDR、pre-rebase など）は数えない。
- 見ないもの: 表に無い語や形、添えた後の書き方、製品や規格の名前。

使い方: python3 -I scripts/check_terms.py [--strict] [リポジトリのルート]
  --strict を付けると、指摘があるとき終了コード1で終わる（試行の後に使う予定）。
"""
import fnmatch
import re
import sys
from pathlib import Path

USAGE = "使い方: python3 -I scripts/check_terms.py [--strict] [リポジトリのルート]"


def parse_args(argv):
    strict = False
    rest = []
    for a in argv:
        if a == "--strict":
            strict = True
        elif a.startswith("-"):
            print(f"知らない引数: {a}\n{USAGE}")
            sys.exit(2)
        else:
            rest.append(a)
    if len(rest) > 1:
        print(USAGE)
        sys.exit(2)
    root = Path(rest[0]).resolve() if rest else Path(__file__).resolve().parent.parent
    return strict, root


def section(text, title):
    """「## 題」の節の中身を返す（次の「## 」の手前まで）。"""
    m = re.search(r"^## " + re.escape(title) + r"[ \t]*\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    return m.group(1) if m else ""


def table_rows(body):
    """表の行を、欄の並びとして返す（見出しの行と区切りの行は除く）。"""
    rows = []
    lines = [ln for ln in body.splitlines() if ln.strip().startswith("|")]
    for ln in lines[2:]:
        rows.append([c.strip() for c in ln.strip().strip("|").split("|")])
    return rows


def load_config(path):
    """対応の表、対象、例外を読む。"""
    text = path.read_text(encoding="utf-8")
    pairs = [(r[0], r[1]) for r in table_rows(section(text, "対応の表")) if len(r) >= 2 and r[0] and r[1]]
    targets = re.findall(r"^-\s*`([^`]+)`", section(text, "対象"), re.M)
    exceptions = {(r[0], r[1]) for r in table_rows(section(text, "例外")) if len(r) >= 2}
    return pairs, targets, exceptions


FULLWIDTH = {c: c - 0xFEE0 for c in range(0xFF10, 0xFF5B) if chr(c).isalnum()}


def blank(match):
    """一致した所を、同じ長さの空白に置き換える（位置と行を保つ）。"""
    return re.sub(r"[^\n]", " ", match.group(0))


def blank_quotes(text, limit=400):
    """鉤括弧（「」）の中を、入れ子と改行を含めて空白にする。閉じが遠すぎるものは触らない。"""
    out = list(text)
    stack = []
    for i, ch in enumerate(text):
        if ch == "「":
            # 閉じないまま遠くなった開きは捨てる（後ろの正しい鉤括弧を数えなくするため）
            stack = [s for s in stack if i - s <= limit]
            stack.append(i)
        elif ch == "」" and stack:
            start = stack.pop()
            if not stack and i - start <= limit:
                for j in range(start, i + 1):
                    if out[j] != "\n":
                        out[j] = " "
    return "".join(out)


def clean(text):
    """数えない所を空白にする。"""
    text = re.sub(r"<!--.*?-->", blank, text, flags=re.S)
    text = re.sub(r"^([ \t]*)(`{3,}|~{3,}).*?^\1\2[`~]*[ \t]*$", blank, text, flags=re.S | re.M)
    text = re.sub(r"(`+)(?!`).+?(?<!`)\1(?!`)", blank, text)
    text = re.sub(r"!?\[[^\]\n]*\]\([^)\n]*\)", blank, text)
    text = re.sub(r"https?://[^\s)）」>]+", blank, text)
    return blank_quotes(text)


def units(path):
    """数える単位ごとに、(名前, 文, ファイルの中の始まりの行番号) を返す。"""
    text = path.read_text(encoding="utf-8")
    lines = text.split("\n")
    first = next((i for i, ln in enumerate(lines) if ln.strip()), None)
    if path.name != "SKILL.md" or first is None or lines[first].strip() != "---":
        return [("", text, 1)]
    end = next((i for i in range(first + 1, len(lines)) if lines[i].strip() == "---"), None)
    if end is None:
        return [("", text, 1)]
    out = []
    for i in range(first + 1, end):
        m = re.match(r"description:[ \t]*(.*)$", lines[i])
        if not m:
            continue
        value = m.group(1)
        block = []
        j = i + 1
        while j < end and (lines[j].startswith((" ", "\t")) or not lines[j].strip()):
            block.append(lines[j])
            j += 1
        if re.fullmatch(r"[>|][+-]?[0-9]?\s*", value):
            out.append(("description", "\n".join(block), i + 2))
        else:
            out.append(("description", "\n".join([value] + block), i + 1))
        break
    out.append(("本文", "\n".join(lines[end + 1:]), end + 2))
    return out


def term_pattern(term):
    """専門用語を探す正規表現。英字の語は空白の数を区別せず、前後に英字かハイフンが続く所は数えない。"""
    if re.fullmatch(r"[A-Za-z0-9 +.\-]+", term):
        body = r"\s+".join(re.escape(w) for w in term.split())
        return re.compile(r"(?<![A-Za-z\-])" + body + r"(?![A-Za-z\-])", re.I)
    return re.compile(re.escape(term))


def same_case(found, term):
    """表で大文字の字は、大文字のときだけ当たりにする（npm ci を CI と数えないため）。"""
    letters = [c for c in term if c.isalpha()]
    got = [c for c in found if c.isalpha()]
    return all(g.isupper() for t, g in zip(letters, got) if t.isupper())


def check_unit(text, plain, term):
    """指摘を (行番号, 文) で返す。行番号は単位の中の番号。"""
    cleaned = clean(text).translate(FULLWIDTH)
    pat = term_pattern(term)
    found = [m for m in pat.finditer(cleaned) if same_case(m.group(0), term)]
    if not found:
        return []
    good = re.compile(re.escape(plain) + r"（" + pat.pattern + r"）", pat.flags)
    findings = []
    m = found[0]
    head = cleaned.rfind(plain + "（", 0, m.start())
    ok = head >= 0 and good.match(cleaned, head) and head + len(plain) + 1 == m.start()
    if not ok:
        findings.append((cleaned.count("\n", 0, m.start()) + 1,
                         f"「{term}」の初出が「{plain}（{term}）」の形でない"))
    dups = list(good.finditer(cleaned))
    if len(dups) > 1:
        findings.append((cleaned.count("\n", 0, dups[1].start()) + 1,
                         f"「{plain}（{term}）」の添え書きが2回以上ある"))
    return findings


def main():
    strict, root = parse_args(sys.argv[1:])
    terms_path = root / "docs" / "terms.md"
    if not terms_path.exists():
        print(f"docs/terms.md が無い（ルート: {root}）")
        return 2
    if not (root / "skills").is_dir():
        print(f"skills/ が無い（ルート: {root}）")
        return 2
    pairs, targets, exceptions = load_config(terms_path)
    files = []
    for skill in sorted(p for p in (root / "skills").iterdir() if p.is_dir()):
        if not any(fnmatch.fnmatchcase(skill.name, t) for t in targets):
            continue
        for p in sorted(skill.rglob("*.md")):
            rel = p.relative_to(skill).parts
            if rel == ("SKILL.md",) or rel[0] in ("references", "templates"):
                files.append(p)
    findings = []
    for path in files:
        rel = path.relative_to(root).as_posix()
        for unit, text, start in units(path):
            for plain, term in pairs:
                if any(t == term and fnmatch.fnmatchcase(rel, f) for f, t in exceptions):
                    continue
                for line, msg in check_unit(text, plain, term):
                    where = rel + (f"（{unit}）" if unit else "")
                    findings.append(f"{where}:{start + line - 1}: {msg}")
    for f in findings:
        print("指摘", f)
    print(f"専門用語 {len(pairs)}、対象 {', '.join(targets)}、ファイル {len(files)}、指摘 {len(findings)}（試行中。落とさない）")
    return 1 if (strict and findings) else 0


if __name__ == "__main__":
    sys.exit(main())
