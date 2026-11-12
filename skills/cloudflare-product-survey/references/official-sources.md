# 公式資料の引き方

- 確認日: 2026-11-12
- この一覧も古くなる。URL が 404 になったら、下の「製品の一覧」から引き直し、この一覧を直す。

## 1. どこに何があるか

| 知りたいこと | 入口 | 備考 |
| :--- | :--- | :--- |
| 製品の一覧 | `https://developers.cloudflare.com/directory/` | 製品名から各製品の文書へ |
| 文書全体の索引（機械向け） | `https://developers.cloudflare.com/llms.txt` | 製品ごとの `llms.txt` へのリンクが並ぶ |
| 製品ごとの索引 | `https://developers.cloudflare.com/<製品>/llms.txt` | 例: `/workers/llms.txt`。各ページの Markdown 版へのリンクが並ぶ |
| 制限 | `https://developers.cloudflare.com/<製品>/platform/limits/` | 例: `/workers/platform/limits/`、`/durable-objects/platform/limits/`。製品によって場所が違うので、索引で探す |
| 価格 | `https://developers.cloudflare.com/<製品>/platform/pricing/` | 例: `/workers/platform/pricing/`。同上 |
| 変更履歴 | `https://developers.cloudflare.com/changelog/` | 提供開始、ベータ、価格の変更の時期。製品ごとの changelog もある（例: `/workers/platform/changelog/`） |
| 構成の参考 | `https://developers.cloudflare.com/reference-architecture/` と `…/reference-architecture/diagrams/` | 大きな構成（CDN、セキュリティ等）と、アプリの構成図（serverless、storage、ai 等） |
| データの置き場の選び方 | `https://developers.cloudflare.com/workers/reference/storage/overview/` | ストレージ製品の使い分け |
| 学習の順序 | `https://developers.cloudflare.com/learning-paths/` | 製品ごとの入門コース |
| 障害の情報 | `https://www.cloudflarestatus.com/` | 稼働状況 |

## 2. Markdown 版で読む

エージェントが読むときは、HTML より Markdown 版が扱いやすい。

- ページの URL の末尾に `index.md` を付ける。例: `https://developers.cloudflare.com/workers/platform/limits/index.md`（`text/markdown` で返る）
- または、`index.md` を付けない URL に `Accept: text/markdown` の見出しを付けて取得する（製品ごとの `llms.txt` の冒頭に案内がある）。
- 出典として示す URL は、利用者が開ける HTML のページの URL にする。

## 3. いつ書き換わったかを追う

文書の原稿は GitHub の `cloudflare/cloudflare-docs`（既定のブランチは `production`）にある。

- ページの原稿は `src/content/docs/<製品>/…` にある。例: Workers の制限は `src/content/docs/workers/platform/limits.mdx`。変更履歴の原稿は `src/content/changelog/` にある。
- ページの更新の履歴は、GitHub の History か、`gh api "repos/cloudflare/cloudflare-docs/commits?path=<原稿のパス>"` で引ける。
- 過去のある時点の仕様を示す必要があるときは、出典に取得日に加えてコミット ID を書く。

## 4. ライセンスと表示

`cloudflare/cloudflare-docs` の README の「License and Legal Notices」による（2026-11-12 確認）。

- 文書などの中身は CC BY 4.0、コードは MIT License（`LICENSE-CODE`）。ただし「Except as otherwise noted」とあり、個別に別の条件が書かれたものはそれに従う。
- Cloudflare の名前・ロゴ・商標を使う権利は含まれない。
- 原文や図を写すときは、作者（Cloudflare とコントリビューター）、ライセンス名とリンク、元ページの URL、改変の有無を書く。要約と出典 URL だけなら、表示の負担は軽い。
- 公式ブログ（`blog.cloudflare.com`）はこのリポジトリに含まれない。ライセンスは確かめていないので、リンクと自分の言葉の要約だけにする。

## 5. 公式でない情報源

- Qiita・Zenn などのコミュニティ記事は、構成の型や製品の名前を見つける入口にだけ使う。仕様、上限、価格の根拠にしない（書かれた時点の情報で、ずれやすい）。
- 本文、図、コードは写さない。示すなら URL と、記事に出ている著者の表示名と、取得日だけにする。
- 有料記事は使わない。
