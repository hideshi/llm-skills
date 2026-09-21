---
name: jev-monitoring-platform
description: Turns a Jev observability contract into cloud-neutral monitoring infrastructure and monitoring-app requirements, with Cloudflare as the default binding and AWS/GCP/Azure remaps—without implementing or hardcoding vendor limits.
---

# Jev Monitoring Platform（監視基盤要件）

工程名（日本語）: **監視基盤要件**（スキル ID との対応は `../jev-shared/references/jev-lifecycle-status.md` §7）。

このスキルは、`jev-observability` の**観測契約**を入力とし、運用に載せるための **監視インフラ要件**と **監視アプリ要件**を、クラウド中立のコア＋プロバイダ写像として定義します。

- **既定バインディング**: Cloudflare（Workers / Analytics Engine / D1 / Pages / Access 等を候補名として扱う）
- **読み替え**: AWS / GCP / Azure への対応表を併記する（`references/cloud-provider-remap.md`）
- **しないこと**: ダッシュボード実装、アラート実装、課金確定、ベンダー制限値の記憶断定、本番デプロイ
- **本版スコープ外（後段で契約化）**: 政策スナップショット共有面の詳細契約、再較正トリアージの業務フロー（誰がいつ承認して較正に入るか）。試験参照で「読み取り共有が必要」と触れるのみ

制限・価格・保持の数値は、**公式ドキュメント等の出典付き裏取り**またはプロジェクト入力から転記する。モデル記憶だけで本命を確定しない。

共有ステータス語彙は `../jev-shared/references/jev-lifecycle-status.md` を参照してください。

---

## スコープ境界（委譲事項）

| 対象 | 委譲先 |
| :--- | :--- |
| 観測契約（イベント／メトリクス／アラート意図／保持境界） | `jev-observability` |
| 問い・閾値・Safe Default | `jev-logic-architect` / `jev-calibration` |
| Cloudflare／他クラウド製品の制限・価格・API の出典付き裏取り | 公式ドキュメント調査（取得日・URL を残す）。本スキル内では断定しない |
| AWS / GCP / Azure の同等裏取り | 各クラウドの公式ドキュメント調査（プロジェクト入力または別スキル）。本スキルは写像候補のみ |
| 実装・オンコール・canary | SRE / MLOps / リリース管理 |
| セキュリティ・プライバシー最終判断 | セキュリティ審査・法務 |

---

## 入力契約（Input Contract）

不足は推測せず未決事項にする。

1. **Requirement ID** と業務判断の責務
2. **`jev-observability` 成果物**（判定イベント契約・時系列メトリクス・アラート意図・保持境界）。無い場合は本スキルを進めず、先に **監視設計**（`jev-observability`）へ差し戻す（観測契約の欠落）
3. **業務結果の重篤度**（共有語彙 §8）とゲート指標方針（ラボ／本番で見る・見ない指標）
4. **既定クラウド**: 省略時は Cloudflare。他クラウドを本命にする場合は明示
5. （任意）既存基盤・コンプライアンス制約・コスト上限の入力参照
6. （任意）出典付きの裏取りメモ／公式ドキュメントへのポインタ（取得日付き）

---

## 実行ワークフロー

1. **前提確認**
   - 観測契約があること。`observabilityStatus: reviewed` があれば優先。drafted のみならその旨を明記し、基盤要件も `platformStatus: drafted` に留める。

2. **クラウド中立コアの要件化**
   最低限、次の能力領域を要件として書く（製品名はまだ決め打ちしない。役割名で書く）:
   - **取り込み**: 判定経路からのイベント／メトリクス投入
   - **時系列ストア**: 集計・切り口クエリ
   - **索引／メタストア**: 閾値版・短いイベント索引（本文は原則載せない＝観測契約に従う）
   - **監視 UI**: 時系列・切り口・メタのドリルダウン・閾値版の閲覧
   - **認証・認可**: 誰が UI／API を利用できるか（認証と権限）
   - **秘密情報**: Jev／クラウド資格情報の置き場（値は書かない）
   - **後段（任意）**: キュー、ワークフロー、オブジェクト保管、ログ転送、強状態 等は「最小に含めない／後段」と明示

3. **監視アプリ要件（最小）**
   - 取り込み確認、時系列ビュー、切り口、メタ／閾値版ドリルダウン、認証・認可
   - **含めない（後段）**: アラート配信の実装、ドリフト自動再較正の実行 UI（意図は観測契約側。実装は委譲）

4. **既定バインディング（Cloudflare）**
   - コアの各役割に、CF 候補サービスを**提案として**割り当てる（例の型のみ。制限値は出典付き裏取り／プロジェクト入力から）。
   - 未確認の制限・保持・課金・認証／認可の挙動はブロッカー一覧に残し、**出典付き裏取り**（またはプロジェクト入力）が揃うまで本命確定しない。

5. **他クラウド読み替え**
   - `references/cloud-provider-remap.md` に沿い、AWS / GCP / Azure の対応候補を表で併記する。
   - 「同一」と断定せず、差分・要確認を書く。

6. **試験方針とローカル再現（要件に含める）**
   - `references/testing-and-local-dev.md` の層（Unit → 契約 → コンポーネント → 狭い統合 → 合成 E2E → 運用リハーサル → 観察）を案件向けに短く転記する。
   - Cloudflare 既定のとき、コンポーネント層用に `templates/local-dev/` の Dockerfile／compose **例**を案件リポへコピーする前提を書いてよい（AE／Access 本番相当は含めないと明記）。
   - ローカルは原則 **1コンテナ（1プロセス系統）**。付属が必要なら compose で足す。

7. **成果物出力**
   - `templates/jev-monitoring-platform-spec-template.md` に従う。
   - `platformStatus: drafted`（既定）/ `reviewed`（HITL 後）。
   - 定形結果レポートを更新する場合はプロセス表に **監視基盤要件** 行を追加してよい（共有語彙 §7）。完了版の所有者ルールは calibration／監視設計側に従う。

---

## 出力契約（Output Contract）

| 項目 | 内容 |
| :--- | :--- |
| クラウド中立コア要件 | 役割ごとの FR/NFR（製品名なし） |
| 監視アプリ要件 | 最小機能一覧と後段除外 |
| 既定バインディング（CF） | 役割→候補サービス。未確認ブロッカー付き |
| 他クラウド写像 | AWS / GCP / Azure 対応表 |
| `platformStatus` | `drafted` / `reviewed` |
| 試験方針 | 層の割り当てとローカル Docker の範囲（AE/Access 除外を明記） |
| 次フェーズ | 未確認ブロッカーの出典付き裏取り → SRE/MLOps 実装／リリース管理へ委譲 |

---

## テンプレート・参照

- 仕様テンプレ: `templates/jev-monitoring-platform-spec-template.md`
- プロバイダ写像: `references/cloud-provider-remap.md`
- 試験・ローカル: `references/testing-and-local-dev.md`
- ローカル Docker 例: `templates/local-dev/`（Dockerfile / compose。案件へコピーして使う）
- 上流: `../jev-observability/`
- 共有語彙: `../jev-shared/references/jev-lifecycle-status.md`
- 定形結果レポート: `../jev-shared/templates/jev-pipeline-result-report-template.md`
