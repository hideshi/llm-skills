# 開発スキル群の流れ図

プロファイルごとに、どの順で単位を使い、何を受け取って何を渡し、どの条件で次へ進むかを図にしたもの。正本は各プロファイルの SKILL.md の「工程」「遷移」「振り分け」「工程の間の決まり」で、この図はそれを読みやすくした写し。プロファイルを直したら、この図も直す。図の矢印は、判定と人の決定をたたむと、プロファイルの「遷移」の表と一致する（`scripts/check_dev_flows.py` で確かめる）。

図の見方:

- 四角は工程。1行目は工程の識別子（プロファイルの工程の表の1列目）、2行目は工程の名前。`dev-` の名前があるものは単位を使う工程、「（人）」は単位を使わない工程。
- 矢印の上の文字は、渡す成果物の型か、進む条件。
- ひし形は判定。

## 1. レビューの一巡（`dev-profile-review-cycle`）

```mermaid
flowchart TD
    IN(["変更を作った工程・仕様"])
    JEvidence{"画面・録画・帳票の<br/>証拠があるか"}
    Evidence["evidence<br/>受入の証拠を確かめる<br/>dev-evidence-check"]
    Brief["brief<br/>依頼文を書く<br/>dev-review-brief"]
    Review["review<br/>レビューする<br/>dev-review-conduct<br/>（別のモデル・セッション・人）"]
    JReview{"判定"}
    Rework["rework<br/>直す<br/>（実装）"]
    ReReviewRound["re-review-round<br/>再レビュー<br/>dev-review-brief → dev-review-conduct<br/>（直した所に絞る）"]
    JReReview{"判定"}
    H(["人の決定"])
    Audit["audit<br/>完了前に監査する<br/>dev-completion-audit"]
    JAudit{"判定"}
    FinalOk(["final-ok<br/>人の最終確認"])

    IN --> JEvidence
    JEvidence -->|"ある"| Evidence
    JEvidence -->|"ない<br/>変更の事実・原典の参照・検証の記録"| Brief
    Evidence -->|"受入の証拠（確定）"| Brief
    Brief -->|"レビュー依頼文"| Review
    Review -->|"レビュー結果・方針外の課題の記録"| JReview
    JReview -->|"変更要求"| Rework
    JReview -->|"判断を人へ戻す"| H
    JReview -->|"承認"| Audit
    H -->|"決定に従って"| Rework
    Rework -->|"変更の事実・検証の記録・完了の主張"| ReReviewRound
    Rework -.->|"直した所が受入の証拠に関係する"| Evidence
    Evidence -.->|"直した後のやり直し"| ReReviewRound
    ReReviewRound -->|"レビュー結果"| JReReview
    JReReview -->|"変更要求"| Rework
    JReReview -->|"同じ指摘で2回合意できない"| H
    JReReview -->|"承認"| Audit
    IN -.->|"完了条件の一覧・追跡表（任意）"| Audit
    Audit -->|"完了判定"| JAudit
    JAudit -->|"条件付き: 示された手順の後にやり直す"| Audit
    JAudit -->|"止める: 原因の工程へ"| Rework
    JAudit -->|"進めてよい"| FinalOk
```

決まり:

- `brief` と `review`（`re-review-round` の中の依頼文とレビューも）を、同じセッションで続けて行わない。
- 受入の証拠は確定してから依頼文に添える。確定の後に関係する所を変えたら、`evidence` をやり直す。
- 「判断を人へ戻す」の間も、決定待ちの事柄以外の作業は止めない。

### 入口（一言の依頼から入る工程）

| 依頼の言い方・状況 | 入る工程 |
|---|---|
| このセッションが作った変更を「レビューに出したい」「レビューして」「直したのでレビューして」 | `brief`（証拠があれば `evidence` から） |
| レビュー依頼文を渡された、またはこのセッションが作っていない変更を「レビューして」「このPRを見て」 | `review` |
| レビュー結果を受けて「直したので見て」「再レビューして」 | `re-review-round` |
| 「終わったか確認して」「人に見せてよいか」 | `audit` |

## 2. 既存システムの改修（`dev-profile-existing-system`）

```mermaid
flowchart TD
    Request(["依頼"])
    Intake["intake<br/>受付（人）<br/>判定 A・B・C<br/>本番で動いているか"]
    Sizing["sizing<br/>規模を判定する<br/>dev-change-sizing"]
    Survey["survey<br/>今の動きを調べる<br/>dev-current-behavior-survey<br/>dev-rule-extraction（規則が散らばっているとき）<br/>dev-code-search（場所や波及を探すとき）"]
    FormalCheck["formal-check<br/>モデルで検査する<br/>dev-formal-model-check<br/>（人が依頼したとき）"]
    DataAudit["data-audit<br/>データの規則違反を監査する<br/>dev-rule-violation-audit<br/>（人が依頼したとき）"]
    SurveyAsk["survey-ask<br/>人に確かめる（人）"]
    JA{"A: 既存の利用側が<br/>ある処理に触るか"}
    Baseline["baseline<br/>回帰の基準を固める<br/>dev-regression-baseline<br/>（改修前の版で通す）"]
    JB{"B: 不具合か<br/>機能の変更か"}
    Req["req<br/>要件を書く<br/>dev-requirements"]
    PrimarySource["primary-source<br/>一次情報を調べる<br/>dev-external-domain-survey<br/>dev-statutory-grounding"]
    DomainModel["domain-model<br/>モデルを直す<br/>dev-domain-model"]
    ReqAsk["req-ask<br/>人に確かめる（人）<br/>仮説・未確定の規則"]
    JScreen{"画面が済んでいるか"}
    Screen["screen<br/>画面を設計する<br/>dev-screen-design<br/>（踏襲する範囲を人と合意）"]
    JWire{"人に画面を見せて<br/>確かめたいか"}
    Wireframe["wireframe<br/>ワイヤーを作る<br/>dev-wireframe"]
    ScreenOk(["screen-ok<br/>画面の設計を採る（人）"])
    JScreenOk{"意見があるか・採るか"}
    JReqDesign{"設計の観点が要るか"}
    Design["design<br/>設計する（要る観点だけ）<br/>dev-responsibility-design<br/>dev-authorization-design<br/>dev-api-contract<br/>dev-error-design<br/>dev-data-design<br/>dev-async-execution-design<br/>dev-cross-system-design<br/>dev-logging-design<br/>dev-entry-safety-design<br/>dev-agent-contract<br/>dev-design-system<br/>dev-message-design"]
    DesignOk["design-ok<br/>設計を承認する（人）<br/>決定待ちを決め、担当の案を採る"]
    SizingAfterDesign["sizing-after-design<br/>規模を判定し直す<br/>dev-change-sizing"]
    Fix["fix<br/>不具合を是正する<br/>dev-defect-fix"]
    TestDesign["test-design<br/>試験を設計する<br/>dev-test-case-design<br/>dev-acceptance-e2e（条件付き）"]
    JTasks{"作業に分ける<br/>条件に当たるか"}
    Tasks["tasks<br/>作業に分ける<br/>dev-task-breakdown"]
    Implement["implement<br/>改修する<br/>dev-test-first（既定）<br/>dev-diff-check（作業の終わり）"]
    JBaselineUpdate{"期待値が変わった<br/>検証点があるか"}
    BaselineUpdate["baseline-update<br/>回帰の基準を更新する<br/>dev-regression-baseline"]
    SizingAfterImplement["sizing-after-implement<br/>規模を判定し直す<br/>dev-change-sizing（実際の差分で）"]
    JOps{"運用の作業・文書に<br/>当たるか"}
    OpsArtifacts["ops-artifacts<br/>運用の成果物と利用者向けの文書を作る<br/>dev-production-procedure<br/>dev-credential-catalog<br/>dev-personal-info-ledger<br/>dev-user-manual"]
    JOpsResult{"手元で流した結果<br/>確認事項・業務の決定"}
    OpsOk(["ops-ok<br/>運用の成果物と利用者向けの文書を承認する（人）"])
    JOpsOk{"承認するか"}
    JEvidence{"画面・録画・帳票が<br/>証拠になるか"}
    Evidence["evidence<br/>受入の証拠を確かめる<br/>dev-evidence-check"]
    ReviewRound["review-round<br/>レビュー<br/>dev-review-brief → dev-review-conduct<br/>（別の担当）"]
    JReview{"判定"}
    H(["人の決定"])
    Audit["audit<br/>完了前に監査する<br/>dev-completion-audit"]
    JAudit{"判定"}
    FinalOk(["final-ok<br/>人の最終確認"])

    Request --> Intake
    Intake -->|"改修の範囲・不具合の報告"| Sizing
    Sizing -->|"A か C に当たる<br/>規模の判定"| Survey
    Sizing -->|"どちらでもない"| JB
    Survey -->|"問題台帳に質問・事実確認がある"| SurveyAsk
    SurveyAsk -->|"問題台帳（回答つき）"| Survey
    Survey -.->|"人が今の実装の検査を依頼"| FormalCheck
    FormalCheck -.->|"今の実装を検査した後"| Survey
    Survey -.->|"人がデータの監査を依頼"| DataAudit
    DataAudit -.->|"問題台帳・検証の記録"| Survey
    Design -.->|"人が設計の検査を依頼"| FormalCheck
    FormalCheck -.->|"設計を検査した後: 検証の記録・問題台帳"| DesignOk
    Survey -->|"調べ終えた: 現状の振る舞いの記録・問題台帳・業務規則の一覧"| JA
    JA -->|"はい"| Baseline
    JA -->|"いいえ"| JB
    Baseline -->|"回帰の基準"| JB
    JB -->|"不具合"| Fix
    JB -->|"機能の変更"| Req
    Req -.->|"外部の仕様・公的な規則の確かめが要る"| PrimarySource
    PrimarySource -.->|"一次情報の記録"| Req
    Req -.->|"規則が変わる・根拠の規則に仮説がある"| DomainModel
    DomainModel -->|"ドメインモデル・業務規則の一覧"| Req
    DomainModel -->|"仮説・未確定がある"| ReqAsk
    Req -.->|"要件の確認事項に未回答がある"| ReqAsk
    ReqAsk -->|"業務規則の回答: 一覧に反映する"| DomainModel
    ReqAsk -->|"要件・画面の回答"| Req
    ReqAsk -.->|"台帳の回答"| OpsArtifacts
    Design -.->|"新しく外部に依存する・完了条件に無い業務の決定が要る・画面の契機が無いのに画面が要る"| Req
    Design -.->|"画面の契機があり、認可・エラー・デザインシステム・文面で画面が変わる"| Screen
    Req -->|"完了条件の一覧"| JScreen
    JScreen -->|"済んでいない"| Screen
    JScreen -->|"済んでいる"| JReqDesign
    Screen -.->|"受入条件の案・確認事項の候補・入力情報か判断の欠け"| Req
    Screen -->|"画面の設計"| JWire
    JWire -->|"はい"| Wireframe
    JWire -->|"いいえ"| ScreenOk
    Wireframe -->|"ワイヤー"| ScreenOk
    Wireframe -.->|"画面の設計を変える案"| Screen
    ScreenOk --> JScreenOk
    JScreenOk -.->|"意見がある・採らない: 確認事項の記録で振り分ける"| Req
    JScreenOk -->|"採った（設計から戻った画面。先に見る）"| Design
    JScreenOk -->|"採った: 採った版の所在"| JReqDesign
    JReqDesign -->|"要る"| Design
    JReqDesign -->|"要らない"| TestDesign
    Design -->|"設計の判断"| DesignOk
    DesignOk -->|"設計の判断（決定済み）"| SizingAfterDesign
    SizingAfterDesign -->|"規模の判定"| TestDesign
    DesignOk -.->|"反例・決定待ちの決定・人の直しの求めで設計を直す"| Design
    TestDesign -->|"テストケース表"| JTasks
    TestDesign -.->|"受入条件の書き直しの案を採る"| Req
    JTasks -->|"当たる"| Tasks
    JTasks -->|"当たらない"| Implement
    Tasks -->|"作業の一覧・追跡表"| Implement
    Fix -->|"是正の対応表・変更の事実・完了条件の一覧"| JBaselineUpdate
    Fix -.->|"直す方針が設計を要る: B を機能の変更に"| Req
    Fix -.->|"同じ形の箇所をまとめて直す: テストケース表から作業に分ける"| TestDesign
    Tasks -.->|"作業の一覧（是正のとき）"| Fix
    Implement -->|"変更の事実・検証の記録"| JBaselineUpdate
    Implement -.->|"差分の点検で設計の判断を見直すと決まった"| Design
    JBaselineUpdate -->|"ある"| BaselineUpdate
    JBaselineUpdate -->|"ない"| SizingAfterImplement
    BaselineUpdate -->|"回帰の基準（区分と根拠つき）"| SizingAfterImplement
    SizingAfterImplement -->|"規模の判定"| JOps
    SizingAfterImplement -.->|"①完了条件の承認し直しが要る。または是正で設計が要る（B を切り替える）"| Req
    SizingAfterImplement -.->|"②機能の変更で、要る観点に設計の判断が無い"| Design
    SizingAfterImplement -.->|"③機能の変更で、作業に分ける条件に当たり、作業の一覧が無い"| Tasks
    SizingAfterImplement -.->|"③是正で、作業に分ける条件に当たり、作業の一覧が無い"| Fix
    JOps -->|"当たる"| OpsArtifacts
    JOps -->|"当たらない"| JEvidence
    OpsArtifacts -->|"本番の手順・目録・台帳"| JOpsResult
    JOpsResult -.->|"台帳の確認事項に未回答"| ReqAsk
    JOpsResult -.->|"完了条件に無い業務の決定が要る"| Req
    JOpsResult -.->|"不具合（是正）"| Fix
    JOpsResult -.->|"不具合（機能の変更）"| Implement
    JOpsResult -->|"作り終えた"| OpsOk
    OpsOk --> JOpsOk
    JOpsOk -.->|"承認しない（直す）"| OpsArtifacts
    JOpsOk -->|"承認した"| JEvidence
    JEvidence -->|"なる"| Evidence
    JEvidence -->|"ならない"| ReviewRound
    Evidence -->|"受入の証拠（確定）"| ReviewRound
    ReviewRound -->|"レビュー結果"| JReview
    JReview -->|"変更要求（不具合）"| Fix
    JReview -->|"変更要求（機能の変更）"| Implement
    JReview -->|"判断を人へ戻す・2回合意できない"| H
    H -->|"決定に従って（不具合）"| Fix
    H -->|"決定に従って（機能の変更）"| Implement
    JReview -->|"承認"| Audit
    Audit -->|"完了判定"| JAudit
    JAudit -->|"条件付き: 示された手順の後にやり直す"| Audit
    JAudit -->|"止める（不具合）"| Fix
    JAudit -->|"止める（機能の変更）"| Implement
    JAudit -->|"進めてよい"| FinalOk
```

判定の中身:

| 判定 | 結果ごとの工程 |
|---|---|
| A. 既存の利用側がある処理（共有の処理、外部との連携）に触るか | 触るなら `survey` と `baseline` |
| B. 不具合を直すのか、機能を変えるのか | 不具合なら `fix`、機能の変更なら `req`、`test-design`、`implement`。両方あれば分けて進める |
| C. 仕様書が無い・信用できない、または原因の切り分けに今の動きの把握が要るか | 当たれば `survey`。仕様書が無いときは、人が確かめた問題台帳と現状の振る舞いの記録を、その後の工程の原典の参照にする |
| 作業に分ける条件 | 通常の道、B が両方、設計の判断に波及や順序の制約がある、同じ形の箇所をまとめて直す承認がある、並べて進める。どれかに当たれば `tasks` |

`formal-check`・`data-audit`・`survey-ask` は `survey` から寄り道して `survey` に戻り、`primary-source`・`domain-model`・`req-ask` は `req` から寄り道して `req` に戻る。`screen`・`wireframe`・`screen-ok` は本線で、要件を書き終え、仕様化を終えるときの検査を通した後にだけ入り、`screen` の後は必ず `screen-ok` を通る。既存の画面を踏襲するときは、`screen` で踏襲する範囲の表を人と合意してから差分だけを設計する。`screen-ok` の意見はどれも `req` で確認事項の記録の行にして振り分ける。`design` は、規模の判定が要るとした観点の単位だけを、責務の配置 → 認可 → システム間の連携 → データ → エラー → デザインシステム → 非同期の実行 → 文面 → ログ → 呼ばれる契約 → 応答と入口の安全 → エージェント向けの契約 の順に使う。是正（`fix`）の方針が契約・エラー・データ・非同期の実行・システム間の連携を変えると分かったら、是正を止め、B を機能の変更に切り替えて `req` へ進む。是正で作業に分ける条件に当たったら、`test-design` でテストケース表を作り、`tasks` で分けてから作業ごとに `fix` を進める。モデルの検査（`formal-check`）は、今の実装を対象なら `survey` の中で、`design` の設計を対象なら `design` の後に行い、反例の扱いは `design-ok` で人が決める。`test-design` の `dev-acceptance-e2e` は、画面をまたぐ流れが変わるか、既存の E2E がある処理の状態や導線を変えるときに使う。

決まり:

- `baseline` は、`fix`・`implement` より前に通す。確定した重要な不具合で急ぐときは、是正と並べて固め、`audit` の前に是正の前の版で通したことを確かめる。
- 基準を通すために動きを直したり、期待値を黙って変えたりしない。期待値は `baseline-update` で、区分と根拠を付けて変える。
- 業務規則が変わるときは、モデルを先に直し（`domain-model`）、要件はそれを根拠に書く（`req`）。今の画面でできることを、要件の根拠にしない。仮説・未確定の業務規則（`survey` で抜き出した候補、一次情報から推定したものを含む）を要件と設計の根拠にせず、`domain-model`・`req-ask` で確定させる。業務規則の回答は、どの結果でも `domain-model` で一覧に反映する。`req` を終える前に型の一覧の「仕様化を終えるときの検査」を、`design` を終える前に「設計を終えるときの検査」を通す。
- 規模の判定は `sizing`、原因や設計が固まった時（`sizing-after-design`）、`sizing-after-implement`（実際の差分で）の3回行う。作業に分けて道が変わったときも判定し直す。道の正本は最新の規模の判定で、`tasks` を行ったら通常の道。
- 設計の判断に人の決定待ちが残っている作業は始めない。モデルの検査とデータの規則違反の監査は人が依頼するまで始めない。
- E2E の範囲を縮めること（既存の E2E の廃止を含む）は、人の承認を待つ。
- 受入の証拠は確定してから `review-round` と `audit` に回す。確定の後に関係する所を変えたら、`evidence` をやり直す。
- 同じ範囲に是正・人の判断・調べが残っていれば、`audit` へ進めない。
- `implement`（と、`tasks` で分けた是正の `fix`）の差分の点検は、実装した側の点検で、`review-round` のレビューの代わりにしない。依頼文に写すのは、点検した範囲と見なかった観点だけ。設計の判断と違う実装は判断に合わせ、判断を見直すと人が決めたら `design` に戻る。

### 入口（一言の依頼から入る工程）

| 依頼の言い方・状況 | 入る工程 |
|---|---|
| 「この不具合を直して」 | `intake` → `sizing` → `fix`（A か C に当たれば `survey`・`baseline` を先に） |
| 「この課題を進めて」 | `intake` → `sizing`（B を判定してから `fix` か `req` → `test-design` → `implement`） |
| 「既存システムに新しい機能を足したい」 | `intake` → `sizing` → `req` → `design`（要るとき）→ `test-design` → `tasks`（条件に当たれば）→ `implement`（A に当たれば `survey`・`baseline` を先に） |
| 「この変更の要件を書いて」「要望との差を要件にして」 | `req` |
| 「既存のコードから業務規則を洗い出して」 | `survey`（業務規則の抽出） |
| 「今の画面を踏襲して差分だけ設計して」「この画面の流れを変えたい」 | `intake` → `sizing` → `req` → `screen`（今の画面の記録が無ければ `survey` を先に） |
| 「ワイヤーを作って」「画面のたたき台を見せられる形にして」 | `wireframe`（画面の設計が無ければ `screen` から） |
| 「既存のデザインシステムに合わせて」「この部品の仕様を決めて」 | `design`（デザインシステム） |
| 「既存のデータが規則を守っているか調べて」 | `data-audit` |
| 「この権限を変えたい」「組織をまたいでデータが見えないようにしたい」 | `intake` → `sizing` → `survey` → `req` → `design`（認可） |
| 「既存のアプリに MCP サーバーを組み込みたい」 | `intake` → `sizing` → `req` → `design`（認可とエージェント向けの契約） |
| 「もう直ってるはず」「再現しないと言われた」 | `fix`（現実の確認から） |
| 「同じような不具合がほかにないか見て」 | `fix`（同じ形の箇所の探索だけ） |
| 「既存の動きを壊さずに直したい」「改修前に今の動きを固めておきたい」 | `intake` → `survey`（記録が無ければ）→ `baseline` |
| 「今どう動いているか調べて」「現状の仕様を洗い出して」 | `survey` |
| 「〜の処理はどこ？」「この関数を変えると、どこに影響する？」 | `survey`（場所の探索だけ。通しの調査や台帳は作らない） |
| 「この共通処理を変えたい」「この外部連携を作り直したい」「既存システムを改修したい」 | `intake` → `sizing` → `survey` → `baseline` |
| 「期待値が変わったけどテストを直していい？」 | `baseline-update` |
| 「コミットの前に差分を点検して」「この作業の実装が設計どおりか確かめて」 | `implement`（作業の終わりの点検） |
| 「この録画を提出していい？」「画面の証拠を確かめて」 | `evidence` |
| 「直したのでレビューして」 | `review-round` |
| 「もう閉じていい？」 | `audit` |

## 3. 新規開発（`dev-profile-new-feature`）

```mermaid
flowchart TD
    Request(["依頼"])
    Sizing["sizing<br/>受付と規模の判定<br/>dev-change-sizing"]
    Req["req<br/>要件を書く<br/>dev-requirements<br/>識別子と道を書く"]
    PrimarySource["primary-source<br/>一次情報を調べる<br/>dev-external-domain-survey<br/>dev-statutory-grounding"]
    DomainModel["domain-model<br/>モデルを作る<br/>dev-domain-model"]
    ReqAsk["req-ask<br/>人に確かめる（人）<br/>仮説・未確定の規則"]
    JScreen{"画面が済んでいるか"}
    Screen["screen<br/>画面を設計する<br/>dev-screen-design"]
    JWire{"人に画面を見せて<br/>確かめたいか"}
    Wireframe["wireframe<br/>ワイヤーを作る<br/>dev-wireframe"]
    ScreenOk(["screen-ok<br/>画面の設計を採る（人）"])
    JScreenOk{"意見があるか・採るか"}
    JAcceptance{"画面をまたぐ流れか<br/>判定できるか疑わしい"}
    Acceptance["acceptance<br/>受入条件を確かめる<br/>dev-acceptance-e2e"]
    JDesign{"設計の観点が要るか"}
    Design["design<br/>設計する（要る観点だけ）<br/>dev-responsibility-design<br/>dev-authorization-design<br/>dev-api-contract<br/>dev-error-design<br/>dev-data-design<br/>dev-async-execution-design<br/>dev-cross-system-design<br/>dev-logging-design<br/>dev-entry-safety-design<br/>dev-agent-contract<br/>dev-design-system<br/>dev-message-design"]
    FormalCheck["formal-check<br/>モデルで検査する<br/>dev-formal-model-check<br/>（人が依頼したとき）"]
    DesignOk["design-ok<br/>設計を承認する（人）<br/>決定待ちを決め、担当の案を採る"]
    SizingAfterDesign["sizing-after-design<br/>規模を判定し直す<br/>dev-change-sizing"]
    TestCases["test-cases<br/>テストケースを導く<br/>dev-test-case-design"]
    JTasks{"通常の道か"}
    Tasks["tasks<br/>作業に分ける<br/>dev-task-breakdown"]
    Implement["implement<br/>実装する<br/>dev-test-first（既定）<br/>dev-diff-check（作業の終わり）"]
    SizingAfterImplement["sizing-after-implement<br/>規模を判定し直す<br/>dev-change-sizing（実際の差分で）"]
    JOps{"運用の作業・文書に<br/>当たるか"}
    OpsArtifacts["ops-artifacts<br/>運用の成果物と利用者向けの文書を作る<br/>dev-production-procedure<br/>dev-credential-catalog<br/>dev-personal-info-ledger<br/>dev-user-manual"]
    JOpsResult{"手元で流した結果<br/>確認事項・業務の決定"}
    OpsOk(["ops-ok<br/>運用の成果物と利用者向けの文書を承認する（人）"])
    JOpsOk{"承認するか"}
    JEvidence{"画面・録画・帳票が<br/>証拠になるか"}
    Evidence["evidence<br/>受入の証拠を確かめる<br/>dev-evidence-check"]
    ReviewRound["review-round<br/>レビュー<br/>dev-review-brief → dev-review-conduct<br/>（別の担当）"]
    JReview{"判定"}
    H(["人の決定"])
    Audit["audit<br/>完了前に監査する<br/>dev-completion-audit"]
    JAudit{"判定"}
    FinalOk(["final-ok<br/>人の最終確認"])

    Request --> Sizing
    Sizing -->|"規模の判定"| Req
    Req -.->|"外部の仕様・公的な規則の確かめが要る"| PrimarySource
    PrimarySource -.->|"一次情報の記録"| Req
    Req -.->|"新しい概念・規則がある・根拠の規則に仮説がある"| DomainModel
    DomainModel -->|"ドメインモデル・業務規則の一覧"| Req
    DomainModel -->|"仮説・未確定がある"| ReqAsk
    Req -.->|"要件の確認事項に未回答がある"| ReqAsk
    ReqAsk -->|"業務規則の回答: 一覧に反映する"| DomainModel
    ReqAsk -->|"要件・画面の回答"| Req
    ReqAsk -.->|"台帳の回答"| OpsArtifacts
    Req -->|"要件を書き終えた: 完了条件の一覧"| JScreen
    JScreen -->|"済んでいない"| Screen
    JScreen -->|"済んでいる"| JAcceptance
    Screen -.->|"受入条件の案・確認事項の候補・入力情報か判断の欠け"| Req
    Screen -->|"画面の設計"| JWire
    JWire -->|"はい"| Wireframe
    JWire -->|"いいえ"| ScreenOk
    Wireframe -->|"ワイヤー"| ScreenOk
    Wireframe -.->|"画面の設計を変える案"| Screen
    ScreenOk --> JScreenOk
    JScreenOk -.->|"意見がある・採らない: 確認事項の記録で振り分ける"| Req
    JScreenOk -->|"採った（設計から戻った画面。先に見る）"| Design
    JScreenOk -->|"採った: 採った版の所在"| JAcceptance
    JAcceptance -->|"はい"| Acceptance
    JAcceptance -->|"いいえ"| JDesign
    Acceptance -->|"テストケース表（E2E）"| JDesign
    Acceptance -.->|"受入条件の書き直しの案を採る"| Req
    Design -.->|"新しく外部に依存する・完了条件に無い業務の決定が要る・画面の契機が無いのに画面が要る"| Req
    Design -.->|"画面の契機があり、認可・エラー・デザインシステム・文面で画面が変わる"| Screen
    JDesign -->|"要る"| Design
    JDesign -->|"要らない"| TestCases
    Design -->|"設計の判断"| DesignOk
    Design -.->|"人が依頼したとき"| FormalCheck
    FormalCheck -->|"検証の記録・問題台帳"| DesignOk
    DesignOk -->|"設計の判断（決定済み）"| SizingAfterDesign
    SizingAfterDesign -->|"規模の判定"| TestCases
    DesignOk -.->|"反例・決定待ちの決定・人の直しの求めで設計を直す"| Design
    TestCases -->|"テストケース表・追跡表"| JTasks
    JTasks -->|"はい"| Tasks
    JTasks -->|"いいえ（軽い道）"| Implement
    Tasks -->|"作業の一覧・追跡表"| Implement
    Implement -.->|"軽い道の実装中に作業が増えた（観点が要る）・点検で設計の判断を見直すと決まった"| Design
    Implement -.->|"軽い道の実装中に作業が増えた（観点は要らない）"| Tasks
    Implement -->|"変更の事実・作業の一覧"| SizingAfterImplement
    SizingAfterImplement -->|"規模の判定"| JOps
    SizingAfterImplement -.->|"①完了条件の承認し直しが要る"| Req
    SizingAfterImplement -.->|"②要る観点に設計の判断が無い（実際の差分で）"| Design
    SizingAfterImplement -.->|"③通常の道に変わり、作業の一覧が無い"| Tasks
    JOps -->|"当たる"| OpsArtifacts
    JOps -->|"当たらない"| JEvidence
    OpsArtifacts -->|"本番の手順・目録・台帳"| JOpsResult
    JOpsResult -.->|"台帳の確認事項に未回答"| ReqAsk
    JOpsResult -.->|"完了条件に無い業務の決定が要る"| Req
    JOpsResult -.->|"手元で流して不具合"| Implement
    JOpsResult -->|"作り終えた"| OpsOk
    OpsOk --> JOpsOk
    JOpsOk -.->|"承認しない（直す）"| OpsArtifacts
    JOpsOk -->|"承認した"| JEvidence
    JEvidence -->|"なる"| Evidence
    JEvidence -->|"ならない"| ReviewRound
    Evidence -->|"受入の証拠（確定）"| ReviewRound
    ReviewRound -->|"レビュー結果"| JReview
    JReview -->|"変更要求"| Implement
    JReview -->|"判断を人へ戻す・2回合意できない"| H
    H -->|"決定に従って"| Implement
    JReview -->|"承認"| Audit
    Audit -->|"完了判定"| JAudit
    JAudit -->|"条件付き: 示された手順の後にやり直す"| Audit
    JAudit -->|"止める: 原因の工程へ"| Implement
    JAudit -->|"進めてよい"| FinalOk
```

決まり:

- 完了条件の一覧には、項目ごとの識別子を書き、道はどの規模の判定に従うかを指す（道の正本は最新の規模の判定）。
- `primary-source`・`domain-model`・`req-ask` は `req` から寄り道して `req` に戻る。業務規則が変わるときは、モデルを先に作り（`domain-model`）、要件はそれを根拠に書く。仮説・未確定の業務規則（一次情報から推定したものを含む）を要件と設計の根拠にせず、`domain-model`・`req-ask` で確定させる。業務規則の回答は、どの結果でも `domain-model` で一覧に反映する。`req` を終える前に型の一覧の「仕様化を終えるときの検査」を、`design` を終える前に「設計を終えるときの検査」を通す。
- `design` の単位は、要るものを 責務の配置 → 認可 → システム間の連携 → データ → エラー → デザインシステム → 非同期の実行 → 文面 → ログ → 呼ばれる契約 → 応答と入口の安全 → エージェント向けの契約 の順に使う。後の単位が前の判断の前提を変えたら、前の判断を直して承認の状態を戻す。
- 画面の工程（`screen`・`wireframe`・`screen-ok`）には、要件を書き終え、仕様化を終えるときの検査を通した後にだけ入る。`screen` の後は必ず `screen-ok` を通る。`screen-ok` の意見はどれも `req` で確認事項の記録の行にして振り分け、画面やワイヤーだけで直さない。採った版の所在を、原典の参照として下流に渡す。
- 設計の判断に人の決定待ちが残っている作業は始めない。モデルの検査は人が依頼するまで始めない。反例の扱いは `design-ok` で人が決める。
- 道が軽い道から通常の道に変わったら（`sizing-after-design`、作業に分けた後、軽い道の実装中のどれでも）、実装を止めて `design` と `tasks` を通す。
- `sizing-after-implement` の判定は、承認し直し（①）→ 要る観点の設計（②）→ 作業の一覧（③）→ 通常の続行 の順に見る（図の矢印の番号）。
- 受入の証拠は確定してから `review-round` と `audit` に回す。E2E の範囲を縮めることは、人の承認を待つ。
- 型の一覧の「道に応じた検査」が通らない項目が残っていれば、`audit` で「進めてよい」にしない。
- `implement` の差分の点検は、実装した側の点検で、`review-round` のレビューの代わりにしない。依頼文に写すのは、点検した範囲と見なかった観点だけ。設計の判断と違う実装は判断に合わせ、判断を見直すと人が決めたら `design` に戻る。

### 入口（一言の依頼から入る工程）

| 依頼の言い方・状況 | 入る工程 |
|---|---|
| 「新しい機能を作りたい」「新規開発を進めて」 | `sizing` から |
| 「要件は決まったので設計して」 | `sizing`（完了条件の一覧を入力に）→ `req`（受けて確かめるだけ）→ `design` |
| 「要望から要件を起こして」「受入条件を書いて」 | `req` |
| 「ドメインモデルを作って」「業務の用語と規則を整理して」 | `domain-model` |
| 「この外部 API の仕様を調べて」「この計算が法令どおりか確かめて」 | `primary-source` |
| 「画面設計をして」「画面一覧を作って」「画面遷移を決めて」 | `screen`（完了条件の一覧が無ければ `sizing` から） |
| 「ワイヤーを作って」「画面のたたき台を見せられる形にして」 | `wireframe`（画面の設計が無ければ `screen` から） |
| 「デザインシステムを作って」「トークンを整理して」「この部品の仕様を決めて」 | `design`（デザインシステム） |
| 「タスクに分けて」「作業計画を立てて」 | `tasks`（テストケース表が無く通常の道なら `test-cases` を先に） |
| 「この機能のテストを洗い出して」 | `test-cases` |
| 「テストを先に書いて実装して」 | `implement` |
| 「コミットの前に差分を点検して」「この作業の実装が設計どおりか確かめて」 | `implement`（作業の終わりの点検） |
| 「形式手法で確かめて」 | `formal-check` |
| 「誰がこの操作をできるか決めて」「他人のデータが見えないようにしたい」 | `design`（認可） |
| 「アプリに MCP サーバーを組み込みたい」 | `sizing` から（`design` でエージェント向けの契約） |
| 「直したのでレビューして」 | `review-round` |
| 「もう閉じていい？」 | `audit` |

## 4. 中断と再開（`dev-profile-interrupt-resume`）

```mermaid
flowchart TD
    IN(["中断した組み合わせの工程"])
    JEntry{"中断するか・再開するか<br/>結果が届いたか"}
    Handoff["handoff<br/>引継ぎを書く<br/>dev-work-continuity<br/>（控えを先に取る）"]
    JHandoff{"渡し方"}
    Receipt["receipt<br/>受け取りを確かめる<br/>dev-work-continuity"]
    JReceipt{"届いたか<br/>委任だけか"}
    Resume["resume<br/>再開して照らす<br/>dev-work-continuity"]
    DelegateResult["delegate-result<br/>委任の結果を統合する<br/>dev-work-continuity"]
    JResume{"人に確かめる<br/>条件に当たるか"}
    ResumeAsk(["resume-ask<br/>人に確かめる"])
    JAsk{"人の決定"}
    Return(["return<br/>続きに戻る<br/>（元の組み合わせの工程）"])

    IN --> JEntry
    JEntry -->|"中断する・委任する<br/>作業の一覧・完了条件の一覧ほか"| Handoff
    JEntry -->|"記録から再開する"| Resume
    JEntry -->|"委任の結果が届いた<br/>完了の主張"| DelegateResult
    Handoff -->|"引継ぎの記録・作業状態の控え・委任の依頼文"| JHandoff
    JHandoff -->|"委任した・交代する担当に渡した"| Receipt
    JHandoff -.->|"次のセッションが続ける（中断の間）"| Resume
    Receipt --> JReceipt
    JReceipt -->|"委任だけで受け取りを確かめた"| Return
    JReceipt -->|"送れなかった・相手が終わっていた"| ResumeAsk
    JReceipt -.->|"受け取りを確かめた（中断の間）"| Resume
    Resume -->|"引継ぎの記録（再開の記録）"| JResume
    DelegateResult -->|"引継ぎの記録（委任の状態）"| JResume
    JResume -->|"当たる"| ResumeAsk
    JResume -->|"当たらない"| Return
    ResumeAsk --> JAsk
    JAsk -->|"記録を選び直す・直す・伝言が届いた"| Resume
    JAsk -->|"続け方を決めた"| Return
```

### 入口（一言の依頼から入る工程）

| 依頼の言い方・状況 | 入る工程 |
|---|---|
| 「ここで中断して、続きは次にやる」「次のセッションに引き継いで」 | `handoff` |
| 「この作業を別の担当に頼みたい」「この部分を委任して」 | `handoff`（委任の依頼文を書く） |
| 「続きから再開して」「前のセッションの続きをやって」（引継ぎの記録がある） | `resume` |
| 「続きをやって」（記録が見つからない） | `resume`（推定して `resume-ask` へ） |
| 「頼んでいた作業の結果が届いた」「委任先の報告をまとめて」 | `delegate-result` |

## 5. 版管理の作業（`dev-profile-version-control`）

```mermaid
flowchart TD
    IN(["依頼・元の組み合わせの作業"])
    JEntry{"どの作業から<br/>始めるか"}
    Workspace["workspace<br/>作業場所を作る<br/>dev-isolated-workspace"]
    Work["work<br/>作業する<br/>（元の組み合わせの工程）"]
    Integrate["integrate<br/>取り込む<br/>（取り込み・確認）"]
    Resolve["resolve<br/>衝突を解く<br/>dev-conflict-resolution"]
    ContractAsk(["contract-ask<br/>人が決める"])
    Recover["recover<br/>困りごとから戻す<br/>dev-history-recovery"]
    DestructiveOk(["destructive-ok<br/>破壊的な操作を承認する"])
    Cleanup["cleanup<br/>片付ける<br/>dev-isolated-workspace"]
    END(["終わり"])

    IN --> JEntry
    JEntry -->|"作業場所を作る"| Workspace
    JEntry -->|"統合する"| Integrate
    JEntry -->|"衝突を解く"| Resolve
    JEntry -->|"トラブルから戻す"| Recover
    JEntry -->|"片付ける"| Cleanup
    Workspace -->|"作業場所の台帳・作業状態の控え<br/>隔離を確かめた"| Work
    Work -->|"変更の事実・作業状態の控え<br/>統合する"| Integrate
    Work -.->|"トラブルが起きた"| Recover
    Integrate -->|"衝突・統合後の不整合"| Resolve
    Integrate -.->|"トラブルが起きた"| Recover
    Integrate -->|"検証の記録・統合完了または破棄承認<br/>片付けへ"| Cleanup
    Integrate -->|"衝突なし・片付け不要"| END
    Resolve -->|"未決の契約の変化がある<br/>統合の判断表"| ContractAsk
    ContractAsk -->|"原典の参照<br/>契約の選択を決めた"| Resolve
    Resolve -.->|"トラブルが起きた"| Recover
    Resolve -->|"解消完了・取り込み完了と確認へ"| Integrate
    Resolve -->|"解消完了・作業場所を残すか無し"| END
    Recover -->|"印に取り返せない・外部道具の導入<br/>破壊的操作の計画"| DestructiveOk
    DestructiveOk -->|"承認した"| Recover
    DestructiveOk -->|"中止して終わる"| END
    Recover -.->|"作業中のトラブルを復旧し戻る"| Work
    Recover -->|"復旧後に衝突の解消が要る"| Resolve
    Recover -->|"復旧完了・取り込み完了と確認へ"| Integrate
    Recover -->|"復旧完了・作業場所を残すか無し"| END
    Cleanup -->|"作業場所の台帳（片付け済み）"| END
```

### 入口（一言の依頼から入る工程）

| 依頼の言い方・状況 | 入る工程 |
|---|---|
| 「worktree で進めたい」「並列で安全に作業したい」「別の作業場所を作って」 | `workspace` |
| 「終わったので本線に取り込んで」「別の枝を統合したい（衝突はまだ無い）」 | `integrate` |
| 「コンフリクトを解消して」「rebase で衝突した」「取り込みで衝突や食い違いが出た」「両方残して統合するか判断して」 | `resolve` |
| 「push が拒否された」「大きいファイルをコミットしてしまった」「秘密をコミットに含めてしまった」「detached HEAD になった」「直前のコミットを取り消したい」 | `recover` |
| 「worktree を片付けて」 | `cleanup` |

## 6. 依存の更新（`dev-profile-dependency-upkeep`）

```mermaid
flowchart TD
    Intake(["intake<br/>受付（人）<br/>告知への対応か、定期の更新か"])
    JEntry{"入口"}
    AdvisoryCheck["advisory-check<br/>告知を点検する<br/>dev-advisory-check"]
    TriageAsk(["triage-ask<br/>直すかを決める（人）<br/>直す・受け入れる・保留"])
    JTriage{"直す行があるか"}
    JB{"基準を固める<br/>条件に当たるか"}
    Baseline["baseline<br/>上げる前の基準を固める<br/>dev-current-behavior-survey<br/>dev-regression-baseline"]
    Bump["bump<br/>版を上げる<br/>dev-dependency-bump"]
    JBump{"追随のコード<br/>期待値の変化"}
    DiffCheck["diff-check<br/>差分を点検する<br/>dev-diff-check"]
    JDiff{"高の指摘<br/>期待値の変化"}
    BaselineUpdate["baseline-update<br/>基準を更新する<br/>dev-regression-baseline<br/>（人が採った決めた動きだけを根拠に）"]
    SizingAfterImplement["sizing-after-implement<br/>規模を判定し直す<br/>dev-change-sizing"]
    JP{"運用の作業「本番の手順」が<br/>当たるか"}
    Procedure["procedure<br/>本番の手順を作る<br/>dev-production-procedure"]
    ProcedureOk(["procedure-ok<br/>本番の手順を承認する（人）"])
    JProcedureOk{"承認するか"}
    ReviewRound["review-round<br/>レビュー<br/>dev-review-brief → dev-review-conduct"]
    JReview{"レビューの判定"}
    Audit["audit<br/>完了前に監査する<br/>dev-completion-audit"]
    JAudit{"監査の判定"}
    FinalOk(["final-ok<br/>最終確認（人）"])

    Intake -->|"改修の範囲"| JEntry
    JEntry -->|"告知への対応・先に照らす"| AdvisoryCheck
    JEntry -->|"定期の更新"| JB
    AdvisoryCheck -->|"安全の点検の記録・問題台帳"| TriageAsk
    TriageAsk --> JTriage
    JTriage -->|"直す行がある"| JB
    JTriage -->|"直す行が無い（当たらない・受け入れ・保留）<br/>点検の記録・問題台帳・方針外の課題の記録を外へ"| FinalOk
    JB -->|"当たる"| Baseline
    JB -->|"当たらない"| Bump
    Baseline -->|"回帰の基準"| Bump
    Bump -->|"是正の対応表・変更の事実・完了条件の一覧"| JBump
    Bump -->|"追随に設計が要る<br/>問題台帳・是正の対応表を外へ"| FinalOk
    JBump -->|"追随のコードがある"| DiffCheck
    JBump -->|"期待値が変わった"| BaselineUpdate
    JBump -->|"どちらも無い"| SizingAfterImplement
    DiffCheck --> JDiff
    JDiff -->|"高の指摘が残った"| Bump
    JDiff -->|"期待値が変わった"| BaselineUpdate
    JDiff -->|"期待値は変わらない"| SizingAfterImplement
    BaselineUpdate -->|"回帰の基準"| SizingAfterImplement
    SizingAfterImplement -->|"規模の判定"| JP
    JP -->|"当たる"| Procedure
    JP -->|"当たらない"| ReviewRound
    Procedure -->|"本番の手順・検証の記録"| ProcedureOk
    Procedure -.->|"手元で流して不具合（diff-check・baseline-update・sizing-after-implement を通し直す）"| Bump
    ProcedureOk --> JProcedureOk
    JProcedureOk -->|"承認しない（直す）"| Procedure
    JProcedureOk -->|"承認した（手順の所在をレビューへ）"| ReviewRound
    ReviewRound --> JReview
    JReview -->|"変更要求"| Bump
    JReview -->|"承認"| Audit
    Audit --> JAudit
    JAudit -->|"止める"| Bump
    JAudit -.->|"条件付き（手順の後にやり直す）"| Audit
    JAudit -->|"進めてよい<br/>完了判定"| FinalOk
```

### 入口（一言の依頼から入る工程）

| 依頼の言い方・状況 | 入る工程 |
|---|---|
| 「この脆弱性の告知に対応して」「この CVE はうちに当たる？」 | `intake` → `advisory-check` |
| 「依存の脆弱性を定期的に点検して」 | `intake` → `advisory-check`（直すと決めた行があれば `baseline` か `bump` へ） |
| 「依存を定期的に更新したい」「この部品を最新にして」 | `intake` → `baseline` か `bump`（告知を先に照らすなら `advisory-check`） |
| 「この版に上げて」（行き先の版が決まっている） | `intake` → `baseline` か `bump` |
| 「ロックを作り直して」 | `intake` → `bump` |
| 「上げたのでレビューして」 | `review-round` |
| 「もう閉じていい？」 | `audit` |

## 7. 今の状態の安全の点検（`dev-profile-exposure-sweep`）

```mermaid
flowchart TD
    Intake(["intake<br/>受付（人）<br/>範囲と、要求を送ってよい相手の許可"])
    EntryCheck["entry-check<br/>点検する<br/>dev-entry-safety-check<br/>dev-advisory-check（告知も見るとき）"]
    JEntryCheck{"問題がある行か<br/>人の判断が要る行"}
    TriageAsk(["triage-ask<br/>人が決める<br/>直す・受け入れる・事実を確かめる"])
    JTriage{"点検し直すか"}
    FinalOk(["final-ok<br/>最終確認（人）"])

    Intake -->|"改修の範囲・許可の記録"| EntryCheck
    EntryCheck -->|"安全の点検の記録・問題台帳"| JEntryCheck
    JEntryCheck -->|"ある"| TriageAsk
    JEntryCheck -->|"無い"| FinalOk
    TriageAsk --> JTriage
    JTriage -->|"この一巡で事実を確かめる・許可を広げた"| EntryCheck
    JTriage -->|"全部の行に人の決定<br/>方針外の課題の記録"| FinalOk
```

### 入口（一言の依頼から入る工程）

| 依頼の言い方・状況 | 入る工程 |
|---|---|
| 「今の公開サイトの安全の設定を点検して」「管理画面のヘッダと Cookie を見て」 | `intake` → `entry-check` |
| 「走査の道具の指摘を仕分けて」 | `intake` → `entry-check` |
| 「直したので点検し直して」 | `intake` → `entry-check`（前回の点検の記録を入力にする） |
| 「この指摘は受け入れていい？」 | `triage-ask` |

## 8. 引き継いだシステム（`dev-profile-inherited-system`）

```mermaid
flowchart TD
    Intake(["intake<br/>受付（人）<br/>範囲、前任者がいるか"])
    Map["map<br/>地図を作る<br/>dev-system-map<br/>dev-code-search（場所を探すとき）"]
    JMap{"問う事実確認が<br/>残っているか"}
    MapAsk(["map-ask<br/>前任者か人に確かめる<br/>合っている／違う／分からない"])
    JMapAsk{"答えを受けたか"}
    Catalog["catalog<br/>秘密の目録を作る<br/>dev-credential-catalog"]
    JCatalog{"個人の情報を扱うか<br/>未回答の事実確認"}
    Ledger["ledger<br/>個人情報の台帳を作る<br/>dev-personal-info-ledger"]
    JLedger{"未回答の確認事項<br/>か事実確認"}
    InventoryAsk(["inventory-ask<br/>人に確かめる"])
    JInventoryAsk{"答えの戻し先"}
    InventoryOk(["inventory-ok<br/>承認する（人）"])
    JInventoryOk{"承認するか"}
    E(["終わり（地図・目録・台帳を外へ）"])

    Intake -->|"改修の範囲"| Map
    Intake -.->|"承認した地図が既にある"| Catalog
    Map -->|"システムの地図・問題台帳"| JMap
    JMap -->|"ある"| MapAsk
    JMap -->|"無い・反映し終えた"| Catalog
    MapAsk --> JMapAsk
    JMapAsk -->|"答えを受けた（反映する）"| Map
    JMapAsk -->|"前任者がいない・答えられない"| Catalog
    Catalog -->|"秘密の目録"| JCatalog
    JCatalog -->|"扱う"| Ledger
    JCatalog -->|"扱わず、未回答がある"| InventoryAsk
    JCatalog -->|"扱わず、未回答も無い"| InventoryOk
    Ledger -->|"個人情報の台帳・確認事項の記録"| JLedger
    JLedger -->|"ある"| InventoryAsk
    JLedger -->|"無い"| InventoryOk
    InventoryAsk --> JInventoryAsk
    JInventoryAsk -->|"目録の事実確認"| Catalog
    JInventoryAsk -->|"台帳の確認事項"| Ledger
    JInventoryAsk -->|"期限つきで保留"| InventoryOk
    InventoryOk --> JInventoryOk
    JInventoryOk -->|"地図を直す"| Map
    JInventoryOk -->|"目録を直す"| Catalog
    JInventoryOk -->|"台帳を直す"| Ledger
    JInventoryOk -->|"承認"| E
```

### 入口（一言の依頼から入る工程）

| 依頼の言い方・状況 | 入る工程 |
|---|---|
| 「前任者から引き継いだシステムの現状を把握したい」「保守を引き継いだので、どこに何があるか整理したい」 | `intake` → `map` |
| 「ドキュメントの無いシステムの地図を作って」 | `intake` → `map` |
| 「引き継いだシステムの秘密を、値を見ずに一覧にして」 | `intake` → `map` → `catalog`（地図が既にあれば `intake` → `catalog`） |
| 「引き継いだシステムの個人情報の台帳を作って」 | `intake` → `map` → `catalog` → `ledger`（地図が既にあれば `intake` → `catalog` → `ledger`） |
| 「前任者の回答が届いた」 | `map-ask` か `inventory-ask` |

## 9. 単位の入力と出力

プロファイルを使わずに単位だけを使うときの早見表。型の中身は [型の一覧](../skills/dev-shared/references/artifact-types.md) を見る。

| 単位 | 必須の入力 | 条件付き・任意の入力 | 出力 |
|---|---|---|---|
| `dev-change-sizing` | — | 改修の範囲（既存を変えるとき）、完了条件の一覧、原典の参照、作業の一覧、設計の判断、変更の事実（終わる時） | 規模の判定 |
| `dev-requirements` | 原典の参照 | ドメインモデル、業務規則の一覧、一次情報の記録（公的な規則や外部の仕様が基準のとき）、現状の振る舞いの記録（既存を変えるとき）、問題台帳、規模の判定、確認事項の記録、完了条件の一覧（直すとき・受けるとき）、画面の設計（返された案を採否するとき） | 完了条件の一覧、確認事項の記録、問題台帳 |
| `dev-screen-design` | 完了条件の一覧 | 原典の参照、ドメインモデル、業務規則の一覧、設計の判断（認可・エラー・デザインシステム・文面の判断があるとき）、現状の振る舞いの記録（既存の画面を踏襲するとき）、確認事項の記録、画面の設計（直すとき） | 画面の設計 |
| `dev-wireframe` | 画面の設計 | 設計の判断、原典の参照 | ワイヤー |
| `dev-domain-model` | 原典の参照 | 規模の判定、一次情報の記録、現状の振る舞いの記録（既存を変えるとき）、業務規則の一覧、確認事項の記録 | ドメインモデル、業務規則の一覧、確認事項の記録、問題台帳 |
| `dev-rule-extraction` | 改修の範囲 | 業務規則の一覧、原典の参照 | 業務規則の一覧、問題台帳、検証の記録 |
| `dev-code-search` | — | 改修の範囲、ドメインモデル、原典の参照 | 現状の振る舞いの記録 |
| `dev-rule-violation-audit` | 業務規則の一覧、改修の範囲 | 原典の参照 | 問題台帳、検証の記録、テストケース表、変更の事実（試験のコードを残すとき） |
| `dev-external-domain-survey` | 原典の参照 | 完了条件の一覧、設計の判断、改修の範囲（既存の連携の障害を調べるとき） | 一次情報の記録 |
| `dev-statutory-grounding` | 原典の参照 | 業務規則の一覧、ドメインモデル、不具合の報告（不具合の調査の中で裏取りするとき） | 一次情報の記録、業務規則の一覧、確認事項の記録、問題台帳 |
| `dev-responsibility-design` | 原典の参照 | 完了条件の一覧、現状の振る舞いの記録、業務規則の一覧、ドメインモデル | 設計の判断、方針外の課題の記録 |
| `dev-authorization-design` | 完了条件の一覧 | 原典の参照、ドメインモデル、業務規則の一覧、設計の判断、現状の振る舞いの記録（既存の権限や分離を変えるとき） | 設計の判断 |
| `dev-api-contract` | 完了条件の一覧 | 原典の参照、設計の判断 | 設計の判断 |
| `dev-agent-contract` | 完了条件の一覧 | 原典の参照、設計の判断、一次情報の記録、現状の振る舞いの記録（既にある道具を変えるとき） | 設計の判断 |
| `dev-error-design` | 完了条件の一覧 | 原典の参照、設計の判断、業務規則の一覧 | 設計の判断 |
| `dev-design-system` | — | 原典の参照、完了条件の一覧、画面の設計、設計の判断 | 設計の判断 |
| `dev-message-design` | 完了条件の一覧 | 業務規則の一覧、ドメインモデル、画面の設計、設計の判断、一次情報の記録（法定の記載事項がありうるとき）、個人情報の台帳、現状の振る舞いの記録（今ある文面を変えるとき）、原典の参照 | 設計の判断 |
| `dev-logging-design` | 完了条件の一覧 | 原典の参照、設計の判断、現状の振る舞いの記録（既存の処理のログを変えるとき） | 設計の判断 |
| `dev-entry-safety-design` | 完了条件の一覧 | 原典の参照、設計の判断、現状の振る舞いの記録（既存の入口や応答の設定を変えるとき） | 設計の判断 |
| `dev-data-design` | 完了条件の一覧、原典の参照 | 現状の振る舞いの記録（既存の表を変えるとき）、業務規則の一覧、問題台帳（既存のデータの監査の結果）、ドメインモデル、設計の判断 | 設計の判断、検証の記録 |
| `dev-async-execution-design` | 完了条件の一覧 | 原典の参照、一次情報の記録、ドメインモデル、設計の判断、現状の振る舞いの記録（既存のジョブを変えるとき） | 設計の判断 |
| `dev-cross-system-design` | 完了条件の一覧、原典の参照 | 一次情報の記録、改修の範囲、現状の振る舞いの記録 | 設計の判断 |
| `dev-formal-model-check` | 原典の参照（人の依頼の記録を含む） | 設計の判断、現状の振る舞いの記録、変更の事実 | 検証の記録、問題台帳 |
| `dev-task-breakdown` | 完了条件の一覧 | テストケース表（通常の道では必須）、設計の判断、原典の参照、問題台帳、回帰の基準、是正の対応表、方針外の課題の記録、作業の一覧 | 作業の一覧、追跡表 |
| `dev-review-brief` | 変更の事実、原典の参照 | 検証の記録、レビュー結果（再依頼のとき） | レビュー依頼文 |
| `dev-review-conduct` | レビュー依頼文、または変更の事実と原典の参照 | — | レビュー結果、方針外の課題の記録 |
| `dev-completion-audit` | 完了の主張、完了条件の一覧、検証の記録 | 追跡表、作業の一覧、テストケース表、レビュー結果、方針外の課題の記録、設計の判断、規模の判定、受入の証拠、業務規則の一覧、ドメインモデル、画面の設計 | 作業状態の控え、完了判定 |
| `dev-work-continuity` | 再開するとき: 引継ぎの記録、作業状態の控え／委任の結果を統合するとき: 完了の主張 | 作業の一覧、完了条件の一覧、設計の判断、確認事項の記録、問題台帳、変更の事実、検証の記録、レビュー結果、規模の判定、方針外の課題の記録、原典の参照、委任の依頼文 | 引継ぎの記録、作業状態の控え、委任の依頼文 |
| `dev-isolated-workspace` | 原典の参照、作業状態の控え | 作業の一覧、作業場所の台帳、検証の記録 | 作業場所の台帳、作業状態の控え、検証の記録 |
| `dev-conflict-resolution` | 変更の事実、原典の参照、作業状態の控え | 設計の判断、業務規則の一覧、ドメインモデル、完了条件の一覧 | 統合の判断表、変更の事実、検証の記録 |
| `dev-history-recovery` | 作業状態の控え | 原典の参照、引継ぎの記録、破壊的操作の計画（承認後の実行時） | 破壊的操作の計画、作業状態の控え、検証の記録 |
| `dev-current-behavior-survey` | 改修の範囲 | 原典の参照 | 現状の振る舞いの記録、問題台帳 |
| `dev-regression-baseline` | 新しく固めるとき: 現状の振る舞いの記録／更新するとき: 回帰の基準 | 問題台帳、業務規則の一覧、是正の対応表、完了条件の一覧、変更の事実 | 回帰の基準、検証の記録 |
| `dev-production-procedure` | 変更の事実 | 原典の参照、検証の記録、是正の対応表、設計の判断、システムの地図、秘密の目録、規模の判定、本番の手順（直すとき） | 本番の手順、検証の記録 |
| `dev-system-map` | 改修の範囲 | システムの地図（更新のとき）、問題台帳（答えを反映するとき）、原典の参照、現状の振る舞いの記録 | システムの地図、問題台帳 |
| `dev-credential-catalog` | 改修の範囲 | 秘密の目録（更新のとき）、変更の事実（変更に合わせるとき）、原典の参照、システムの地図 | 秘密の目録、問題台帳 |
| `dev-personal-info-ledger` | 改修の範囲 | 個人情報の台帳（更新のとき）、変更の事実（変更に合わせるとき）、原典の参照、確認事項の記録、一次情報の記録、システムの地図 | 個人情報の台帳、確認事項の記録 |
| `dev-user-manual` | — | 画面の設計、完了条件の一覧、テストケース表、設計の判断、操作マニュアル（直すとき）、原典の参照 | 操作マニュアル、問題台帳 |
| `dev-entry-safety-check` | 改修の範囲、原典の参照（要求を送るとき。許可の記録） | 安全の点検の記録（前回）、設計の判断 | 安全の点検の記録、問題台帳、検証の記録 |
| `dev-advisory-check` | 改修の範囲 | 原典の参照、安全の点検の記録（前回） | 安全の点検の記録、問題台帳、検証の記録 |
| `dev-dependency-bump` | 改修の範囲 | 問題台帳（告知への対応のとき）、安全の点検の記録、原典の参照、回帰の基準 | 是正の対応表、変更の事実、検証の記録、完了条件の一覧、方針外の課題の記録、完了の主張 |
| `dev-defect-fix` | 不具合の報告か問題台帳 | 原典の参照、回帰の基準 | 是正の対応表、変更の事実、検証の記録、方針外の課題の記録、完了条件の一覧、完了の主張 |
| `dev-test-case-design` | 完了条件の一覧か現状の振る舞いの記録 | 原典の参照、追跡表、問題台帳、設計の判断、業務規則の一覧 | テストケース表、追跡表 |
| `dev-acceptance-e2e` | 完了条件の一覧 | 原典の参照、テストケース表 | テストケース表（E2E）、完了条件の一覧（書き直しの案） |
| `dev-diff-check` | 変更の事実、完了条件の一覧 | 作業の一覧、設計の判断、業務規則の一覧、ドメインモデル、テストケース表、是正の対応表、回帰の基準、原典の参照 | 検証の記録、方針外の課題の記録 |
| `dev-test-first` | 完了条件の一覧か不具合の報告 | テストケース表、回帰の基準、作業の一覧、設計の判断 | 変更の事実、検証の記録、方針外の課題の記録、完了の主張、作業の一覧（受け取ったとき） |
| `dev-evidence-check` | 検証の記録と、テストケース表か完了条件の一覧 | 変更の事実 | 受入の証拠、検証の記録 |

型でつながる様子（どの単位の出力が、どの単位の入力になるか）。点線の矢印は、更新や再依頼のときに戻る流れ。

```mermaid
flowchart TD
    sizing["dev-change-sizing<br/>規模を判定する"]
    survey["dev-current-behavior-survey<br/>今の動きを調べる"]
    baseline["dev-regression-baseline<br/>回帰の基準を固める"]
    rules["dev-rule-extraction<br/>業務規則を抜き出す"]
    search["dev-code-search<br/>コードの場所を探す"]
    violation["dev-rule-violation-audit<br/>データの規則違反を監査する"]
    primary["dev-external-domain-survey<br/>dev-statutory-grounding<br/>一次情報を調べる"]
    model["dev-domain-model<br/>モデルを作る・直す"]
    req["dev-requirements<br/>要件を書く"]
    screen["dev-screen-design<br/>画面を設計する"]
    wire["dev-wireframe<br/>ワイヤーを作る"]
    design["設計の単位<br/>dev-responsibility-design<br/>dev-authorization-design<br/>dev-api-contract<br/>dev-error-design<br/>dev-data-design<br/>dev-async-execution-design<br/>dev-cross-system-design<br/>dev-logging-design<br/>dev-entry-safety-design<br/>dev-agent-contract<br/>dev-design-system<br/>dev-message-design"]
    formal["dev-formal-model-check<br/>モデルで検査する"]
    tcd["dev-test-case-design<br/>テストケースを導く"]
    e2e["dev-acceptance-e2e<br/>受入条件と E2E を設計する"]
    plan["dev-task-breakdown<br/>作業に分ける"]
    fix["dev-defect-fix<br/>不具合を是正する"]
    tf["dev-test-first<br/>テストを先に書いて実装する"]
    dc["dev-diff-check<br/>差分を点検する"]
    ev["dev-evidence-check<br/>受入の証拠を確かめる"]
    brief["dev-review-brief<br/>レビュー依頼文を書く"]
    conduct["dev-review-conduct<br/>独立してレビューする"]
    audit["dev-completion-audit<br/>完了前に監査する"]
    cont["dev-work-continuity<br/>引き継ぎ、再開する"]
    ws["dev-isolated-workspace<br/>作業場所を分ける"]
    conf["dev-conflict-resolution<br/>統合の衝突を解く"]
    rec["dev-history-recovery<br/>履歴・状態を復旧する"]

    sizing -->|"規模の判定"| req
    survey -->|"現状の振る舞いの記録・問題台帳"| baseline
    survey -->|"問題台帳・現状の振る舞いの記録"| req
    survey -->|"現状の振る舞いの記録"| design
    survey -->|"現状の振る舞いの記録"| model
    rules -->|"業務規則の一覧（仮説）"| model
    search -->|"現状の振る舞いの記録"| design
    model -->|"ドメインモデル"| search
    rules -->|"業務規則の一覧"| violation
    violation -->|"問題台帳"| req
    primary -->|"一次情報の記録・業務規則の一覧"| model
    primary -->|"一次情報の記録"| req
    primary -->|"一次情報の記録"| design
    violation -->|"問題台帳"| design
    model -->|"業務規則の一覧・ドメインモデル"| audit
    model -->|"ドメインモデル・業務規則の一覧"| req
    model -->|"業務規則の一覧・ドメインモデル"| design
    model -->|"業務規則の一覧"| tcd
    model -->|"業務規則の一覧"| baseline
    req -->|"完了条件の一覧"| design
    req -->|"完了条件の一覧"| screen
    model -->|"業務規則の一覧・ドメインモデル"| screen
    screen -.->|"画面の設計（受入条件の案・確認事項の候補）"| req
    screen -->|"画面の設計"| wire
    screen -->|"画面の設計"| design
    design -.->|"設計の判断（認可・エラー・デザインシステム・文面）"| screen
    design -->|"設計の判断（デザインシステム）"| wire
    screen -->|"画面の設計"| audit
    req -->|"完了条件の一覧"| tcd
    req -->|"完了条件の一覧"| e2e
    req -->|"完了条件の一覧"| plan
    design -->|"設計の判断"| tcd
    design -->|"設計の判断"| plan
    design -->|"設計の判断"| tf
    design -->|"設計の判断"| formal
    formal -->|"問題台帳"| req
    tcd -->|"テストケース表"| plan
    tcd -->|"テストケース表"| tf
    e2e -->|"テストケース表（E2E）"| tf
    plan -->|"作業の一覧"| tf
    plan -->|"作業の一覧・追跡表"| audit
    baseline -->|"回帰の基準"| fix
    baseline -->|"回帰の基準"| tf
    fix -->|"変更の事実・検証の記録"| brief
    tf -->|"変更の事実・検証の記録"| brief
    tf -->|"変更の事実"| sizing
    tf -->|"変更の事実"| dc
    design -->|"設計の判断"| dc
    model -->|"業務規則の一覧"| dc
    dc -->|"検証の記録"| audit
    tf -->|"検証の記録"| ev
    sizing -->|"規模の判定（終わる時）"| audit
    ev -->|"受入の証拠"| audit
    brief -->|"レビュー依頼文"| conduct
    conduct -->|"レビュー結果・方針外の課題の記録"| audit
    fix -->|"完了の主張・完了条件の一覧"| audit
    tf -->|"完了の主張・作業の一覧"| audit
    fix -.->|"是正の対応表・変更の事実（更新のとき）"| baseline
    tf -.->|"変更の事実（更新のとき）"| baseline
    conduct -.->|"レビュー結果（再依頼のとき）"| brief
    plan -.->|"作業の一覧（中断するとき）"| cont
    cont -.->|"引継ぎの記録・作業状態の控え（再開したとき）"| cont
    plan -.->|"作業の一覧（並べて進める）"| ws
    ws -->|"作業状態の控え"| rec
    tf -.->|"変更の事実（衝突のとき）"| conf
    design -.->|"設計の判断（根拠）"| conf
    model -.->|"業務規則の一覧・ドメインモデル（根拠）"| conf
    conf -->|"変更の事実・検証の記録"| brief
    cont -.->|"引継ぎの記録（再開時の復旧）"| rec
```
