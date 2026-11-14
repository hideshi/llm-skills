# 根拠と変えたところ

プログラムやシェルから呼ばれる契約を設計する手順が、どの先行の手法に基づき、どこを変え、どこが独自の判断かを書く。手順そのものは SKILL.md が正本で、ここは読む人が元の考え方をたどるための別紙。

- 確かめた日: 2026-11-13
- 確かめた水準: 「原典を読んだ」「書誌と二次資料で確かめた」「未確認」

## 先行の手法

| 手順の箇所 | 手法 | 出典 | 確かめた水準 | 同じところ | 変えた・足したところ |
|---|---|---|---|---|---|
| 2・3・8・HTTP での例（操作、冪等性、状態コード） | HTTP セマンティクスと冪等キー | R. Fielding, M. Nottingham, J. Reschke 編『RFC 9110: HTTP Semantics』IETF、2022（https://datatracker.ietf.org/doc/rfc9110/ ）。M. Nottingham, R. Fielding『RFC 6585: Additional HTTP Status Codes』IETF、2012（https://datatracker.ietf.org/doc/rfc6585/ ）。J. Jena, S. Dalal, D. Tishkin『The Idempotency-Key HTTP Header Field』IETF ドラフト `draft-ietf-httpapi-idempotency-key-header`（draft-08、2026年10月、https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/ ） | 原典を読んだ（RFC 9110 §9.2.2、RFC 6585 §4、draft-08 §2 を 2026-11-13 に確認） | 読み取りや全体置換・削除を冪等とし、冪等でない操作を冪等キーで補い、その有効期限・保持期間を定めて公開する。状態コードを回復の動きに対応づける | HTTP だけでなく RPC、WebSocket、メッセージ、ライブラリ、CLI を含む共通手順にし、HTTP の具体を `references/http.md` へ分けた |
| 4・CLI での例（互換性の判定と廃止） | 寛容な読み手（Tolerant Reader）、並行変更（Parallel Change）、廃止通知 | Martin Fowler「TolerantReader」（https://martinfowler.com/bliki/TolerantReader.html 、2011）、Danilo Sato「ParallelChange」（https://martinfowler.com/bliki/ParallelChange.html 、2014）。S. Dalal, E. Wilde『RFC 9745: The Deprecation HTTP Response Header Field』IETF、2025（https://datatracker.ietf.org/doc/rfc9745/ ） | 原典を読んだ（TolerantReader、ParallelChange、RFC 9745 §2〜§4 を 2026-11-13 に確認） | 読み手側が未知の応答項目を許容し（Tolerant Reader）、非互換の変更は拡張・移行・縮小の3段に分け（Parallel Change）、廃止する旧版の応答で廃止予定（`Deprecation`）・案内文書リンク（`deprecation` link relation）を通知し、停止時期は `Sunset`（RFC 8594、RFC 9745 §4 が関係を規定）で示す | 応答項目の追加や任意入力の追加は互換を保ち、削除・改名・型変更・必須追加・CLI 旗の既定値変更・機械向け出力の形・終了コードの意味変更は壊す変更とする分類表に具体化した。呼び出し側が管理外にあるときの人の決定待ちを足した（下の独自の判断） |
| 5（一覧を返す操作） | 件数上限とカーソルによるページング | JJ Geewax『API Design Patterns』Manning、2021（第21章「Pagination」） | 書誌と二次資料で確かめた（本文は未読） | 一覧の1回の件数に上限を設け、続きの取得には続きを指す値（カーソル）を用いる | 返す項目を、呼び出し側が必要とする項目と過不足なく突き合わせる確認を足した |
| 6（計算済みの値を受け取るとき） | サーバー側での再検証 | MITRE「CWE-602: Client-Side Enforcement of Server-Side Security」（https://cwe.mitre.org/data/definitions/602.html ） | 原典を読んだ（2026-11-13 に定義本文を確認） | 呼び出し側から送られた値をそのまま信じて保存せず、サーバー側の規則で検証する | 不一致のときに黙って計算し直して置き換えず弾くと決め、規則の正本を1か所に置く指針を足した（下の独自の判断） |
| 8・HTTP での例（失敗の返し方） | 機械が分岐できる構造化エラー応答 | M. Nottingham, E. Wilde, S. Dalal『RFC 9457: Problem Details for HTTP APIs』IETF、2023（RFC 7807 を置換、https://datatracker.ietf.org/doc/rfc9457/ ） | 原典を読んだ（§1・§3 を 2026-11-13 に確認） | 呼び出し側が分岐に使える安定したコードと詳細を構造化して返す | 特定のメディア型や項目名を強制せず、安定したコード・相関識別子・項目ごとの誤りを備える形に一般化し、エラーの種類の分け方は別工程へ委ねた |
| CLI での例（全体） | CLI ガイドライン | Aanand Prasad, Ben Firshman, Carl Tashian, Eva Parish（Design: Mark Hurrell）『Command Line Interface Guidelines』（https://clig.dev/ 、発行年記載なし） | 原典を読んだ（2026-11-13 に本文を確認） | 結果を標準出力、進み具合・警告・誤りを標準エラーに出し、成功を 0、失敗を非 0 として主要な失敗の形に対応づける。`--dry-run` や `--json` を用意し、秘密を引数で受け取らない | 使い方の誤りを 2（`references/cli.md`）、一部失敗・入力内容の誤り・一時障害・恒久障害の終了コードを回復の動きに対応づけて契約化し、人向け文言は契約外と明記した |

## 独自の判断

| 決まり | 理由 | 確かめ方 |
|---|---|---|
| 呼び出し側が自分の管理の外にあるなら、互換を壊す変更は「人の決定待ち」にする | 管理外の呼び出し元は同じ変更で直せず、廃止期間や影響の引き受けを技術判断だけで決められないため | 承認待ちで止めた変更のうち人の決定で計画変更・代替移行になった割合と、承認を経て互換判定を進めた後に後続のレビュー結果で呼び出し側破損が見つかった件数を比べ、判断の線引きを見直す |
| 計算済みの値が不一致のとき、黙って再計算して置き換えず弾く | 利用者に見せた値と別の値で確定する事故や、改ざんの看過を防ぐため | 計算不一致で弾いた要求のうち正当な端数差・版差で仕様調整になった誤拒否件数と、検証の記録を通過後に数値の食い違いが起きた件数を比べ、再検証の許容差と境界を見直す |
| エラーの一覧が入力に無いときは、エラーの設計が要ることを人への問いにする | 契約ごとに独自のエラー分類が生まれて文言や記録と食い違うのを防ぐため | 後続で契約ごとの独自エラー分類が増えた件数を記録し、見落としが多ければ未記入時の問い返し方を見直す |
| その場で結果を返さない操作の契約項目を4点（受付応答・状態照会・完了通知・冪等キー）に絞る | 裏の実行基盤（キューやジョブ）の設計に踏み込まず、呼び出し側との境界だけを揃えるため | 非同期境界で状態不整合や二重実行が起きた件数を記録し、4点以外の項目が要る事象が出れば項目数を見直す |
| 既存の契約の所在が分からないときは、互換の判定を「未確認」にして人に確かめる | 推測で互換を保てると判断し、既存の呼び出し側を壊すのを防ぐため | 確認事項の記録へ出した未確認項目のうち既存の呼び出し元が見つかった割合と、所在ありとして変更した後に後続のレビュー結果で破損が見つかった件数を比べ、未確認時の進行基準を見直す |

## 改善の記録

- 2026-11-13: 初版。先行の手法6つと独自の判断5つを書いた。
- 2026-11-13: Idempotency-Key ドラフトの版・年月（draft-08、2026年10月）と『Command Line Interface Guidelines』の著者・デザイン表記を一次情報で確認して明確化し、Tolerant Reader と提供側互換ルールの関係を整理した。
- 2026-11-13: 公開 Web 原典（RFC 9110/6585/9457/9745、Idempotency-Key draft-08、TolerantReader、ParallelChange、CWE-602、clig.dev）を確認して水準を更新し（draft-08 §2.3 に含まれる保持期間の位置を「同じところ」へ修正）、独自の判断5件を反証可能な確かめ方へ改めた。
- 2026-11-13: 独立レビューを受け、POSIX を別行へ分離、`clig.dev` の年表記・値 2 の位置・RFC 9745 §2〜§4 と互換分類表の位置を「変えた・足したところ」へ正し、計算不一致判定などの確かめ方に誤拒否・過剰停止側の視点を補った。
- 2026-11-13: 独立レビューを受け、旧版側での `Deprecation` 通知の向きと `Sunset`（RFC 8594 と RFC 9745 §4）の関係を正し、SKILL.md に言及の無い未確認 POSIX 行を外し、確かめ方の違反前提表現と「手数」表現を修正した。
