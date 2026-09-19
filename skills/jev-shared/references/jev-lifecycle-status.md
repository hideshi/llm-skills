# Jev ライフサイクル共有ステータス語彙

本ドキュメントは `jev-candidate-detector` / `jev-logic-architect` / `jev-eval-set` / `jev-calibration` / `jev-observability` が共通して用いる**状態語彙**と遷移の契約である。プロジェクト固有のゲート基準・閾値・データパスはここに書かず、各スキルの**入力契約**で受け取る。

---

## 0. 表記規約

- `decision` / `datasetStatus` / `shadowStatus` / `observabilityStatus` の**値**は小文字（例: `proposed`, `frozen`, `shadowed`, `drafted`）。
- `validationStatus` の**値**のみ大文字（例: `PENDING`, `VALIDATED`）。歴史的互換のため。
- フィールド名自体は camelCase。


## 1. ステータス語彙

### 1.1 `decision`（候補の採用判断・HITL）

| 値 | 意味 |
| :--- | :--- |
| `proposed` | 検出・設計提案済み。人間の承認待ち。 |
| `approved` | 技術・業務側の承認済み。後段スキルへ進める。 |
| `rejected` | （任意）採用見送り。理由を記録する。 |

### 1.2 `datasetStatus`（評価セットの凍結状態）

| 値 | 意味 |
| :--- | :--- |
| `draft` | 構築中。ラベル・分割・版が未確定。 |
| `frozen` | freeze 承認済み。較正（`jev-calibration`）の入力として使える。 |
| `superseded` | （任意）後継版に置き換え済み。旧版は再較正・監査参照のみ。 |

### 1.3 `validationStatus`（閾値・ポリシーの実証状態）

| 値 | 意味 |
| :--- | :--- |
| `PENDING` | 未検証、または再較正待ち。自動化ポリシーへの昇格禁止。 |
| `VALIDATED` | プロジェクト入力のゲート基準を満たし、HITL が検証完了を承認。 |
| `REJECTED` | 閾値調整では救えない／スキーマ再設計が必要。`jev-logic-architect` へ差し戻し。 |
| `NEEDS_MORE_DATA` | データ不足・分布偏り・信頼区間が広すぎる等。`jev-eval-set` へ差し戻し。 |

> **互換メモ**: 過去文書の `UNVALIDATED` は本語彙の `PENDING` と同義。現行テンプレは `PENDING` を用いる。

### 1.4 `shadowStatus`（本番非適用の観測記録）

| 値 | 意味 |
| :--- | :--- |
| `not_started` | shadow 観測未実施。 |
| `shadowed` | shadow レポートを記録済み。**本番トラフィックへの判定適用・canary・全量展開は含まない**（記録のみ）。 |

`shadowed` は「本番に出した」ことを意味しない。本番適用はリリース管理プロセスへ委譲する。


### 1.5 `observabilityStatus`（観測契約の整備状態）

| 値 | 意味 |
| :--- | :--- |
| `drafted` | 監視設計（`jev-observability`）の仕様草案。HITL 未了でも可。 |
| `reviewed` | 観測契約を人間がレビュー済み。実装委譲の前提としてよい。 |

`observabilityStatus` の**値**は小文字（§0 の例外は `validationStatus` のみ）。


---

## 2. 状態機械（前進）

```text
decision: proposed
  → decision: approved
    → (jev-logic-architect: スキーマ・初期閾値・Safe Default)
      → datasetStatus: frozen   … jev-eval-set
        → validationStatus: VALIDATED   … jev-calibration
          → shadowStatus: shadowed   … 記録のみ（本番非適用）
            → observabilityStatus: drafted → reviewed   … 監視設計（jev-observability）
              → （リリース管理へ委譲: canary / 全量 / ロールバック）
```

前進の前提（各矢印で必須）:

| 遷移 | 必須前提 |
| :--- | :--- |
| `proposed → approved` | HITL（技術＋必要なら業務側） |
| architect 完了 → eval-set | `decision: approved` と設計ブロック（プリミティブ・選択肢・Safe Default・初期閾値仮説） |
| `draft → frozen` | ラベル承認者・freeze 承認者・`datasetVersion`・リーク防止確認 |
| `PENDING → VALIDATED` | `datasetStatus: frozen` + プロジェクト入力のゲート基準クリア + HITL |
| `VALIDATED → shadowed` | shadow レポート契約の記録（本番適用はしない） |
| shadowed → 監視設計完了 | `jev-observability` の観測契約（`observabilityStatus: drafted` 以上。本番前は `reviewed` 推奨） |

---

## 3. 差し戻し矢印

```text
validationStatus: NEEDS_MORE_DATA  →  jev-eval-set（データ追加・再サンプリング・再 freeze）
validationStatus: REJECTED         →  jev-logic-architect（スキーマ／問い／Safe Default 再設計）
質問文・スキーマ変更後             →  validationStatus を PENDING に戻し、必要なら dataset 再 freeze
datasetVersion 変更後              →  validationStatus を PENDING に戻す（再測定=較正、再 freeze=評価セット整備）。ゲート再達まで昇格禁止
監視設計で設計不備を検出           →  jev-logic-architect（例: Safe Default が観測不能、経路語彙が欠落）
```

差し戻し時は必ず次を記録する。

- 差し戻し理由（ゲート未達項目、スキーマ欠陥の仮説、データギャップ）
- 関連 Requirement ID
- 再開時に必要な入力（追加ラベル方針、再設計すべき問い、等）

---

## 4. Requirement ID トレーサビリティ方針

- 候補・設計・評価セット・較正レポートは、**Requirement ID**（なければドキュメント内の安定した見出し）で紐付ける。
- **行番号（`#L45` 等）は用いない**。追記・整形でずれやすいため、補助情報としても禁止する。
- 原文フレーズの引用は短く、ID と見出しで再特定可能にする。

---

## 5. 「スキルに焼かない」原則

次の値はスキル本文・テンプレの固定値にせず、**入力契約または実験リポジトリの成果物**として受け取る。

- ゲート基準（目標 FP/FN、信頼区間、最低サンプル数、帯域別カバレッジ等）
- 閾値の数値（`blockThreshold` / `allowThreshold` 等）
- 生データ・評価セット・実験ログのパス（例: 実験用 sibling リポ上のパス）
- プロジェクト固有の SLO・コスト単価・人件費

スキル側が定義するのは**手順・契約項目・報告欄・委譲先**のみとする。

---

## 6. 定形結果レポート

一連工程の**区切り**では、`../templates/jev-pipeline-result-report-template.md` に従い定形結果レポートを出す。区切りの例:

- `validationStatus: VALIDATED` かつ `shadowStatus: shadowed`
- `REJECTED` / `NEEDS_MORE_DATA` での差し戻し区切り
- **利用者が「ここまでで結果報告」と明示したとき**（任意トリガ。`jev-calibration` の契約と揃える）

ルール:

- 見出し構造を変えず、毎回同じ節立てで書く。
- 対象・プロセス・結果・成果物パス・次アクションをユビキタス言語と本語彙で埋める。**プロセス表の日本語名称は必須**（スキル ID 併記）。
- 詳細な較正表は `jev-calibration` の詳細レポート側。定形レポートは利用者向け要約である。
- **利用者向け要約は会話上で読める形で出す**: 区切り到達時は、埋めた定形本文を**利用者チャットへ全文貼る**ことと、指定パスへの**ファイル保存**の両方が必須。ファイルのみ・添付のみ・要約のみは未達。詳細表はパス参照でよい。
- 「レポートを出しますか？」と利用者へ確認する必要はない（区切りで自動義務）。
- **完了版の出力義務は `jev-calibration`**。他スキルはプロセス表の自段を埋める・部分記入してよいが、完了版の所有者は calibration。

---

## 7. 工程の日本語名称（スキル ID 対応）

定形結果レポートおよび各スキルの工程呼びは、次の対応を**一意**に用いる。別名を増やさない。

| 日本語名称（工程） | スキル ID | 備考 |
| :--- | :--- | :--- |
| 候補検出 | `jev-candidate-detector` | |
| 論理設計 | `jev-logic-architect` | |
| 評価セット整備 | `jev-eval-set` | |
| 較正（バッチ評価・閾値・検証ゲート） | `jev-calibration` | 短く「較正」と書いてもよい（同一工程） |
| （較正の子）パラメータ掃引 | `jev-calibration` | 較正の子ステップ。比較表必須。順番は推奨であり固定契約ではない |
| shadow 評価 | `jev-calibration`（shadow） | calibration 内の shadow 記録工程。本番適用を含まない |
| 監視設計 | `jev-observability` | 観測契約（イベント・メトリクス・アラート意図・保持境界）。実装は SRE/MLOps |

差し戻し先を書くときも、日本語名称とスキル ID を併記する（例: 評価セット整備 / `jev-eval-set`）。

---

## 8. 業務結果の重篤度（コスト非対称）

**投稿の深刻度**（Score の low/medium/high など、1件の中身の強さ）と混同しない。

| 用語 | 意味 |
| :--- | :--- |
| 投稿の深刻度 | 1件の判定対象そのものの強さ（Score 等）。プリミティブの出力。 |
| **業務結果の重篤度** | 誤判定が業務・利用者・法務にどれだけ効くか（コスト非対称）。要件／入口の入力。 |

Jev パイプライン開始時（要件文書または候補検出）の**必須入力**として、少なくとも次を案件ごとに書く（全案件共通の「見逃し優先」等をスキルに焼かない）:

1. **失敗モードごとの相対コスト**（例: FN vs FP、不可逆操作の有無）
2. **リスク区分**（高 / 中 / 低）と**理由一文**
3. **ラボ／本番ゲートで見る指標と見ない指標**（案件ごと。例: 自動化率はラボゲート外、など）

### 下流への転記先
- `jev-candidate-detector` 候補レポート（候補詳細）
- `jev-logic-architect` の ADR／設計ブロック（リスク区分＆コスト非対称）
- `jev-calibration` のゲート基準入力および較正レポートのコスト行列・§4.2（定形の「ゲート／方針との関係」）
- 定形結果レポート §1（リスク区分・重篤度要約）

