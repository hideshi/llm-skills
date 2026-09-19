---
name: jev-eval-set
description: Builds and freezes a labeled evaluation dataset contract for an approved Jev logic design, producing datasetVersion and freeze records for downstream calibration.
---

# Jev Eval Set

このスキルは、前段の `jev-logic-architect` が出力した設計ブロック（プリミティブ・選択肢・Safe Default・初期閾値仮説）と、プロジェクトから渡された生データ源・承認者情報を入力とし、**較正（`jev-calibration`）に使える評価データセットの契約記述と freeze 記録**を整備します。

共有ステータス語彙は `../jev-shared/references/jev-lifecycle-status.md` を参照してください。

成果物の中心は次です。

- frozen dataset の**契約記述**（何を正解とするか、分割、版、リーク防止）
- `datasetVersion`
- freeze 記録
- ステータス `datasetStatus: frozen`

JSONL 実データや実験数値そのものは本スキル／`llm-skills` には置かず、実験用リポジトリ側に残します。ここは**汎用手順と契約**のみです。

---

## スコープ境界（委譲事項）

本スキルがカバーするのは **評価セットの起票・スキーマ整合・サンプリング方針の文書化・ラベル定義の固定・freeze 手続き**までです。以下は対象外です。

- **ラベリング方法論そのもの**（複数人アノテーション、一致率の品質管理、ガイドラインの運用改善）→ **データ整備プロセス**
- **閾値の決定・ゲート合否** → `jev-calibration`
- **スキーマ／問い文／Safe Default の再設計** → `jev-logic-architect`
- **本番・canary・全量展開** → リリース管理プロセス
- **定常ドリフト監視** → SRE / MLOps

---

## 入力契約（Input Contract）

不足している場合は推測せず、未決事項として報告します。

1. **承認済み候補**: `decision: approved`（Requirement ID。行番号は用いない）
2. **architect 設計ブロック**:
   - 採用プリミティブ（choice / score / noul）
   - instructions / criteria（または同等の問い定義）
   - Safe Default
   - 初期閾値仮説（値は入力。スキルに焼かない）
3. **生データ源の所在**: パス・クエリ・抽出手順は**入力で受け取る**（スキル本文にハードコードしない）
4. **ラベル定義（何を正解とするか）**: 選択肢キーと業務上の正解の対応、境界ケースの扱い
5. **ラベル承認者 / freeze 承認者**（役割または氏名）
6. **Requirement ID** とトレーサビリティ方針への同意
7. （任意）既存の draft セットや除外リストの所在
8. （任意・差し戻し再開時）前回の `validationStatus: NEEDS_MORE_DATA`（または同等）理由、追加ラベル方針、前回 `datasetVersion` / freeze 記録の所在

---

## 実行ワークフロー

1. **スキーマ整合チェック**
   - ラベル空間が architect の criteria / レベル定義と 1 対 1 で対応することを確認する。
   - 脱出選択肢（`none` / `other` 等）の業務上の正解扱いを明記する。
   - 不整合があれば本スキルで勝手にスキーマを変えず、`jev-logic-architect` への差し戻し候補として記録する。

2. **サンプリング & 分割方針の文書化**
   - `references/sampling-and-leakage-guide.md` に従い、層化・境界ケース・時間分割などの方針を**入力と合意に基づき**記録する。
   - 最低件数・層の目標比率などの数値は入力契約から受け取り、スキルに焼かない。

3. **リーク防止の確認**
   - train/dev/test（または eval 専用ホールドアウト）間の重複、同一スレッド・同一顧客の漏洩、プロンプト／ラベルの混入をチェック項目として報告する。
   - 実データの中身はレポートに貼らず、実験リポ上のパスとチェック結果のみ記す。

4. **ラベル分布・帯域統計の報告項目を埋める**
   - クラス分布、欠損、境界ケース比率など、テンプレの報告欄を埋める（具体値は実験成果物から転記）。

5. **freeze**
   - `datasetVersion` を付与する（命名規約は一般化し、具体値は実験リポ側。例: 内容ハッシュ接頭辞、または日付タグ＋連番）。
   - ラベル承認者・freeze 承認者・日時・対象パス（入力で受け取った所在）を freeze 記録に残す。
   - `datasetStatus: frozen` とする。

6. **次フェーズ契約の出力**
   - `templates/jev-eval-set-report-template.md` に従いレポートを出力する。
   - 次は `jev-calibration`（入力に `datasetStatus: frozen` と `datasetVersion` が必須）。

---

## 出力契約（Output Contract）

| 項目 | 内容 |
| :--- | :--- |
| `datasetStatus` | `frozen`（成功時） |
| `datasetVersion` | ハッシュまたは日付タグ等。具体値は実験リポ |
| ラベル分布・帯域統計 | 報告項目をテンプレどおり記載（数値は実験側） |
| freeze 記録 | 承認者・日時・対象・除外理由 |
| 次フェーズ | `jev-calibration` |
| 差し戻し | スキーマ不整合時は `jev-logic-architect` |

---

## テンプレート・参照

- レポート: `templates/jev-eval-set-report-template.md`
- サンプリング・リーク防止: `references/sampling-and-leakage-guide.md`
- 共有語彙: `../jev-shared/references/jev-lifecycle-status.md`
