---
name: jev-calibration
description: Calibrates decision thresholds on a frozen Jev eval set, producing batch evaluation summaries, recommended thresholds, validationStatus, and shadow-only reports without production rollout.
---

# Jev Calibration

工程名（日本語）: **較正（バッチ評価・閾値・検証ゲート）**（短称「較正」。shadow 記録工程は **shadow 評価**。対応は共有語彙 §7）。

このスキルは、`jev-eval-set` で freeze された評価セット（`datasetStatus: frozen` + `datasetVersion`）と、architect の初期閾値仮説・プロジェクトのゲート基準を入力とし、**どこで切るか（閾値較正）**を実証します。

共有ステータス語彙は `../jev-shared/references/jev-lifecycle-status.md` を参照してください。

成果物の中心は次です。

- バッチ評価要約契約
- 推奨閾値（**提案**。確定は HITL。値は入力／実験側）
- `validationStatus: VALIDATED | REJECTED | NEEDS_MORE_DATA`（未了時は `PENDING`）
- shadow レポート契約（**記録のみ・本番非適用**）
- **パイプライン定形結果レポート**（`../jev-shared/templates/jev-pipeline-result-report-template.md`）

実験の生ログ・混同行列の実数値・JSONL は実験用リポジトリ側に置き、本スキルは契約と手順のみを扱います。

---

## スコープ境界（委譲事項）

- **評価データセットの作成・再 freeze** → `jev-eval-set`
- **ラベリング方法論・一致率の品質管理** → データ整備プロセス
- **スキーマ／問い文／Safe Default の変更** → `jev-logic-architect`（変更後は `validationStatus` を `PENDING` に戻す）
- **本番 / canary / 全量展開・ロールバック** → リリース管理プロセス
- **観測契約の設計** → `jev-observability`
- **定常ドリフト監視・閾値の定期再較正の運用実行** → SRE / MLOps
- **負荷試験・レイテンシ SLO 実測の主体** → 性能試験スキル / SRE（本スキルは判定品質の較正に集中）

---

## 入力契約（Input Contract）

不足している場合は推測せず、未決事項として報告します。

1. **`datasetStatus: frozen`** と **`datasetVersion`**（必須）
2. **評価セット成果物の所在**: パスは入力（特定の実験リポ名やパスをスキルに焼かない）
3. **architect 設計ブロック**: プリミティブ、問い定義、Safe Default、**初期閾値仮説**
4. **ゲート基準（VALIDATED 条件）**: 目標指標・信頼区間・最低件数・帯域別条件など。**すべてプロジェクト入力**。業務結果の重篤度（共有語彙 §8: 失敗モード相対コスト、リスク区分、ラボ／本番で見る／見ない指標）から導出・転記する。投稿の深刻度（Score）と混同しない。
5. **Requirement ID**（行番号は用いない）
6. （任意）前回較正レポート、既知の失敗モード

---

## 実行ワークフロー

1. **前提確認**
   - `datasetStatus` が `frozen` であること。`draft` なら `jev-eval-set` へ差し戻す。
   - ラベル空間とスキーマの版が一致していること。

2. **バッチ評価**
   - frozen セット上でモデル／現行実装を評価する。
   - `references/evaluation-metrics.md` の定義に沿い、一致率・混同行列・帯域分布・フォールバック率などを集計する（合格ライン数値は入力）。

3. **Dual Threshold / 帯域別の検討（該当プリミティブ）**
   - noul: high / low 閾値と中間帯（REVIEW）のトレードオフを整理する。
   - score: 期待値ではなく `probabilities` 側の分岐仮説を、帯域別に検証する（設計原則は architect 側参照）。
   - choice: confidence／先頭確率と誤分類コストに基づく自動確定帯を検討する。

4. **パラメータ掃引（較正の子ステップ）**
   - 手順の詳細は `references/parameter-sweep-playbook.md` に従う。
   - **比較表は必須**（候補ごとに変更変数・固定条件・主要指標・失敗モード・採用可否）。
   - **1変数が既定**。相互作用が疑われるときのみペア掃引を許容する。掃引の順番はプレイブックの **推奨** であり、固定契約にしない。
   - 閾値・帯域ルールのみの変更なら、同一推論ログへの **オフライン再スコア** でよい。
   - ラベル空間／criteria／Score アンカーの **意味** が変わった場合は二重再掃引トリガ（プレイブック §5）を適用する。文言の言い換えのみは対象外。

5. **推奨閾値の提案**
   - ゲート基準を満たす候補を**推奨**として提示する。確定値のコミットは HITL。
   - 満たせない場合は `NEEDS_MORE_DATA` または `REJECTED` を選び、差し戻し先を明示する。
   - 初期仮説から**変更した場合**は、変更前→変更後・理由（観測問題）・掃引／採用ルール／オフライン再スコア要約を、詳細レポートの「閾値・分岐の改善」節と定形結果レポート §4 に必ず転記できる形で残す。

6. **validationStatus の付与**
   - `VALIDATED`: ゲート基準クリア + HITL 承認
   - `NEEDS_MORE_DATA`: データ不足 → `jev-eval-set`
   - `REJECTED`: 閾値では救えない・スキーマ再設計が必要 → `jev-logic-architect`
   - それ以外・作業中: `PENDING`

6b. **版安定ゲート（datasetVersion 変更時）**
   - `datasetVersion` が変わったら、共有語彙に従い `validationStatus` を **`PENDING`** に戻す（`UNVALIDATED` 等の新語彙は導入しない）。
   - **再測定**は本スキル（同一ポリシーでゲート再計測）、**再 freeze**は `jev-eval-set`。ゲートを満たすまで `VALIDATED` へ昇格しない。

7. **shadow レポート（記録のみ）**
   - 本番非適用の観測計画または結果要約をテンプレに記録する。
   - `shadowStatus: shadowed` は「記録した」意味であり、トラフィックへの適用・canary を含意しない。

8. **成果物出力**
   - 詳細: `templates/jev-calibration-report-template.md` に従う。
   - **定形結果レポート（必須・区切り到達時）**: 次のいずれかに達したら、`../jev-shared/templates/jev-pipeline-result-report-template.md` を**同じ見出し構造のまま**埋める。
     - `validationStatus: VALIDATED` かつ `shadowStatus: shadowed`
     - `validationStatus: REJECTED` または `NEEDS_MORE_DATA`（差し戻しで一旦区切るとき）
     - （任意）利用者が「ここまでで結果報告」と明示したとき
   - **「出力」の定義（両方必須・区切りで自動義務）**:
     1. テンプレと同見出しで定形本文を埋める
     2. 入力で指定されたパスへ**ファイル保存**する
     3. **同じ本文を利用者チャットへ全文貼る**（会話上で読める形）
   - ファイルのみ・添付のみ・口頭／チャット要約のみは**契約未達**。区切り到達時に「レポートを出しますか？」と利用者へ確認する必要はない（自動義務）。詳細較正表はチャット全文に出さず、パス参照でよい。
   - 定形レポートはユビキタス言語（担当部署・緊急度・人手レビュー要否など案件用語）と契約ステータス（`decision` / `datasetStatus` / `validationStatus` / `shadowStatus`）で書く。**プロセス表では日本語名称を必須とし、スキル ID を併記する**（対応は共有語彙 §7）。パス・数値は入力／実験成果物から転記し、スキルに焼かない。
   - **閾値・分岐を変更した場合**は定形結果レポートの **「## 4. 閾値・分岐の改善（該当時必須）」** を必ず埋める（4.1 変更前→後、4.2 理由、4.3 掃引・採用・再スコア要約）。変更が無い場合は「なし（初期仮説のまま）」と明記する。詳細レポート側の同名節から転記してよい。

---

## 出力契約（Output Contract）

| 項目 | 内容 |
| :--- | :--- |
| `validationStatus` | `PENDING` / `VALIDATED` / `REJECTED` / `NEEDS_MORE_DATA` |
| 推奨閾値 | 提案欄に記載。確定は HITL |
| 閾値・分岐の改善経緯 | 変更時は定形レポート §4（および詳細レポート同名節）に変更前→後・理由・改善内容 |
| バッチ評価要約 | 指標定義に沿った要約（数値は実験側参照） |
| `shadowStatus` | `not_started` または `shadowed`（本番非適用を明記） |
| 定形結果レポート | 区切り到達時に `jev-pipeline-result-report-template.md` 準拠。**利用者チャット全文提示＋ファイル保存の両方必須**（添付のみ・要約のみ・ファイルのみは未達） |
| 差し戻し先 | `jev-eval-set` または `jev-logic-architect`（該当時） |
| 次フェーズ | `VALIDATED` かつ shadow 記録後 → `jev-observability`（監視設計）→ リリース管理へ委譲 |

---

## テンプレート・参照

- 詳細レポート: `templates/jev-calibration-report-template.md`
- **定形結果レポート**: `../jev-shared/templates/jev-pipeline-result-report-template.md`
- 指標定義: `references/evaluation-metrics.md`
- **パラメータ掃引プレイブック**: `references/parameter-sweep-playbook.md`
- 共有語彙: `../jev-shared/references/jev-lifecycle-status.md`
