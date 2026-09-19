# Jev パイプライン結果レポート（定形）

> **用途**: detector → architect → eval-set → calibration（→ shadow）の一連工程が**区切り**に達したときに、毎回同じ見出しで出す利用者向け要約。
> **数値・パス**: すべて入力／実験成果物から転記する。本テンプレにハードコードしない。
> **本番適用**: 本レポートは shadow までを扱う。canary／全量はリリース管理へ委譲し、ここに「適用済み」と書かない。

共有語彙: `../references/jev-lifecycle-status.md`

---

## 1. 対象（ユビキタス言語）

| 項目 | 記入 |
| :--- | :--- |
| Requirement ID | `[例: REQ-ROUTE-03]`（行番号は用いない） |
| 業務判断の責務 | `[例: 問い合わせの担当部署への振分]` |
| 採用プリミティブ | `choice` / `score` / `noul` |
| ドメイン語彙（例） | 担当部署 / 緊急度 / 人手レビュー要否 など、当該案件の用語 |
| リスク区分 | 高 / 中 / 低（入力・設計に従う） |
| Safe Default（要約） | |

---

## 2. プロセス（どのスキルをどの契約で使ったか）

- **日本語名称は必須**（利用者向け）。スキル ID は併記必須（実装・トレーサビリティ用）。対応は共有語彙 §7 の表に従い、勝手に別名を増やさない。
- 未実施の工程行は削除せず、契約ステータス欄に `未到達` と書く（部分記入時も同じ）。

| 順 | 日本語名称（工程） | スキル ID | 契約ステータス（到達値） | 実施日 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | 候補検出 | `jev-candidate-detector` | `decision:` `proposed` → `approved`（または `rejected`） | | |
| 2 | 論理設計 | `jev-logic-architect` | 設計完了 / 初期閾値仮説あり / `validationStatus: PENDING` | | |
| 3 | 評価セット整備 | `jev-eval-set` | `datasetStatus:` `draft` → `frozen` / `datasetVersion:` | | |
| 4 | 較正（バッチ評価・閾値・検証ゲート） | `jev-calibration` | `validationStatus:` `PENDING` → `VALIDATED` \| `REJECTED` \| `NEEDS_MORE_DATA` | | |
| 5 | shadow 評価 | `jev-calibration`（shadow） | `shadowStatus:` `not_started` → `shadowed`（**記録のみ・本番非適用**） | | |

差し戻しがあった場合:

| 発生ステータス | 差し戻し先（日本語名称 / スキル ID） | 理由要約 | 再開後の版 |
| :--- | :--- | :--- | :--- |
| `NEEDS_MORE_DATA` | 評価セット整備 / `jev-eval-set` | | |
| `REJECTED` | 論理設計 / `jev-logic-architect` | | |

---

## 3. 結果（要約）

> 詳細表・混同行列の生データは実験成果物を参照し、ここは要約とポインタのみ。

| 観点 | 要約 | 成果物参照（入力パス） |
| :--- | :--- | :--- |
| 一致率 / 精度系 | | |
| 経路内訳（自動確定 / REVIEW・人手レビュー / フォールバック / Safe Default） | | |
| レイテンシ（p50 / p95 等。未測なら `TBD`） | | |
| 推奨閾値（提案。確定は HITL） | | |
| `validationStatus` | | |
| `shadowStatus` | `shadowed` の場合は **本番非適用** を明記 | |
| ゲート基準との対比 | 達 / 未達 / 一部（基準自体は入力参照） | |

### 3.1 ユビキタス言語での一文要約（必須）

例の型に合わせて、案件用語で 2〜4 文:

- 何を判定したか（例: 担当部署・緊急度・人手レビュー要否）
- どの工程まで進んだか（日本語工程名＋ decision / datasetStatus / validationStatus / shadow）
- 主な定量結果（一致率・経路内訳・レイテンシの要点）
- 次アクション（リリース管理へ委譲 / eval-set 差し戻し / architect 差し戻し）

（ここに記入）:

---

## 4. 主な成果物パス（すべて入力由来）

| 種別 | パスまたは参照 | 備考 |
| :--- | :--- | :--- |
| 候補レポート | | 候補検出 |
| 設計ブロック / ADR | | 論理設計 |
| 評価セット（frozen） | | 評価セット整備 / 実験リポ |
| バッチ評価・較正レポート | | 較正 |
| shadow 記録 | | shadow 評価 |
| 本定形結果レポートの保存先 | | 入力で指定された場所 |

---

## 5. 次アクション

| 条件 | 次 |
| :--- | :--- |
| `validationStatus: VALIDATED` かつ `shadowStatus: shadowed` | **リリース管理プロセス**へ委譲（canary / 全量 / ロールバックは本鎖の外） |
| `NEEDS_MORE_DATA` | **評価セット整備**（`jev-eval-set`）でデータ追加・再 freeze 後、較正を再開 |
| `REJECTED` | **論理設計**（`jev-logic-architect`）でスキーマ／問い／Safe Default 再設計 |
| `decision: rejected` | パイプライン終了。理由を §3.1 に残す |

---

## 6. メタ

- **レポート作成日**: [YYYY-MM-DD]
- **作成者 / エージェント**:
- **使用したスキル版・リポ参照**: [入力。例: llm-skills のコミットまたはタグ。推測しない]
