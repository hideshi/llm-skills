---
name: jev-candidate-detector
description: Scans domain models, requirements, and spec documents (Kiro/cc-sdd) to identify logic suitable for TypeSafe AI Jev (System One Model), providing feasibility scoring and cost/latency comparisons.
---

# Jev Candidate Detector

このスキルは、仕様駆動開発（Kiro, cc-sdd等）の要件定義書（`requirements.md`）やドメインモデル（`domain-model.md`）を読み込み、**TypeSafe AI の決定特化型モデル「Jev」が適用可能な業務ロジックを抽出・アタリ付け**し、コストおよびレイテンシの削減効果を試算します。

## 適用判断の判定基準（Jev 適合性シグネチャ）

### ✅ Jev に最適な処理（適合度: 高）
1. **入力**: ユーザーの自然言語、曖昧なフリーテキスト、非構造化コメント、クエリ
2. **出力**: 有限の選択肢（Enum）、真偽値（Boolean）、重み付け・確信度スコア（0.0〜1.0）
3. **目的**: 分類、トリアージ、ルーティング、セーフティチェック、関連度フィルタ
4. **非機能要件**: 低遅延（< 150ms）または 大量トラフィック（高スループット・低コスト化）が求められる箇所

### ❌ Jev に不向きな処理（通常のコード / 生成LLMを維持すべき箇所）
- 完全な決定論的ロジック（数値計算、明確な日付比較、権限ロールチェックなど） → **通常の if / switch 文で十分**
- 文章やコードの新規生成、要約文の作成、自由対話 → **生成型LLM（GPT-4o, Claude, Gemini等）の領域**
- 複雑な多段階推論（Chain of Thought）が必要な高度な数学・論理パズル → **推論型LLM（o1, o3, DeepSeek-R1等）の領域**

---

## 実行ワークフロー

1. **ドキュメントの静的スキャン**
   - 指定された要件定義書・ドメインモデル（または `docs/` 配下）を精読し、自然言語入力に対する「判断」「条件分岐」「バリデーション」「フィルタリング」の記述を抽出する。

2. **Jev 適合性のスコアリング**
   - 上記のシグネチャに照らし合わせ、★1〜★5で適合度を評価する。
   - 既存の代替案（正規表現ルール、または従来の生成LLMによるJSON出力）との差異を整理する。

3. **💰 コスト & レイテンシ試算**
   - `references/cost-estimation-reference.md` の単価を元に、月間リクエスト規模別（1万 / 10万 / 100万コール）のコスト比較表を算出する。
   - Jev の「出力トークン課金 $0」による削減インパクトを明記する。

4. **レポート出力**
   - `templates/jev-candidate-report-template.md` の形式に従い、検出結果と試算レポートを出力する。
   - ユーザーが採用したい候補を絞り込んだ後、後続の `jev-logic-architect` へ引き渡す。
