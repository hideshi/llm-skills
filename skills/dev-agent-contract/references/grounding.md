# 根拠と変えたところ

AI エージェントが呼ぶ道具の契約を設計する手順が、どの先行の手法や仕様に基づき、どこを変え、どこが独自の判断かを書く。手順そのものは SKILL.md が正本で、ここは読む人が元の考え方をたどるための別紙。

- 確かめた日: 2026-11-13
- 確かめた水準: 「原典を読んだ」「書誌と二次資料で確かめた」「未確認」

## 先行の手法

| 手順の箇所 | 手法 | 出典 | 確かめた水準 | 同じところ | 変えた・足したところ |
|---|---|---|---|---|---|
| 1、INV-1・3・6〜9・11・15、`references/mcp/spec-tracking.md`, `authorization.md`, `write-safety.md` | MCP 仕様および OAuth 2.0 保護リソース仕様 | Model Context Protocol『Model Context Protocol Specification』（版 `2026-07-28`、https://modelcontextprotocol.io/specification/2026-07-28/ ）。M. B. Jones, P. Hunt, A. Parecki『RFC 9728: OAuth 2.0 Protected Resource Metadata』IETF、2025（https://datatracker.ietf.org/doc/rfc9728/ ） | 原典を読んだ（MCP `2026-07-28` は `references/mcp/spec-tracking.md` で 2026-11-11 に照合済み。RFC 9728 §2・§5 を 2026-11-13 に確認） | 注釈を信頼しない（INV-1）、役割で可視・呼出範囲を絞る（INV-3）、401/403・`insufficient_scope`・PRM・宛先検証と中継禁止（INV-6）、接続の開始と終了を管理する（INV-7）、要求ごとの能力宣言と `elicitation` / MRTR（INV-8）、状態の完全性保護と1回限り強制（INV-9）、form モードの秘密要求禁止（INV-11）、回数制限（INV-15）の `[仕様]` 要件をそのまま採る | MCP 固有の仕組みを不変条件（INV-1〜16）として抽象化し、版追従の手順を `spec-tracking.md` に分離した。また read/write スコープ分離、どの方式でも秘密要求禁止、確認状態の認証扱い禁止などを `[設計]` として厳格化した |
| INV-4・5・8〜11、「守れることと守れないこと」 | プロンプトインジェクションおよび過剰なエージェンシーへの多層防御 | OWASP『OWASP Top 10 for Large Language Model Applications 2025』（2025、LLM01: Prompt Injection https://genai.owasp.org/llmrisk/llm01-prompt-injection/ 、LLM06: Excessive Agency https://genai.owasp.org/llmrisk/llm062025-excessive-agency/ ） | 原典を読んだ（2026-11-13 に LLM01・LLM06 ページを確認） | 外部データに混入した指示で意図しないツール呼び出しが起きうる前提に立ち、返す内容の最小化と上限設定（INV-4）・構造分離（INV-5）と書き込み前の人間確認を組み合わせる | LLM が読んだ内容に従うこと自体は止められない限界を明記し、サーバーが守る範囲を「確認なしに書き込ませないこと」に限定して保証の宣言に書く決まりにした |
| INV-9・10、`references/mcp/write-safety.md` 3・4節 | 楽観的同時実行制御（OCC）と TOCTOU 競合の防止 | H. T. Kung, J. T. Robinson「On Optimistic Methods for Concurrency Control」ACM TODS 6(2), 1981。Matt Bishop, Michael Dilger「Checking for Race Conditions in File Accesses」Computing Systems 9(2), 1996（MITRE CWE-367） | 書誌と二次資料で確かめた（本文は未読） | 確認時点の対象状態のダイジェストを保持し、保存時にトランザクション内または原子的更新で再照合して途中の割り込み変更を拒む | 更新日時の精度に頼らず保存内容全体のダイジェストを取り、利用者・クライアント・認可世代・単位設定世代・ツール・引数を HMAC/AEAD で結びつけてサーバー記録で1回限りを強制する仕組みを足した |
| INV-13、`references/mcp/implementation.md` 4節 | インターネット上の日時表記（RFC 3339） | G. Klyne, C. Newman『RFC 3339: Date and Time on the Internet: Timestamps』IETF、2002（https://datatracker.ietf.org/doc/html/rfc3339 ） | 原典を読んだ（§5.6 を 2026-11-13 に確認） | 時差付きの日時表記を用いる | 読み取りで返す書式を1つに固定してそのまま書き戻せるようにし、時差なし・範囲外を拒否して変換を共通関数1か所に集約する規約を足した |
| INV-14、`references/mcp/implementation.md` 5節・`testing.md` 3節 | ログへの機微情報混入の防止 | MITRE「CWE-532: Insertion of Sensitive Information into Log File」（https://cwe.mitre.org/data/definitions/532.html ）。OWASP「Logging Cheat Sheet」（https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html ） | 原典を読んだ（2026-11-13 に両原典を確認） | トークン・認証情報・リクエスト本文や引数など機微な値をログに出さず、固定の分類だけを記録する | 未知のツール名や生のエラー文・panic 内容も除外し、一意の目印文字列を流してアクセスログを含む全ログに現れないことを確かめるカナリア試験を必須にした |
| INV-16、`references/mcp/authorization.md` 1節 | 完全調停とオブジェクトレベル認可（BOLA/IDOR 対策） | Jerome H. Saltzer, Michael D. Schroeder「The Protection of Information in Computer Systems」Proceedings of the IEEE 63(9), 1975（https://web.mit.edu/Saltzer/www/publications/protection/Basic.html ）。OWASP「OWASP API Security Top 10 2023 — API1:2023 Broken Object Level Authorization」（https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/ ） | 原典を読んだ（2026-11-13 に両原典を確認） | 道具専用の簡易判定を作らず、既存の画面と同じ1件ごとの所有・所属判定と絞り込みをすべての読み書き道具で通す | 見せる役割を許可の表で許された主体より広げない規則と、認可の世代による停止・再開時のトークンおよび確認の即時失効を組み合わせた |
| `references/mcp/testing.md` 2節 | ミューテーションテストの考え方 | R. A. DeMillo, R. J. Lipton, F. G. Sayward「Hints on Test Data Selection: Help for the Practicing Programmer」IEEE Computer 11(4), 34–41, 1978（DOI 10.1109/C-M.1978.218136） | 書誌と二次資料で確かめた | 守りを意図的に外したときに試験が落ちるかで、試験が本当に守りを確かめているかを見る | 道具による網羅的な変異は求めず、INV-1, 2, 3, 6, 8, 9, 10, 16 など主要な守りを手で外して試験が落ちることを記録する運用にした |

## 独自の判断

| 決まり | 理由 | 確かめ方 |
|---|---|---|
| `[仕様]` と `[設計]` を書き分け、不変条件 ID（INV-1〜16）を欠番管理にする | 仕様の義務とこの単位の厳格化を混ぜず、仕様改定時も不変条件の追跡性を保つため | 仕様改定時に要件の取り違えや代替策の抜けで差し戻された件数を記録し、欠番管理と書き分けの規則を見直す |
| 分類を省いた道具は書き込み（`WRITE`）扱い、機能・単位は既定無効にする（INV-1, 2） | 設定漏れや分類忘れが無確認の書き込み公開につながる事故をフェイルセーフで防ぐため | 検証の記録で起動時検査による正当な道具の誤遮断件数と未分類露出の差し戻し件数を数え、既定無効の粒度を見直す |
| 見えないロールの呼び出し応答を、存在しない道具の応答（値・文言）に完全に揃える（INV-3） | 応答の違いから管理用の道具の有無や権限構成を推測されるのを防ぐため | 検証の記録で応答の食い違い指摘件数と正規の呼び出し側が障害切り分けに詰まった問い合わせ件数を数え、秘匿範囲を見直す |
| 確認の文をサーバーが作り、入力を引用で分離し、何を・どこへ・どう変えるかを先頭に置く（INV-11） | エージェントによる誘導的な要約や、クライアントでの長文折りたたみで利用者が変更内容を見落とすのを防ぐため | 確認文の先頭配置と引用分離を行っても折りたたみ超過や表現不足で誤承認・質問返しが起きた件数を検証の記録・確認事項の記録で数え、構成を見直す |
| 自動承諾クライアントや人の読み飛ばしをサーバーでは見分けられないと明記し、保証の宣言に書く | サーバーが証明できない人の確認責任まで技術的に保証したように誤認させないため | 運用や審査でサーバー保証範囲の誤認や責任の押し付けが起きた件数を記録し、守らない範囲3点の記述を見直す |
| 書き込みは既存の画面と同じ検査・保存経路を通り（INV-12）、未分離なら振る舞いを変えず先に切り出す | 道具専用の保存経路による検査漏れや保存後フックの欠落を防ぐため | 検証の記録で既存画面との結果不一致件数と、先切り出しによる設計変更の差し戻し件数を数え、統合境界の基準を見直す |

## 改善の記録

- 2026-11-13: 初版。先行の手法7つと独自の判断6つを書いた。
- 2026-11-13: MCP `2026-07-28` の確認水準を `spec-tracking.md` の原文照合記録に合わせて「原典を読んだ」に更新し、参照資料に無い RFC 6750・8707 を除いて出典数を規約内に抑え、INV-3・INV-4・INV-7 の対応を明記した。
- 2026-11-13: 公開 Web 原典（RFC 9728/3339、OWASP LLM01/06・Logging・API1、CWE-532、Saltzer & Schroeder Basic.html）を確認して水準と URL を補い、存在確認型だった独自の判断2件の確かめ方を反証可能な形へ改めた。
- 2026-11-13: 独立レビューを受け、RFC 9728 の確認節へ `§5` を追記し、確認文（INV-11）の確かめ方を実測困難な対照比較から運用記録での誤承認・質問返し計測へ改めた。
- 2026-11-13: 独立レビューを受け、「運用記録」を型の一覧にある「検証の記録・確認事項の記録」へ直し、確認型で残っていた「…か試験で見る」3件を見直し条件つき指標へ改めた。
