#!/usr/bin/env python3
"""根拠の別紙（references/grounding.md）にある URL と DOI の到達を確認する任意スクリプト。

ネットワーク接続がある環境で、リンク切れや Crossref 上の DOI 実在を手動またはレビュー時に確認する。
通常のオフライン検査（scripts/check_dev_skills.py）からは切り離している。

使い方: python3 -I scripts/check_grounding_links.py [リポジトリのルート]
"""
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
SKILLS = ROOT / "skills"
USER_AGENT = "llm-skills-grounding-link-check/1.0"


def fetch_status(url, timeout=10):
    """URL に対して HEAD（不可時は GET）で HTTP ステータスコードまたはエラー文字列を返す。"""
    for method in ("HEAD", "GET"):
        req = urllib.request.Request(url, method=method, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.status, None
        except urllib.error.HTTPError as e:
            if method == "HEAD" and e.code in (403, 405, 501):
                continue
            return e.code, str(e.reason)
        except Exception as e:
            return None, str(e)
    return None, "unknown"


def check_crossref_doi(doi, timeout=10):
    """Crossref API で DOI の実在と題名を取得する。未登録時は doi.org にフォールバックする。"""
    api_url = f"https://api.crossref.org/works/{urllib.parse.quote(doi, safe='/')}"
    req = urllib.request.Request(api_url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            titles = data.get("message", {}).get("title") or []
            return True, titles[0] if titles else "(title missing)"
    except urllib.error.HTTPError as e:
        if e.code == 404:
            status, reason = fetch_status(f"https://doi.org/{doi}", timeout=timeout)
            if status and 200 <= status < 400:
                return True, f"(doi.org HTTP {status}; Crossref 404)"
            return False, f"HTTP {e.code} / doi.org {status or reason}"
        return False, f"Crossref HTTP {e.code}"
    except Exception as e:
        return False, str(e)


def extract_dois(text):
    """文中の DOI 文字列を抽出する。括弧入り DOI を壊さず、外側の閉じ括弧だけ除く。"""
    dois = []
    for raw in re.findall(r"DOI[:\s]*([^\s（）、。,→`]+)", text):
        while raw.endswith(")") and raw.count(")") > raw.count("("):
            raw = raw[:-1]
        if raw:
            dois.append(raw)
    return dois


def main():
    files = sorted(SKILLS.glob("dev-*/references/grounding.md"))
    urls, dois = {}, {}
    for p in files:
        unit = p.parent.parent.name
        # 改善の記録には修正前の古い DOI/URL を書くことがあるため除外する
        text = p.read_text(encoding="utf-8").split("## 改善の記録", 1)[0]
        for url in re.findall(r"https?://[^\s）)）、。>`]+", text):
            urls.setdefault(url, set()).add(unit)
        for doi in extract_dois(text):
            dois.setdefault(doi, set()).add(unit)

    failures = 0
    print(f"DOI {len(dois)}件、URL {len(urls)}件を確認します。")

    for doi in sorted(dois):
        ok, info = check_crossref_doi(doi)
        mark = "OK" if ok else "NG"
        if not ok:
            failures += 1
        units_str = ", ".join(sorted(dois[doi]))
        print(f"{mark} DOI {doi} [{units_str}]: {info}")

    for url in sorted(urls):
        status, err = fetch_status(url)
        ok = status is not None and 200 <= status < 400
        mark = "OK" if ok else "NG"
        if not ok:
            failures += 1
        units_str = ", ".join(sorted(urls[url]))
        detail = f"HTTP {status}" if status is not None else err
        print(f"{mark} URL {url} [{units_str}]: {detail}")

    print(f"完了: 失敗 {failures}件")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
