---
name: jev-observability
description: Designs a Jev-specific observability contract (decision events, time-series metrics, alert intents, retention/privacy boundaries) for production handoff without implementing dashboards or on-call.
---

# Jev Observability（監視設計）

工程名（日本語）: **監視設計**（スキル ID との対応は `../jev-shared/references/jev-lifecycle-status.md` §7）。

このスキルは、承認済みの論理設計（`jev-logic-architect`）と、可能な場合は較正結果（`jev-calibration` の `validationStatus` / 推奨閾値 / 経路内訳）を入力とし、**Jev 判定の観測契約**を設計します。成果物は SRE / MLOps / セキュリティ審査へ委譲できる仕様です。

共有ステータス語彙は `../jev-shared/references/jev-lifecycle-status.md` を参照してください。

成果物の中心は次です。

- **判定イベント契約**（1 判定あたり何を残すか）
- **時系列メトリクス契約**（成功率・レイテンシ・REVIEW 率等）
- **アラート意図**（何が異常か。閾値数値は入力）
- **保持・プライバシー境界**（生本文をどこまで残すか）
- `observabilityStatus: drafted | reviewed`（任意。reviewed は HITL）

ダッシュボード実装、オンコール、ベンダー選定、アラート対応の実行は行いません。

---

## スコープ境界（委譲事項）

本スキルがカバーするのは **観測契約の設計と報告欄の定義**までです。

- **スキーマ／問い／Safe Default／初期閾値仮説** → `jev-logic-architect`
- **評価セット・較正・shadow 記録** → `jev-eval-set` / `jev-calibration`
- **ダッシュボード・ログ基盤・アラートルールの実装と運用** → SRE / MLOps
- **セキュリティ・プライバシー審査（外部送信・保持期間の最終判断）** → セキュリティレビュー・法務
- **本番 canary / 全量 / ロールバック** → リリース管理プロセス
- **ドリフト検知後の閾値再較正の実行** → `jev-calibration`（設計変更が必要なら architect）＋ SRE 運用
- **評価セット版の更新** → `datasetVersion` 変更時は較正の版安定ゲート（`validationStatus: PENDING` へ戻し、同一ポリシー再測定まで昇格禁止）を参照（`jev-calibration` / 共有語彙）

---

## 入力契約（Input Contract）

不足している場合は推測せず、未決事項として報告します。

1. **Requirement ID** と業務判断の責務（行番号は用いない）
2. **architect 設計ブロック**: プリミティブ、問い定義、Safe Default、初期閾値仮説、経路（自動 / REVIEW / フォールバック）
3. **calibration 成果**: `validationStatus`、推奨閾値、経路内訳・レイテンシの要約参照（パスは入力）。**本番適用前は実質必須**。ラボ用途のみで較正前に草案する場合は省略可だが、その旨をレポートに明記する
4. **SLO / アラート方針の入力**: 目標 p95、REVIEW 率上限、Safe Default 率上限など（数値はプロジェクト入力。スキルに焼かない）
5. **データ保持・プライバシー制約の入力**: チケット本文等を残してよいか、マスキング方針、保持日数の候補（最終承認は審査へ）
6. （任意）既存のログ基盤・メトリクス基盤の所在（パス／ドキュメント参照は入力）

---

## 実行ワークフロー

1. **前提確認**
   - `decision: approved` の設計があること。なければ architect / detector へ差し戻す。
   - 本番適用前なら `validationStatus: VALIDATED` を推奨。ラボのみならその旨をレポートに明記し、ゲートを緩くしない（別枠のラボ観測として書く）。

2. **判定イベント契約の定義**
   - `references/decision-event-contract.md` に沿い、1 判定 1 イベントの必須／任意フィールドを決める。
   - 生本文・PII はデフォルトでイベントに入れず、入れる場合は審査要否を記録する。

3. **時系列メトリクス契約の定義**
   - 最低限: 成功率（または完了率）、レイテンシ p50/p95、REVIEW 率、フォールバック率、Safe Default 率。
   - 切り口例（案件に応じて入力から選ぶ）: Requirement ID、担当部署、緊急度、人手レビュー要否、経路、`validationStatus`。
   - 合格ライン・アラート閾値の**数値は入力**。スキルは「どの指標を定義するか」だけを固定する。

4. **アラート意図の列挙**
   - 例の型のみ（数値は空欄＋入力参照）: REVIEW 急増、Safe Default 急増、p95 悪化、VALIDATED なのに PENDING 経路多発、API エラー率。
   - 通知先・オンコールは委譲先欄に書くだけ。

5. **保持・プライバシー境界**
   - 何を何日残すか、誰が読めるか、マスキングの要否を表にする。確定はセキュリティ審査へ委譲。

6. **成果物出力**
   - `templates/jev-observability-spec-template.md` に従う。
   - 定形結果レポートを更新する場合は、プロセス表に **監視設計** 行を追加してよい（共有語彙 §7）。完了版レポートの所有者は引き続き主に calibration 区切りだが、運用突入前の追加区切りとして本スキル完了時に部分更新してよい。**完了版の二重発行を避ける**: 監視設計完了をもって完了版とする場合は、calibration 側の区切り条件（例: `validationStatus: VALIDATED` かつ `shadowStatus: shadowed`）を満たしていることを確認し、既に出している完了版があるときは同一成果物を更新するか版を明示する。

---

## 出力契約（Output Contract）

| 項目 | 内容 |
| :--- | :--- |
| 判定イベント契約 | 必須／任意フィールド、禁止フィールド |
| 時系列メトリクス契約 | 指標名・定義・次元・成果物参照（数値閾値は入力） |
| アラート意図一覧 | 条件の型・委譲先。実装はしない |
| 保持・プライバシー境界 | 審査要否付き |
| `observabilityStatus` | `drafted`（既定）/ `reviewed`（HITL 後） |
| 次フェーズ | SRE/MLOps 実装、セキュリティ審査、リリース管理 |

---

## テンプレート・参照

- 仕様テンプレ: `templates/jev-observability-spec-template.md`
- イベント契約ガイド: `references/decision-event-contract.md`
- 共有語彙: `../jev-shared/references/jev-lifecycle-status.md`
- 定形結果レポート: `../jev-shared/templates/jev-pipeline-result-report-template.md`
