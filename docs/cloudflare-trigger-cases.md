# Cloudflare の群の起動の試験

一言の依頼ごとに、起動してほしいスキルを並べる。Cloudflare の群のスキルの description を変えたとき、または近い言い方の description を持つスキルを足したときに、この表で起動を確かめ直す。

試験の定義の正本は [tests/trigger/cases.json](../tests/trigger/cases.json) で、この表は ID を合わせた人向けの説明（依頼文と合格とするスキルの正確な定義は cases.json）。流し方と判定は [tests/trigger/README.md](../tests/trigger/README.md) を見る。

## 試験の条件

- 試験用のリポジトリは、試験の仕組み（スクリプト、ログ）や、ほかの作業フォルダと別の場所に置く。移行元の旧リポジトリは同時に開かない。
- リポジトリの全スキルを、リンクでなく実体で `.claude/skills` だけに置く（ほかの群との取り合いも見るため）。
- 各回の前に、リポジトリを初期の状態に戻す。1件ずつ新しいセッションで起動し、書き込みと外部への通信の道具は止めておく。
- 利用者の記憶や計画書が読み込まれない場所で流し、ログで外の参照が無いかを確かめる。
- 試験用のリポジトリには、依頼の前置きが指す文書（要件のメモ、制約シート）と、小さな実装を置く。前置きと置いた文書が食い違わないようにする。
- 最初に使ったスキルが期待どおりなら合格とする。

## 依頼と期待するスキル

| ID | 依頼の例 | 状況 | 期待するスキル |
|---|---|---|---|
| CF1 | 「Workers の CPU 時間の上限は？」 | 一問一答 | `cloudflare-product-survey` |
| CF2 | 「Cloudflare でメールアドレスを持てる？」 | 一問一答 | `cloudflare-product-survey` |
| CF3 | 「この要件を Cloudflare で組むための制約を整理して」 | 要件のメモがある | `cloudflare-requirements-framing` |
| CF4 | 「この制約シートで構成案を出して」 | Cloudflare 向けの制約シートがある | `cloudflare-architecture-advisor` |
| CF5 | 「ローカル LLM を選びたい」 | — | 群1（`model-requirements-analyzer` など）。Cloudflare の群は起動しない |
| CF6 | 「Jev の監視基盤を Cloudflare で」 | — | `jev-monitoring-platform` |
| CF7 | 「今どう動いているか調べて」 | 自分たちの実装がある | `dev-current-behavior-survey`（`cloudflare-product-survey` と取り合わない） |
| CF8 | 「現状の仕様を洗い出して」 | 自分たちの実装がある | `dev-current-behavior-survey`（同上） |

## 実施の記録

下の表の 2026-11-12 の行は、試験を Go に移す前に手で流したもの。隔離した場所で流したが、利用者の設定（言語の指定、フック）、利用者単位のスキルとプラグイン、MCP は読み込まれていた（Go に移した後のレビューで判明）。参考として残し、判断には `tests/trigger` で流した結果を使う。

| 日付 | 道具とモデル | 結果 | 直したこと |
|---|---|---|---|
| 2026-11-12 | Claude Code（Sonnet 5.5）、全37本、隔離した場所 | 8件とも、期待するスキルを最初に使った。CF6 の `jev-monitoring-platform` は Cloudflare の群と取り合わず、CF7・CF8 は `cloudflare-product-survey` に取られなかった。外の参照なし | なし |
| 2026-11-12 | Claude Code（Haiku 5.5）、同じ条件 | CF1〜CF4 と CF6 は期待どおり（CF4 は構成案の単位の後に裏取りの単位も使った）。CF5、CF7、CF8 はスキルを使わなかったが、Cloudflare の群も起動しなかった。CF5 では端末の性能を調べようと `/proc` の下を読みにいったが、権限で拒否された（試験の仕組みとは関係しない） | なし。Haiku 相当が一言の依頼でスキルを使わないことがあるのは、開発作業の群の試験と同じ傾向 |
| 2026-11-13 | Claude Code（Sonnet 5.5 と Haiku 5.5）、`tests/trigger` の Go の試験（各3回）。利用者の設定・フック・利用者単位のスキル・MCP を読まない隔離 | Sonnet は24回とも合格。Haiku は24回中22回が合格し、CF5 と CF6 で1回ずつスキルを使わなかった。Cloudflare の群が誤って起動した回は無い。外の中身を読んだ回0件 | なし |
