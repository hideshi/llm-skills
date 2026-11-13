# 開発リポジトリへの導入

このスキルは、作業中のアプリの開発リポジトリへ導入し、振り返りで育てた個人用スキルと並べて使う。このファイルは導入する人と、正本・導入先の対応を確かめるエージェントが読む。

## 配置先

パスの末尾に `post-task-retrospective/` を置く。2026 年 10 月に各ツールの公式ドキュメントで確認した配置先で、使う前に最新の公式情報を確かめる。

| ツール | 開発リポジトリ内 | ユーザー単位 |
|---|---|---|
| Claude Code | `.claude/skills/` | `~/.claude/skills/` |
| Codex | `.agents/skills/` | `~/.agents/skills/` |
| Cursor | `.agents/skills/` または `.cursor/skills/` | `~/.agents/skills/` または `~/.cursor/skills/` |
| Antigravity | `.agents/skills/` | ツールの版ごとの場所（公式を確認） |

四つのツールで使うなら `.agents/skills/` と `.claude/skills/` の二か所で足りる。Cursor は `.claude/skills/` も読むので、同名のスキルが二つ見えることがある。内容は同じに保つ。チームやリモート環境で使うなら、ユーザー単位ではなく開発リポジトリ内に置く。

llm-skills 自身の `.agent/skills/` と `codex/skills/` は、このリポジトリで以前から使っている配置。導入先のアプリでは上の表の場所を使う。

## コピーで導入する

`llm-skills` を取得したルートで実行する。スキルのフォルダー全体（`references/` を含む）と `LICENSE` を一緒にコピーし、アプリ自身の `LICENSE` は置き換えない。既存の導入があれば上書きせず、先に差分を確かめる。

macOS・Linux:

```bash
(
  set -eu
  src="$(pwd -P)/skills/post-task-retrospective"
  app="/absolute/path/to/application"
  [ -f "$src/SKILL.md" ] && [ -f LICENSE ] || { echo "llm-skills のルートで実行してください" >&2; exit 1; }
  [ -d "$app" ] || { echo "開発リポジトリが見つかりません: $app" >&2; exit 1; }
  app="$(cd "$app" && pwd -P)"
  [ "$app" != "$(pwd -P)" ] || { echo "llm-skills とは別の開発リポジトリを指定してください" >&2; exit 1; }
  for root in .agents/skills .claude/skills; do
    dest="$app/$root/post-task-retrospective"
    if [ -e "$dest" ] || [ -L "$dest" ]; then echo "既存の導入を確認してください: $dest" >&2; exit 1; fi
  done
  for root in .agents/skills .claude/skills; do
    mkdir -p "$app/$root"
    cp -R "$src" "$app/$root/post-task-retrospective"
    cp LICENSE "$app/$root/post-task-retrospective/LICENSE"
  done
)
```

Windows（PowerShell。WSL2 は不要）:

```powershell
& {
  $ErrorActionPreference = 'Stop'
  $root0 = (Get-Location).ProviderPath
  $src = Join-Path $root0 'skills\post-task-retrospective'
  $app = 'C:\path\to\application'
  if (-not (Test-Path -LiteralPath (Join-Path $src 'SKILL.md') -PathType Leaf) -or
      -not (Test-Path -LiteralPath (Join-Path $root0 'LICENSE') -PathType Leaf)) { throw 'llm-skills のルートで実行してください' }
  if (-not (Test-Path -LiteralPath $app -PathType Container)) { throw "開発リポジトリが見つかりません: $app" }
  $app = (Get-Item -LiteralPath $app).FullName.TrimEnd('\')
  if ($app -eq $root0.TrimEnd('\')) { throw 'llm-skills とは別の開発リポジトリを指定してください' }
  foreach ($root in '.agents\skills', '.claude\skills') {
    $parent = Join-Path $app $root
    # 壊れたリンクも見つけるため、親フォルダーの一覧で確かめる
    if ((Test-Path -LiteralPath $parent) -and
        (Get-ChildItem -LiteralPath $parent -Force | Where-Object Name -eq 'post-task-retrospective')) {
      throw "既存の導入を確認してください: $parent\post-task-retrospective"
    }
  }
  foreach ($root in '.agents\skills', '.claude\skills') {
    $parent = Join-Path $app $root
    $dest = Join-Path $parent 'post-task-retrospective'
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    Copy-Item -Recurse -LiteralPath $src -Destination $dest
    Copy-Item -LiteralPath 'LICENSE' -Destination (Join-Path $dest 'LICENSE')
  }
}
```

更新するときは、取得した版と導入済みのコピーを比べ、アプリ側の独自の変更があれば統合する。初回の手順を再実行して上書きしない。削除されたファイルも確かめる。途中で失敗して半端なコピーが残ったら、中身を確かめてから消し、やり直す。

ほかの方式: シンボリックリンクは正本を一つに保てるが、変更が即座に届き、別のマシンや Windows では保たれないことがある。submodule は版を固定できるが、置くだけではスキルとして検出されず、配置先へのコピーかリンクが要る。

## 個人用スキルと一緒に導入する

```text
my-skills/                          # 個人用スキルの正本（独立した Git リポジトリ）
└── skills/clarify-acceptance/SKILL.md

application/
├── .agents/skills/
│   ├── post-task-retrospective/    # llm-skills から導入
│   └── clarify-acceptance/         # 個人リポジトリから導入
├── .claude/skills/                 # 同じスキルをコピー
├── docs/skill-sources.md           # 正本と導入先の対応記録
└── drafts/retrospective/           # 振り返りメモ（実行時に作られる）
```

名前は例。`post-task-retrospective` と同じ名前の個人用スキルを置かない。個人用スキルには、そのリポジトリのライセンスを保つ。

正本を追えるように、アプリ側に対応記録を置き、利用者の依頼やプロジェクトの指示でエージェントに参照させる。

```markdown
# スキルの導入元

- 個人用スキルの正本: /path/to/my-skills（取得したコミット: <ID>）
- 導入方式: コピー

| スキル名 | 正本内のパス | 導入先 |
|---|---|---|
| clarify-acceptance | skills/clarify-acceptance/ | .agents/skills/ と .claude/skills/ |

post-task-retrospective は llm-skills（取得元の URL: <URL>、コミット: <ID>）からの導入物で、個人用スキルとして更新しない。
```

チームで共有する記録に個人の絶対パスを載せたくなければ、個人向けの指示や Git 管理外の記録で補う。

## 出力の置き場所

| 内容 | 置き場所 |
|---|---|
| このスキルの導入コピー | `.agents/skills/` と `.claude/skills/`。振り返りの出力は書かない |
| 振り返りメモ | `drafts/retrospective/` か利用者が指定した場所。個人用なら `.gitignore` か `.git/info/exclude` で除外する |
| 新規・更新スキルの正本 | 利用者が指定した個人リポジトリ |
| 個人用スキルの導入コピー | 正本へ保存した後、承認された範囲で反映する |

## 読み込みの確認

開発リポジトリをツールで開き、新しいセッションでスキル一覧に `post-task-retrospective` があることを確かめる。呼び出しは、Claude Code では `/post-task-retrospective`、Codex では `$post-task-retrospective`、ほかのツールでは名前を添えて「今日はここまで。post-task-retrospective で振り返って」と頼む。

最初は小さな区切りで、メモが指定先に保存されること、このスキル自体が書き換えられないこと、スキル案の本文と対象パスが承認の前に示されること、個人リポジトリが未設定ならスキルを保存しないことを確かめる。
