# 開発スキル群の起動の試験

一言の依頼ごとに、起動してほしいスキルを並べる。スキルの description か振り分けの表を変えたら、この表で起動を確かめ直す。

試験の定義の正本は [tests/trigger/cases.json](../tests/trigger/cases.json) で、この表は ID を合わせた人向けの説明（依頼文と合格とするスキルの正確な定義は cases.json）。流し方と判定は [tests/trigger/README.md](../tests/trigger/README.md) を見る。下の「作った本人の流れ」（SA）は、まだ手で流している。

「期待する工程」に着けば合格とする。プロファイルを経ずに単位が直接選ばれても、同じ工程に着けば合格。工程は、各節の見出しに書いたプロファイルの工程の識別子で書く。見出しに2つ以上のプロファイルを書いた節では、そのすべてにある識別子だけを所属なしで書く。ほかのプロファイルの工程は「`dev-profile-…` の工程 `x`」と所属を書く。

試験は、dev- のスキルが置かれた作業場所で、1件ずつ新しいセッションを起動して行う。ほかの場所で起動すると、スキルが自動で読み込まれず、起動の試験にならない。書き込みの道具は止めておく。

新しいセッションでは「このセッションが変更を作った」状況を再現できない。依頼文の前置き（「いま自分で作り終えたところ」）は依頼者が作ったことしか示さないので、A・B・N・O・P でセッションが「自分は作っていない」と判断して工程 `review`（独立レビュー）に進んだ場合も、振り分けの決まりに沿っていれば合格とし、その旨を記録する。

## レビューの一巡（`dev-profile-review-cycle` の工程）

| ID | 依頼の例 | 状況 | 期待するスキル | 期待する工程 |
|---|---|---|---|---|
| A | 「この変更をレビューに出したい」 | このセッションが変更を作った | `dev-profile-review-cycle` → `dev-review-brief`（`dev-review-brief` を直接でも可） | `brief` |
| B | 「レビューして」 | このセッションが変更を作った直後 | `dev-profile-review-cycle` → `dev-review-brief` | `brief` |
| C | 「レビューして」＋レビュー依頼文を貼る | 他人の依頼文を受けた | `dev-review-conduct` | `review` |
| D | 「このPRを見て」 | 同僚の変更 | `dev-review-conduct` | `review` |
| E | 「指摘を直したので再レビューして」 | レビュー結果がある | `dev-profile-review-cycle` → `dev-review-brief` | `re-review-round` |
| F | 「もう終わりでいい？」「人に見せてよい？」 | 実装とレビューの後 | `dev-completion-audit`（プロファイル経由でも可） | `audit` |
| N | 「直したのでレビューして」 | 是正の後、前のレビュー結果が無い | `dev-profile-review-cycle` か `dev-profile-existing-system` → `dev-review-brief` | 依頼文を書く工程 |
| O | 「レビュー依頼文を書いて」 | このセッションが変更を作った | `dev-review-brief`（プロファイル経由でも可） | `brief` |
| P | 「別のモデルにレビューを頼みたい」 | このセッションが変更を作った | `dev-review-brief`（プロファイル経由でも可） | `brief` |
| Q | 「終わったか確認して」 | 実装とレビューの後 | `dev-completion-audit`（プロファイル経由でも可） | `audit` |
| X | 「PR #123 をレビューして」 | 同僚の変更 | `dev-review-conduct`（組み込みの差分レビューに取られたら記録する） | `review` |

## 既存システムの改修（`dev-profile-existing-system` の工程）

| ID | 依頼の例 | 状況 | 期待するスキル | 期待する工程 |
|---|---|---|---|---|
| H | 「この不具合を直して」 | 不具合の報告がある | `dev-profile-existing-system` → `dev-defect-fix`（`dev-defect-fix` を直接でも可） | `intake` → `fix` |
| I | 「もう直ってるはず」 | 再現しないと言われた不具合 | `dev-defect-fix`（プロファイル経由でも可） | `fix` |
| J | 「今どう動いているか調べて」 | 既存システムの機能 | `dev-current-behavior-survey`（プロファイル経由でも可） | `survey` |
| K | 「改修前に今の動きを固めておきたい」 | 既存システムの改修の前 | `dev-profile-existing-system` → `dev-regression-baseline`（直接でも可） | `baseline`（記録が無ければ `survey` から） |
| L | 「この共通処理を変えたい」 | 複数の機能が使う処理 | `dev-profile-existing-system` | `intake` → `survey` → `baseline` |
| M | 「期待値が変わったけどテストを直していい？」 | 回帰の基準が落ちた | `dev-regression-baseline`（プロファイル経由でも可） | `baseline-update` |
| R | 「もう閉じていい？」 | 是正とレビューの後 | `dev-completion-audit`（プロファイル経由でも可） | `audit` |
| S | 「現状の仕様を洗い出して」 | 既存システムの機能 | `dev-current-behavior-survey`（プロファイル経由でも可） | `survey` |
| T | 「既存システムを改修したい」 | 動いているシステム | `dev-profile-existing-system` | `intake` |
| U | 「既存の動きを壊さずに直したい」 | 動いているシステム | `dev-profile-existing-system` か `dev-regression-baseline` | `intake` → `survey` → `baseline` |
| V | 「同じような不具合がほかにないか見て」 | 不具合を直した後 | `dev-defect-fix`（プロファイル経由でも可） | `fix` |
| Z | 「既存システムに新しい機能を足したい」 | 動いているシステム | `dev-profile-existing-system` | `intake` → `sizing` → `req` → `test-design` → `implement`（`primary-source`・`domain-model`・`req-ask`・`design`・`design-ok`・`sizing-after-design`・`tasks` は条件付き） |

## 試験の単位（プロファイルを経ずに直接選ばれてよい）

| ID | 依頼の例 | 状況 | 期待するスキル |
|---|---|---|---|
| T1 | 「この機能のテストを洗い出して」 | 要件の文書がある | `dev-test-case-design` |
| T2 | 「テストが足りているか確認して」 | 実装と要件の文書がある | `dev-test-case-design` |
| T3 | 「受入テストを設計して」 | 画面をまたぐ機能 | `dev-acceptance-e2e` |
| T4 | 「この受入条件で合否を判定できる？」 | 受入条件の案がある | `dev-acceptance-e2e` |
| T5 | 「テストを先に書いて実装して」 | 要件の文書がある | `dev-test-first` |
| T6 | 「再現テストを書いてから直して」 | 不具合の報告がある | `dev-test-first` か `dev-defect-fix` |
| T7 | 「この録画を提出していい？」 | 自分で取った受入の録画がある | `dev-evidence-check` |
| T8 | 「デモ動画を確認して」 | 同僚が取った受入の録画がある | `dev-evidence-check` |

## 新規開発と設計の単位（`dev-profile-new-feature` の工程。既存システムの改修（`dev-profile-existing-system`）でも同じ識別子の工程に着けば合格。単位が直接選ばれてもよい）

| ID | 依頼の例 | 状況 | 期待するスキル | 期待する工程 |
|---|---|---|---|---|
| D1 | 「新しい機能を作りたい」 | 要件のメモがある | `dev-profile-new-feature`（→ `dev-change-sizing`） | `sizing` |
| D2 | 「この処理はどこに書くべき？」 | 実装中の機能 | `dev-responsibility-design` | `design` |
| D3 | 「API を設計して」 | 要件の文書がある | `dev-api-contract` | `design` |
| D4 | 「どんなエラーに分けるか決めて」 | 要件の文書がある | `dev-error-design` | `design` |
| D5 | 「この列を足したい。マイグレーションの進め方を決めて」 | 既存の表がある | `dev-data-design`（`dev-profile-existing-system` 経由でも可） | `design`（新規開発・既存の改修とも） |
| D6 | 「メールを送る処理を設計して。二重送信が怖い」 | 外部へ送る機能 | `dev-async-execution-design` か `dev-cross-system-design` | `design` |
| D7 | 「タスクに分けて」 | 要件の文書がある | `dev-task-breakdown`（プロファイル経由でも可） | `tasks` |
| D8 | 「この変更はどのくらいの規模？設計まで要る？」 | 変更の案がある | `dev-change-sizing` | `sizing` |
| D9 | 「この計算を共通化していい？」 | 似た計算が2か所にある | `dev-responsibility-design` | `design` |
| D10 | 「このロックの設計をモデル検査して」 | 並行実行のある処理 | `dev-formal-model-check` | `formal-check` |
| D11 | 「バッチを設計して。途中で落ちたらどうする？」 | 夜間の集計の処理 | `dev-async-execution-design` | `design` |
| D12 | 「CLI の引数と終了コードを決めて」 | 運用者が流すコマンド | `dev-api-contract` | `design` |
| D13 | 「外部の決済サービスと連携したい」 | 注文の確定で支払う | `dev-cross-system-design` | `design` |
| D14 | 「エラーの扱いを決めて」 | 一部の行が不正な取り込みのバッチ | `dev-error-design` か `dev-async-execution-design` | `design` |
| D15 | 「API のエラーレスポンスの形を決めて」 | 注文の API | `dev-api-contract` | `design` |
| D16 | 「Webhook を受けたい」 | 決済サービスから通知が届く | `dev-cross-system-design` | `design` |
| D17 | 「リトライの方針を決めて」 | 外部の API が時々時間切れ | `dev-cross-system-design` か `dev-async-execution-design` | `design` |
| D18 | 「この共通関数の引数を変えたい。互換性はどうする？」 | 同じリポジトリの中だけで使う関数 | `dev-responsibility-design` | `design` |
| D19 | 「二重に登録されるのを防ぐ設計にしたい」 | これから作る会員登録（コードはまだ無い） | `dev-data-design`、`dev-api-contract`、`dev-async-execution-design`、`dev-defect-fix` のどれか（取り合いの記録）。新規開発のプロファイルから規模の判定（工程 `sizing`）に進むのも可 | `sizing`、`design` か `dev-profile-existing-system` の工程 `fix` |
| D20 | 「この作業の規模を見積もって」 | 要件を足す作業 | `dev-change-sizing` か `dev-task-breakdown` | `sizing` か `tasks` |
| D21 | 「他社の請求書が見えないようにしたい」 | 複数の会社が使うシステムの新しい機能 | `dev-authorization-design` | `design` |
| D22 | 「請求書の確定を、誰ができるか決めて」 | 請求書の機能 | `dev-authorization-design` | `design` |
| D23 | 「ほかの利用者として操作する機能の権限の設計をして」 | 運用者が操作を手伝う | `dev-authorization-design` | `design` |
| D24 | 「このアプリに MCP サーバーを組み込んで、エージェントから記事を読めるようにしたい」 | 動いている記事の管理アプリ | `dev-agent-contract`（プロファイルから規模の判定へ進むのも可） | `sizing` か `design`（新規開発・既存の改修とも） |
| D25 | 「エージェントが記事を書き換える道具を足したい。利用者が知らないうちに書き換わらないようにしたい」 | 記事の管理アプリの MCP サーバー | `dev-agent-contract` | `design`（新規開発・既存の改修とも） |
| D26 | 「コミットの前に、この作業の差分が設計どおりか点検して」 | 自分で作業の実装を終えたところ | `dev-diff-check`（レビューの一巡から依頼文へ進むのも可） | `implement`（新規開発・既存の改修とも） |
| D27 | 「PR を出す前に自分で一度見て」 | 自分で作業の実装を終えたところ | `dev-diff-check`（レビューの一巡から依頼文へ進むのも可） | `implement`（新規開発・既存の改修とも） |
| D28 | 「セルフレビューして」 | 自分で作業の実装を終えたところ | `dev-diff-check` か、レビューの一巡から依頼文（取り合いの記録。冒頭の前提により、独立レビューへ進んでも合格） | `implement`（新規開発・既存の改修とも）、または `dev-profile-review-cycle` の工程 `brief` か、同じく `dev-profile-review-cycle` の工程 `review` |
| D29 | 「ログに何を出すか決めて。出力の量も抑えたい」 | 夜間に会員へメールを送るバッチを作る | `dev-logging-design` | `design`（新規開発・既存の改修とも） |
| D30 | 「失敗の理由のコードを決めたい」 | 外部へ送る処理のログを作り直す | `dev-logging-design`（エラーの種類の分け方を決める依頼なら `dev-error-design`） | `design`（新規開発・既存の改修とも） |
| D31 | 「応答のヘッダと Cookie の方針を決めて」 | これから公開する管理画面 | `dev-entry-safety-design` | `design`（新規開発・既存の改修とも） |
| D32 | 「外部の CDN のスクリプトを読み込んで大丈夫？」 | 新しい画面を作っている | `dev-entry-safety-design` | `design`（新規開発・既存の改修とも） |

## 仕様化の単位（`dev-profile-new-feature` と `dev-profile-existing-system` の工程。単位が直接選ばれてもよい）

| ID | 依頼の例 | 状況 | 期待するスキル | 期待する工程 |
|---|---|---|---|---|
| R1 | 「この要望から要件を起こして」 | 顧客の要望のメール | `dev-requirements` | `req`（新規開発・既存の改修とも） |
| R2 | 「ドメインモデルを作って」 | これから作る機能の業務の説明 | `dev-domain-model` | `domain-model`（新規開発・既存の改修とも） |
| R3 | 「業務の用語と規則を整理して」 | 人によって言葉の使い方が違う | `dev-domain-model` | `domain-model`（新規開発・既存の改修とも） |
| R4 | 「既存のコードから業務規則を洗い出して」 | 仕様書が無い | `dev-rule-extraction` | `dev-profile-existing-system` の工程 `survey` |
| R5 | 「既存のデータが値引きの規則を守っているか調べて」 | 本番のデータの複製がある | `dev-rule-violation-audit` | `dev-profile-existing-system` の工程 `data-audit` |
| R6 | 「この外部 API の仕様を調べて」 | 配送業者の API とつなぐ予定 | `dev-external-domain-survey` | `primary-source`（新規開発・既存の改修とも） |
| R7 | 「この計算が法令どおりか確かめて」 | 消費税の端数処理 | `dev-statutory-grounding` | `primary-source`（新規開発・既存の改修とも） |
| R8 | 「受入条件を書いて」 | 要件の文書がある | `dev-requirements` か `dev-acceptance-e2e`（取り合いの記録） | `req` か `dev-profile-new-feature` の工程 `acceptance` |

## 画面の単位（`dev-profile-new-feature` と `dev-profile-existing-system` の工程。ほかのプロファイルの工程は所属を書く。単位が直接選ばれてもよい）

| ID | 依頼の例 | 状況 | 期待するスキル | 期待する工程 |
|---|---|---|---|---|
| U1 | 「この要件の画面一覧を作って」 | 要件と受入条件の文書がある | `dev-screen-design` | `screen` |
| U2 | 「関係者に見せたいので、ワイヤーを作って」 | 画面の設計がある | `dev-wireframe` | `wireframe` |
| U3 | 「トークンを整理して」 | 色や余白の値が画面ごとにばらばら | `dev-design-system` | `design` |
| U4 | 「部品のカタログを仕様と照らして」 | 部品の仕様の文書とカタログがある | `dev-design-system` | `design` |
| U5 | 「画面遷移を決めて」 | 要件の文書がある | `dev-screen-design`（受入の試験の単位に取られない） | `screen` |
| U6 | 「このモックから要件を起こして」 | 取引先からモックの画像が届いた | `dev-requirements`（画面の設計やワイヤーに取られない） | `req` |
| U7 | 「エラーメッセージを決めて」 | 要件の文書がある | `dev-error-design`（画面の設計に取られない） | `design` |
| U8 | 「誰にどの画面を見せるか決めて」 | 管理者と一般の利用者がいる | `dev-authorization-design`（画面の設計に取られない） | `design` |
| U9 | 「今の画面がどう動いているか調べて」 | 改修の前 | `dev-current-behavior-survey`（画面の設計に取られない） | `dev-profile-existing-system` の工程 `survey` |
| U10 | 「ロゴを作って」 | 新しいサービス | `dev-design-system` は起動しない | — |
| U11 | 「このボタンの部品の story を書いて」 | 部品の仕様の文書がある | `dev-design-system`・`dev-wireframe`・`dev-screen-design` は起動しない（実装。テストを先に書く単位は可） | — |
| U12 | 「この画面を実装して」 | 画面の設計が人に採られている | `dev-wireframe`・`dev-screen-design` は起動しない | — |
| U13 | 「このデモ動画を確認して」 | 受入の証拠の録画がある | `dev-evidence-check`（ワイヤーに取られない） | `evidence` |

「アクセシビリティを確認して」（実装した画面の点検）の起動の先は、まだ決めていない。デザインシステムの単位の使わない場面に入れてあり、受入の証拠か完了前の監査に寄せるかは、使ってみてから決める。

## 文面と操作マニュアルの単位（`dev-profile-new-feature` と `dev-profile-existing-system` の工程。単位が直接選ばれてもよい）

| ID | 依頼の例 | 状況 | 期待するスキル | 期待する工程 |
|---|---|---|---|---|
| TX1 | 「注文確定の通知メールの文面を決めて」 | 注文の確定の要件と受入条件の文書がある | `dev-message-design` | `design` |
| TX2 | 「請求書（帳票）の項目と見せ方を決めて」 | 請求の要件と業務規則の一覧がある | `dev-message-design` | `design` |
| TX3 | 「利用者向けの操作マニュアルを作って」 | 画面の設計があり、隔離した環境で画面が動く | `dev-user-manual` | `ops-artifacts` |
| TX4 | 「画面が変わったので操作マニュアルを直して」 | 利用者向けの操作マニュアルがある。登録の画面が変わった | `dev-user-manual` | `ops-artifacts` |
| TX5 | 「このエラーメッセージで大丈夫？」 | エラーの一覧がある | `dev-error-design`（`dev-message-design` は使わない） | `design` |
| TX6 | 「メールの再送の仕組みを設計して。二重送信が怖い」 | 注文の確定時に確認メールを送る機能 | `dev-async-execution-design`（`dev-message-design` は使わない） | `design` |
| TX7 | 「請求書の金額の端数処理を決めて」 | 請求の機能 | `dev-message-design` は使わない | — |
| TX8 | 「本番の手順を書いて」 | リリースの予定がある | `dev-production-procedure`（`dev-user-manual` は使わない） | `ops-artifacts` |
| TX9 | 「引継ぎの資料を作って」 | 前任者から引き継いだシステム | `dev-system-map` か `dev-profile-inherited-system`（`dev-user-manual` は使わない） | — |
| TX10 | 「この画面の文言を直して」 | 画面の設計がある | `dev-message-design`・`dev-user-manual` は使わない | — |
| TX11 | 「キューに流すメッセージの形を決めて」 | 注文の確定をほかのシステムへ知らせる | `dev-api-contract` か `dev-cross-system-design`（`dev-message-design` は使わない） | `design` |
| TX12 | 「Webhook で送る通知の形を決めて」 | 取引先のシステムへ状態の変化を知らせる | `dev-api-contract` か `dev-cross-system-design`（`dev-message-design` は使わない） | `design` |

## 作業の制御の単位（`dev-profile-existing-system` の工程。中断と再開の工程は所属を書く。単位が直接選ばれてもよい）

| ID | 依頼の例 | 状況 | 期待するスキル | 期待する工程 |
|---|---|---|---|---|
| C1 | 「在庫を引き当てている処理はどこ？」 | 既存システムの引当を変えたい | `dev-code-search` | `survey` |
| C2 | 「この関数を変えると、どこに影響する？」 | 既存システムの共通の計算 | `dev-code-search`（規模の判定に取られたら記録する） | `survey` |
| C3 | 「この文言はどこで作ってる？」 | 画面に出ている文言 | `dev-code-search` | `survey` |
| C4 | 「続きから再開して」 | 引継ぎの記録がある | `dev-profile-interrupt-resume` か `dev-work-continuity` | `dev-profile-interrupt-resume` の工程 `resume` |
| C5 | 「ここで区切って、続きは次のセッションでやれるように引き継いで」 | 実装の途中 | `dev-profile-interrupt-resume` か `dev-work-continuity` | `dev-profile-interrupt-resume` の工程 `handoff` |
| C6 | 「この作業だけ、別の担当に頼みたい」 | 作業の一覧がある | `dev-work-continuity` か `dev-profile-interrupt-resume`（レビューの依頼と取り合わないかを見る） | `dev-profile-interrupt-resume` の工程 `handoff` |
| C7 | 「保守の引継ぎ資料を作って」 | 保守の担当が別のチームに替わる | `dev-work-continuity` と `dev-profile-interrupt-resume` を使わない（作業の中断と再開ではない） | — |
| C8 | 「続きをやって」 | 引継ぎの記録が見当たらない | `dev-profile-interrupt-resume` か `dev-work-continuity` | `dev-profile-interrupt-resume` の工程 `resume`（推定して、同じく `dev-profile-interrupt-resume` の工程 `resume-ask` へ） |

## 版管理の単位（`dev-profile-version-control` の工程。単位が直接選ばれてもよい）

| ID | 依頼の例 | 状況 | 期待するスキル | 期待する工程 |
|---|---|---|---|---|
| V1 | 「worktree で並列に作業したい」「別の作業場所を作って」 | 作業の一覧がある | `dev-profile-version-control` か `dev-isolated-workspace` | `workspace` |
| V2 | 「rebase で衝突した。コンフリクトを解消して」 | 取り込み作業の途中 | `dev-profile-version-control` か `dev-conflict-resolution` | `resolve` |
| V3 | 「push が拒否された（大きいファイルをコミットしてしまった。取り除いて出し直して）」 | 履歴の復旧が必要 | `dev-profile-version-control` か `dev-history-recovery` | `recover` |
| V4 | 「秘密をコミットに含めてしまった。直して」 | 鍵を含めたコミット | `dev-profile-version-control` か `dev-history-recovery` | `recover` |
| V5 | 「統合が終わったので worktree を片付けて」 | 作業場所を使っていた | `dev-profile-version-control` か `dev-isolated-workspace` | `cleanup` |
| V6 | 「直前のコミットを取り消したい」 | 誤ったコミット | `dev-profile-version-control` か `dev-history-recovery` | `recover` |
| V7 | 「作業用の枝を main に取り込んで。まだ衝突しているかは見ていない」 | 衝突前の通常の統合 | `dev-profile-version-control` に入り、`dev-conflict-resolution` 等に飛ばない | `integrate` |
| V8 | 「認証と通知を並列で実装できるよう、作業を分けて順番を決めて」 | 完了条件の一覧がある | `dev-task-breakdown` か `dev-profile-new-feature`（`dev-isolated-workspace` と `dev-profile-version-control` に取られない） | `dev-profile-new-feature` の工程 `test-cases` |
| V9 | 「さっき書き換えた未コミットの変更だけ元に戻して」 | コミット前の単一ファイル編集 | `dev-history-recovery`・`dev-conflict-resolution`・`dev-isolated-workspace`・`dev-profile-version-control` を使わない | — |
| V10 | 「HEAD がどの枝も指さず切り離された状態でコミットしてしまった。変更を消さずに戻して」 | detached HEAD の言い換え | `dev-profile-version-control` か `dev-history-recovery` | `recover` |
| V11 | 「マージは自動で通ったが、片方が消した関数を別ファイルが呼んでいてコンパイルが通らない」 | 衝突印のない隠れ衝突 | `dev-profile-version-control` か `dev-conflict-resolution` | `resolve` |

## 運用と安全の単位（`dev-profile-dependency-upkeep` の工程。ほかのプロファイルの工程は所属を書く。単位が直接選ばれてもよい）

| ID | 依頼の例 | 状況 | 期待するスキル | 期待する工程 |
|---|---|---|---|---|
| O1 | 「この脆弱性の告知はうちに当たる？」 | 使っている部品の告知が今朝公表された | `dev-advisory-check`（プロファイル経由でも可） | `advisory-check` |
| O2 | 「依存の脆弱性を定期的に点検して」 | 動いている Web アプリ | `dev-advisory-check`（プロファイル経由でも可） | `advisory-check` |
| O3 | 「この部品を決めた版に上げて」 | 直す告知と行き先の版が決まっている | `dev-dependency-bump`（プロファイル経由でも可） | `bump` |
| O4 | 「依存を定期的に更新したい」 | 告知は特に無い | `dev-dependency-bump` か `dev-advisory-check`（告知を先に照らす判断） | `bump` か `advisory-check` |
| O5 | 「この外部 API の仕様の変更点を調べて」 | これからつなぐ配送業者の API | `dev-external-domain-survey`（`dev-advisory-check` ではない。境目の確かめ） | `dev-profile-new-feature` の工程 `primary-source` か `dev-profile-existing-system` の工程 `primary-source` |
| O6 | 「今動いている管理画面の応答のヘッダと Cookie を点検して」 | 検証の環境のホストへの要求を許した記録がある | `dev-entry-safety-check`（今の状態の安全の点検のプロファイル経由でも可） | `dev-profile-exposure-sweep` の工程 `entry-check` |
| O7 | 「走査の道具の指摘を仕分けて」 | 手元で流した走査の道具の結果がある | `dev-entry-safety-check`（同上） | `dev-profile-exposure-sweep` の工程 `entry-check` |
| O8 | 「前任者から引き継いだシステムの、どこに何があるかを把握したい」 | ドキュメントの少ない動いているシステム | `dev-profile-inherited-system` か `dev-system-map`（`dev-work-continuity` ではない） | `dev-profile-inherited-system` の工程 `intake`・`map` のどちらか |
| O9 | 「このシステムが使っている秘密を、値を見ずに一覧にして」 | 設定のファイルと設定の雛形がある | `dev-credential-catalog`（引き継いだシステムのプロファイル経由でも可） | `dev-profile-inherited-system` の工程 `catalog` |
| O11 | 「この変更の本番の手順を作って。戻し方も入れて」 | DB の列を足す変更を作り終えたところ | `dev-production-procedure`（既存の改修か依存の更新のプロファイル経由でも可） | `dev-profile-existing-system` の工程 `ops-artifacts` か `procedure` |
| O10 | 「個人情報の台帳を作って、プライバシーポリシーの草案も付けて」 | 会員の情報を扱う Web アプリ | `dev-personal-info-ledger`（同上） | `dev-profile-inherited-system` の工程 `ledger` |
| O12 | 「前任者から引き継いだシステムの現状を把握したい」 | 保守を引き継いだばかりで、文書がほとんど無い | `dev-profile-inherited-system` か `dev-system-map`（`dev-current-behavior-survey` と `dev-work-continuity` ではない） | `dev-profile-inherited-system` の工程 `intake`・`map` のどちらか |
| O13 | 「改修の前に、取り消しの今の仕様を洗い出して」 | 自分たちが保守している既存システムの改修の前 | `dev-current-behavior-survey`（既存の改修のプロファイル経由でも可。`dev-system-map` ではない） | `dev-profile-existing-system` の工程 `survey` |
| O14 | 「新しいキーを足したので、秘密の目録を直して」 | 目録がもうあり、API キーを設定に足した | `dev-credential-catalog`（既存の改修か引き継いだシステムのプロファイル経由でも可） | `dev-profile-existing-system` の工程 `ops-artifacts` か `dev-profile-inherited-system` の工程 `catalog` |
| O15 | 「保存する項目と外部サービスを変えたので、台帳を見直したい」 | 台帳がもうあり、保存する項目と送り先を変えた | `dev-personal-info-ledger`（同上） | `dev-profile-existing-system` の工程 `ops-artifacts` か `dev-profile-inherited-system` の工程 `ledger` |
| O16 | 「このプライバシーポリシーは適法？」 | 公開しているプライバシーポリシーの文面がある | `dev-personal-info-ledger` を使わない（適法かの判断は台帳の単位の外） | — |

C7（「保守の引継ぎ資料を作って」、渡す側）は、O8〜O10 と O12 を足した後も期待を変えない。引き継いだシステムのプロファイルは受け取る側の把握を受け持ち、渡す側の資料作りは受けないため。

W（「セキュリティを見て」、変更の安全性の点検）は、O6・O7 を足した後も「dev- は起動しない」のままにする。変更の差分の点検と今の状態の点検を、依頼の言い方で分けるため。

## 起動してはいけない依頼

| ID | 依頼の例 | 状況 | 期待するスキル |
|---|---|---|---|
| G | 「この機能を実装して」 | 実装の依頼 | dev- は起動しない |
| W | 「セキュリティを見て」 | 変更の安全性の点検 | dev- は起動しない（組み込みのセキュリティの点検は可） |

## 作った本人の流れ

新しいセッションの一言の依頼では「このセッションが作った」状況を再現できないので、別に試す。小さな要件の文書と関数だけを置いた使い捨てのリポジトリに dev- のスキルだけを見せ、1つのセッションに「要件を実装して、終わったらそのままレビューして」と頼む。ファイルの編集は許す。

試験の条件:

- 使い捨てのリポジトリは、試験の仕組み（試験を流すスクリプト、ログ）や、ほかの作業フォルダと別の場所に置く。親フォルダから試験の意図が読み取れると、モデルが「試験されている」と知って振る舞いを変えうる。
- スキルはリンクでなく実体でコピーし、試す道具が読む置き場（Claude Code は `.claude/skills`、Cursor は `.cursor/skills`、Antigravity の CLI は `.agent/skills` か `.agents/skills`）だけに置く。ほかの道具の置き場を同じリポジトリに並べない。
- 各回の前に、リポジトリを初期の状態に戻す（前の回の実装や試験のファイルを残さない）。履歴にも前の回の実装を入れない。
- 試験の対象のリポジトリで、利用者の記憶や計画書が読み込まれないようにする（開発中のリポジトリの作業フォルダで流すと、その記憶が読み込まれることがある）。
- 各回のログで、リポジトリの外を読んだ回が無いかを確かめ、試験の意図が分かるものを読んだ回は集計から外す。

| ID | 依頼 | 期待 |
|---|---|---|
| SA | 「要件 2 と 3 を実装して。実装が終わったら、そのままレビューして」 | 実装の後に `dev-profile-review-cycle` を使い、自分ではレビューせず、`dev-review-brief` の依頼文を書いて止まる |

## 実施の記録

2026-11-14 に、上の表の「期待する工程」を工程の番号から識別子に置き換えた。この節の記録にある工程の番号は、[規約の付録の対応表](dev-skills-conventions.md#付録-工程の識別子の対応表)で読み替える。

2026-11-12 までの Claude Code の起動の試験（下の表の Claude Code の行のうち、「隔離した場所」と書いていないもの）は、開発中のリポジトリの作業フォルダで流しており、利用者の記憶（開発の計画を含む）が読み込まれていた。残っているログでは、4回が記憶の本文を読み、2回が非公開の作業の置き場を一覧していた。これらの行は、条件が崩れた結果として残し、判断には「隔離した場所」の行を使う。

「隔離した場所」の行も、試験を Go に移す前に手で流したもので、利用者の設定（言語の指定、フック）、利用者単位のスキルとプラグイン、MCP は読み込まれていた（Go に移した後のレビューで判明）。W で使われた `security-review` は CLI に組み込みのスキルで、今の隔離でも残る。今後の判断には `tests/trigger` で流した結果を使う。

| 日付 | 道具とモデル | 結果 | 直したこと |
|---|---|---|---|
| 2026-11-12 | Cursor（Grok 4.7 256K Medium）、英語の description | A〜G の7件とも期待する工程に着いた。description だけで選ぶと A は `dev-review-brief`、F は `dev-completion-audit` を直接選び、本文を読むとプロファイル経由に変わった | プロファイルの起動の言い方に、再レビュー・PR・日本語の言い方を足した。振り分けの表に「このPRを見て」「再レビューして」を足した。`dev-review-conduct` の使わない場面に、同じセッションで自分が作った変更を足した |
| 2026-11-12 | Claude Code（Haiku 5.5）、日本語の description | dev- のスキルが無い作業場所で起動されたため、自動の起動は試せなかった。description を直接読ませた判断では、7件とも期待する工程に着いた | `dev-review-conduct` の言い方「この変更をレビューして」を、他人の変更と分かる言い方に替えた |
| 2026-11-12 | Claude Code（Haiku 5.5 と Sonnet 5.5） | 組み込みの差分レビューも読み込まれた状態で、2つのモデルとも A〜G の7件で期待するスキルを最初に使った | なし |
| 2026-11-12 | Claude Code（Haiku 5.5 と Sonnet 5.5）、既存システムの改修を足した後 | H〜M と G は両モデルとも期待どおり。N は、Haiku がスキルを使わず、Sonnet はレビューの単位に直接進んだ（作った本人のレビューになる） | レビューの一巡に「直したのでレビューして」の言い方と振り分けを足し、工程4の順序を書いた。直した後、両モデルとも工程1に着いた |
| 2026-11-12 | Claude Code（Haiku 5.5 と Sonnet 5.5）、名前の付け直しの後 | A〜N の14件。Sonnet は14件とも期待どおり。Haiku は13件が期待どおりで、B は4回中1回だけプロファイルを使い、残り3回はスキルを使わずに差分を読み始めた。Haiku は E でも、依頼文の単位の後にレビューの単位を読み込んだ | なし（記録に留める） |
| 2026-11-12 | Claude Code（Haiku 5.5 と Sonnet 5.5）、Fable 5.1・5.2 のレビューを受けた修正の後 | 25件。Sonnet は25件とも期待どおり（W は組み込みのセキュリティの点検を使い、dev- は起動しなかった。X の「PR #123 をレビューして」も `dev-review-conduct` を選び、組み込みの差分レビューに取られなかった）。Haiku は24件が期待どおりで、W は dev- を起動しなかった。B は、プロファイルを読んだうえで「このセッションは作っていない」と判断して工程2に進んだ。直した振り分けの決まり（作った側かはセッションで決める）に沿った判断なので合格とした | 試験の前提（新しいセッションでは作った側を再現できない）を、この文書の冒頭に書いた |
| 2026-11-12 | Claude Code（Haiku 5.5 と Sonnet 5.5）、作った本人の流れ（SA） | Sonnet は3回とも、実装の後にプロファイルと依頼文の単位を使い、自分ではレビューしなかった。Haiku は3回ともスキルを使わず、自分でレビューした | プロファイルの description に「実装してからレビューして」の言い方と「自分で作った変更を自分でレビューする前に必ず使う」を足した。本文の冒頭に「このセッションが作った変更は自分でレビューせず、依頼文を書いて止まる」を置いた。直した後、Haiku は3回中2回で依頼文を書いて止まり、1回はスキルを使わずに自分でレビューした。Sonnet は1回試して期待どおり。レビュー系の13件（A〜G、N〜Q、W、X）も両モデルで流し直し、すべて合格 |
| 2026-11-12 | Cursor（Grok 4.7 Medium）、作った本人の流れ（SA） | 3回とも、実装の後に依頼文を書いて止まり、自分ではレビューしなかった。1回は実装の前に既存システムの改修のプロファイルも読み、受付の判定（利用側なし、機能の変更）を書いてから実装した | なし |
| 2026-11-12 | Antigravity（Gemini 3.8 Flash Medium）、作った本人の流れ（SA）、試験の仕組みと同じ場所 | 集計から外した。この6回は、試験の仕組みのスクリプトとログがある親フォルダの下で流しており、1回は親フォルダを一覧し、1回は試験のスクリプトを読んでいた（どちらも自分でレビューした回）。また、4つの道具の置き場をリンクで同じリポジトリに並べていた（Antigravity の CLI は `.agent/skills` と `.agents/skills` の両方を読み、`.claude/skills` と `.cursor/skills` は読まないことを、後で置き場を1つずつにして確かめた） | 試験の条件（上の「試験の条件」）を書いた |
| 2026-11-12 | Antigravity（Gemini 3.8 Flash Medium）、作った本人の流れ（SA）、隔離した場所 | スキルを `.agents/skills` だけに実体で置き、親フォルダに何も無い場所で3回。3回とも、プロファイルと依頼文の単位を読み、自分ではレビューせず依頼文を書いて止まった。リポジトリの外を読んだ回は無い | なし |
| 2026-11-12 | Claude Code（Haiku 5.5）、作った本人の流れ（SA）、隔離した場所 | 同じ隔離の条件（`.claude/skills` だけ）で3回。依頼文を書いて止まったのは1回で、2回はスキルを使わずに自分でレビューした。リポジトリの外を読んだ回は無い（1回、外でコードを実行しようとしたが、シェルを止めていたので実行されていない） | なし（Haiku の不安定さは、上の回と合わせて記録に留める） |
| 2026-11-12 | Claude Code（Sonnet 5.5）、作った本人の流れ（SA）、隔離した場所 | 3回とも、プロファイルと依頼文の単位を使い、自分ではレビューせず依頼文を書いて止まった。外の参照なし | なし |
| 2026-11-12 | Cursor（Grok 4.7 Medium）、作った本人の流れ（SA）、隔離した場所 | `.cursor/skills` だけに置いて3回。3回とも、実装の前に既存システムの改修のプロファイルで受付の判定をしてから実装し、実装の後は依頼文を書いて止まった。外の参照なし | なし |
| 2026-11-12 | Claude Code（Sonnet 5.5 と Haiku 5.5）、A〜Z の25件、隔離した場所 | リポジトリの全スキルを `.claude/skills` だけに実体で置き、各回の前に初期の状態と「この変更」（未コミットの実装）を作り直した。外の参照は、どの回にも無い。Sonnet は25件とも期待どおり（B と N は「このセッションは作っていない」と判断して工程2へ。冒頭の前提により合格）。Haiku は21件が期待どおりで、B（自分の変更に「レビューして」）、E（再レビュー）、L（共通処理を変えたい）、Z（既存システムに機能を足したい）の4件はスキルを使わなかった（L では、スキルの文書をわざと除外して調べていた）。記憶が読み込まれていた前回の Haiku の 25/25 より下がった | なし（Haiku では、一言だけの依頼からプロファイルを選ぶ力が弱い。記録に留める） |
| 2026-11-12 | Claude Code（Sonnet 5.5 と Haiku 5.5）、試験の単位を足した後の33件、隔離した場所 | Sonnet は32件が期待どおりで、T1〜T5、T7、T8 は試験の単位を直接選んだ。T6（再現テストを書いてから直して）は両モデルともスキルを使わず、先にコードを読んで「報告の症状は今のコードでは起きない」と判断していた（依頼の前置きと試験用の実装が食い違っていた。書き込みの道具を止めていたことも影響した可能性がある）。Haiku は26件が期待どおりで、M、T、X、Z、T2、T6 はスキルを使わなかった。T8 では両モデルとも録画を探して親フォルダを読もうとしたが、権限で拒否され、外の中身は読んでいない | T6 の依頼の前置きを、試験用の実装と食い違わない不具合の報告に直して、両モデル2回ずつ試し直した。Sonnet は2回とも `dev-test-first` を選んだ。Haiku は2回中1回 `dev-test-first` を選び、1回はスキルを使わなかった |
| 2026-11-12 | Claude Code（Sonnet 5.5 と Haiku 5.5）、設計の群と新規開発のプロファイルを足した後の43件、隔離した場所 | 隔離の場所を作り直し、全スキル30本を `.claude/skills` だけに置いた。Sonnet は41件が期待どおりで、D1〜D10 の10件はどれも期待する単位（D1 はプロファイルから規模の判定）を最初に選んだ。H と T2 はスキルを使わず、先にコードを調べて、3回の手番の上限に達した。Haiku は31件が期待どおりで、E、H、L、M、N、Z、T1、T2、T6、D1、D3、D9 はスキルを使わなかった（D2、D4、D7 は少し調べてから単位を使った）。T8 では両モデルとも録画を探して親フォルダを読もうとしたが、権限で拒否され、外の中身は読んでいない。C の `..` は差分の範囲の指定（`main...feature-x`）で、外の参照ではない | H の前置き（登録画面の不具合）は試験用の実装に無い機能で、Sonnet は手番を増やすと「該当するコードが無い」と判断して止まった（2回）。実装と食い違わない報告（単価に小数があると値引き後の額が小数で返る）に直して2回ずつ試すと、Sonnet は1回 `dev-defect-fix` を使い、1回はスキルを使わずに直接直そうとした。Haiku も2回中1回。T2 は Sonnet で2回試し直し、1回は調べた後に `dev-test-case-design` を使い、1回は使わなかった（試験用のリポジトリにテストが無く、「無い」と答えて終わる）。小さな是正やテストの有無の確認では、Sonnet でもスキルを使わない回がある |
| 2026-11-13 | Claude Code（Sonnet 5.5 と Haiku 5.5）、`tests/trigger` の Go の試験で全件（開発作業の群 53件、各3回）。利用者の設定・フック・利用者単位のスキル・MCP を読まない隔離 | 全366回（Cloudflare の群を含む）で、実行の誤り0件、外の中身を読んだ回0件。開発作業の群では、Sonnet は159回中156回が合格。外れたのは E の1回（プロファイルの後に依頼文でなく独立レビューへ進んだ。新しいセッションは自分が直したと確かめられないので、許される範囲の判断）と D19 の2回（新規開発のプロファイルから規模の判定へ進んだ）。Haiku は159回中145回が合格。D6・D18・D19 は3回ともスキルを使わず、D17 は1回だけ、L・Z・D20 は2回ずつ合格した | D19 の2回は、新規開発のプロファイルが設計の依頼を工程1（規模の判定）から始める決まりどおりの動きだったので、D19 の合格に規模の判定を足した。隔離を正したことで、手で流していた頃より Haiku の合格が増えた（利用者単位のスキルとの取り合いが無くなったためと見られる） |
| 2026-11-13 | Claude Code（Sonnet 5.5）、仕様化の群を足した後の一部（R1〜R8 と、工程番号が変わった D5・Z、起動してはいけない G）、各1回、`tests/trigger` の隔離 | 11件とも合格。R1〜R8 は期待する単位を最初に直接選んだ（取り合いの R8 は `dev-requirements`）。Z はプロファイルから規模の判定へ。外の参照なし | なし。Haiku と各3回の全件は、群を揃えた後にまとめて流す |
| 2026-11-13 | Claude Code（Sonnet 5.5）、仕様化の群のレビューを受けて description を直した後（R1〜R8 と、外部との連携の D13・D16・D17）、各1回 | 11件とも、期待する単位を最初に直接選んだ。外の参照なし | なし |
| 2026-11-13 | Claude Code（Sonnet 5.5）、認可の単位を足した後（D21〜D23 と、取り合いうる D2・D3・W・X・G）、各1回 | 8件とも合格。D21〜D23 は `dev-authorization-design` を直接選んだ。W（セキュリティを見て）は dev- を起動しなかった | なし |
| 2026-11-13 | Claude Code（Sonnet 5.5）、MCP サーバーのスキルを `dev-agent-contract` に移した後（D24・D25 と、取り合いうる D3・D12・D13・D16）、各1回 | 6件とも、期待する単位を最初に直接選んだ | なし |
| 2026-11-13 | Claude Code（Sonnet 5.5）、差分の点検の単位を足した後（D26 と、取り合いうるレビュー系の A・B・C・E・F・N・O・X） | D26 は `dev-diff-check` を直接選んだ。レビュー系は、E の1回を除いて合格し、新しい単位に取られた回は無かった。E の1回は、レビューの一巡の後に依頼文でなく独立レビューへ進んだ（全件の試験で出たのと同じ外れ方）。E だけ3回流し直すと3回とも合格 | なし |
| 2026-11-13 | Claude Code（Sonnet 5.5）、差分の点検の単位をレビュー（別のモデル）を受けて直した後（D26〜D28 と A・B・N、各2回、計12回） | D26・D27 は2回とも `dev-diff-check` を直接選んだ。A・B・N は2回ともレビューの一巡を経て期待どおり。D28（セルフレビューして）は、1回はレビューの一巡から依頼文へ、1回はレビューの一巡から理由を書かずに独立レビューへ進んだ。後者は、新しいセッションが自分の変更と確かめられない A・B と同じ状況なので、合格の側に入れた。作った本人の流れ（SA）は流し直していない | D28 の合格に独立レビューを足した |
| 2026-11-13 | Claude Code（Sonnet 5.5）、コードの場所を探す単位を足した後（C1〜C3 と、取り合いうる J・S・R4・L、各2回、計14回） | 14/14。C1〜C3 は2回とも `dev-code-search` を直接選び、C2（波及）が規模の判定に取られた回は無かった。J・S は今の動きの調査、R4 は業務規則の抽出を直接選び、L はプロファイルの振り分けまで進んだ。新しい単位に取られた回は無かった |
| 2026-11-13 | Claude Code（Sonnet 5.5）、中断と再開の単位とプロファイルを足した後（C4〜C6 と、取り合いうる A・F・O・P、各2回、計14回） | 14/14。C4（続きから再開して）は2回ともプロファイルを経て、C5（区切って引き継いで）は直接1回・プロファイル経由1回、C6（別の担当に頼みたい）は2回とも `dev-work-continuity` を直接選んだ。P（別のモデルにレビューを頼みたい）と O は `dev-review-brief` を直接選び、委任の単位に取られた回は無かった。A と F も期待どおり |
| 2026-11-13 | Claude Code（Sonnet 5.5）、作業の制御の群のレビュー（別のモデル）を受けて直した後（C4〜C8 と P・J、各2回、計14回） | 14/14。新しい C7（保守の引継ぎ資料）は2回とも中断と再開の単位とプロファイルを使わなかった。C8（記録が無い「続きをやって」）は、1回はプロファイルを経て単位まで、1回はプロファイルの振り分けまで進んだ。C4〜C6・P・J は前回と同じく期待どおり | なし |
| 2026-11-13 | Claude Code（Sonnet 5.5）、版管理の群（3単位とプロファイル）を足した後（V1〜V6 と取り合いうる C5・C6・D26、各2回、計18回） | 18/18（すべて期待する単位を最初に直接選択）。V1〜V6 は意図どおりの単位に入り、C5・C6・D26 が新しい版管理の単位に取られた回は無かった | なし |
| 2026-11-13 | Claude Code（Sonnet 5.5）、独立レビュー（別のモデル）を受けた修正と対照ケース V7〜V9 の追加後（V1〜V9 と C5・C6・D7・D26、各2回、計26回） | 26/26（V1〜V6・D7・D26・C5・C6・V8 はすべて期待する単位を直接選択、V7 と V9 は各2回とも禁じた版管理単位を使わなかった） | なし |
| 2026-11-13 | Claude Code（Sonnet 5.5）、Fable 5.1/5.2 のレビューの反映と V2・V3・V7 の修正および V10・V11 追加後（V1〜V11 と C5・C6・D7・D26、各2回、計30回） | 30/30（V1〜V8・V10・V11・D7・D26・C6 は直接 2/2、C5 は直接 1・経由 1、V9 は不使用 2/2） | なし |
| 2026-11-13 | Claude Code（Sonnet 5.5）、独立レビュー（別のモデル）の反映と V8・V9 の禁止対象への `dev-profile-version-control` 追加後（V1〜V11 と C5・C6・D7・D26、各2回、計30回） | 30/30（V1〜V8・V10・V11・D7・D26・C6 は直接 2/2、C5 は直接 1・経由 1、V9 は不使用 2/2） | なし |
| 2026-11-14 | Claude Code（Sonnet 5.5）、工程の識別子への置き換えと、`dev-history-recovery` の description の言い方（「破壊度に応じた」→「取り返せない操作への」）を変えた後（V3・V4・V6・V10、各1回、`tests/trigger` の隔離） | 4/4（どれも `dev-history-recovery` を直接選んだ） | なし |
| 2026-11-14 | Claude Code（Sonnet 5.5）、運用と安全の群の起動の試験 O12〜O16 を足した後（O12〜O16、各1回、`tests/trigger` の隔離） | 5/5。O12（引き継いだシステムの現状の把握）はプロファイルを経て、O13（改修の前の今の仕様）は `dev-current-behavior-survey`、O14 は `dev-credential-catalog`、O15 は `dev-personal-info-ledger` を直接選んだ。O16（プライバシーポリシーは適法？）は台帳の単位を使わなかった | なし |
| 2026-11-14 | Claude Code（Sonnet 5.5）、画面の群（3単位）を足し、新規開発と既存システムの改修の description に「画面の設計」を足した後。U1〜U13 を各2回（計26回）と、全件（開発作業の群 116件と Cloudflare の群 8件）を各1回、`tests/trigger` の隔離 | U1〜U13 は 26/26。U1・U5 は `dev-screen-design`、U2 は `dev-wireframe`、U3・U4 は `dev-design-system` を直接選んだ。対照（U6 モックから要件、U7 エラーメッセージ、U8 誰にどの画面を見せるか、U9 今の画面を調べて、U13 デモ動画）は、どれも期待する単位を直接選び、画面の単位に取られた回は無かった。U10〜U12 は禁じた単位を使わなかった。全件では D32（外部の CDN のスクリプトを読み込んで大丈夫？）だけが外れた（スキルを使わずに要件の文書を読み始めた）。D32 を3回流し直すと 2/3 で、外れた1回も同じ外れ方だった。画面の単位を選んだ回は無い | なし。D32 は前の全件の記録に外れが無いので、記録に留めて、全件を3回流すときに見る |
| 2026-11-14 | Claude Code（Sonnet 5.5・Haiku）、文面と操作マニュアルの単位（`dev-message-design`、`dev-user-manual`）を足した後。TX1〜TX10 と近い既存のケース（U1〜U13、D4、D6、O1、O7、C8）を各3回、`tests/trigger` の隔離 | Sonnet: TX2・TX9 が 2/3、ほかは 3/3。近い既存のケースで新しい単位に取られた回は無い。Haiku: TX1 1/3、TX2・TX6・TX9 0/3（スキルを使わない）。独立レビュー（別のモデル2つ）を受けて直した後、TX11・TX12（機械が受け取るメッセージと Webhook の対照）を足し、Sonnet で TX1〜TX6・TX9・TX11・TX12・D6 を各3回: TX11 が 0/3（文面の単位に取られた）、ほかは 3/3。文面の単位の description に機械が受け取るメッセージ・イベント・Webhook を使わない場面として足し、TX1・TX2・TX11・TX12・D6 を各3回流し直して、どれも 3/3 | Haiku で文面の依頼にスキルを使わない回が多い（記録だけ） |
