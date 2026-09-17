# TypeSafe AI Jev 3大プリミティブ & 確信度・閾値設計リファレンス

## 1. 3つの意思決定プリミティブと応答モデル

TypeSafe AI（Jev）は単一の汎用型ではなく、3つの明確なプリミティブを提供します。**各プリミティブによって確信度の意味や返却構造が異なります。**

### ① `Choice`（多肢選択・排他分類）
- **用途**: カテゴリ分類、ルーティング、担当部署決定。
- **応答形式**: 選択された選択肢、各選択肢の確率分布、および `confidence`。
- **Confidenceの意味**: 選択肢間の「分布の集中度」（最有力候補がどれだけ突出しているか）。
- **判定ロジック例**:
  ```typescript
  const { decision, probabilities, confidence } = result.department;
  // confidence が高い場合のみ自動ルーティング
  if (confidence >= threshold) {
    routeTo(decision);
  } else {
    // 競合している選択肢を提示して確認
    askUserConfirmation(probabilities);
  }
  ```

### ② `Score`（順序尺度・レベル評価）
- **用途**: 緊急度（Low/Med/High）、深刻度レベル（1〜5）、品質評価。
- **応答形式**: 決定されたスコア、スコアごとの確率分布、および `confidence`。
- **Confidenceの意味**: レベル分布の集中度。

### ③ `Noul`（Yes/No の命題確率判定）
- **用途**: スパム判定、ポリシー違反チェック、エスカレーション要否。
- **応答形式**: **`yes` である確率（0.0 〜 1.0）**。※ 独立した confidence は存在しない（0.5 が最も不確実）。
- **閾値設計の重要性**:
  単一の `confidence >= 0.95` で判断してはならない。**「誤検知（False Positive）コスト」** と **「見逃し（False Negative）コスト」** を考慮したデュアル閾値（Dual Threshold）で判定する。
  ```typescript
  const pViolation = result.isViolation.probability; // 0.0〜1.0

  if (pViolation >= BLOCK_THRESHOLD) {
    // 確信を持って違反と判定 (即ブロック)
    return { status: 'BLOCK' };
  } else if (pViolation <= ALLOW_THRESHOLD) {
    // 確信を持って安全と判定 (即通過)
    return { status: 'ALLOW' };
  } else {
    // 中間帯: 不確実（0.5付近）のため人間または生成LLMへエスカレーション
    return { status: 'REVIEW_REQUIRED' };
  }
  ```

---

## 2. 実証的な閾値（Threshold）選定プロセス

固定の経験則（0.95, 0.80等）は**初期仮説に過ぎず、プロダクションでそのまま使用してはならない**。以下の手順で決定する。

1. **評価データセットの準備**: ドメインのラベル付きデータ（最低 100〜500 件）を用意。
2. **コスト行列（Cost Matrix）の定義**:
   - 誤検知（FP）の損害 vs 見逃し（FN）の損害を数値化。
3. **ROC曲線 / Precision-Recall 曲線の分析**:
   - 閾値を変化させたときの「自動化率（Coverage）」と「エラー率」のトレードオフを算出。
4. **本番ドリフト監視**:
   - 運用中の平均確信度や中間帯（Review率）の推移をモニタリングし、モデルやプロンプト変更時に再評価を実施する。

---

## 3. 障害耐性・堅牢性設計（Production Resilience）

外部AI API障害時にもシステムを停止させないための必須パターン：

- **タイムアウト設定**: 通常 150ms 応答のため、`timeout: 500ms` 等で打ち切る。
- **限定リトライ**: 429（Rate Limit）や 503 のみ、Exponential Backoff で最大 2 回リトライ。
- **Circuit Breaker**: 障害検知時は Jev 呼出をバイパスし、即時 Fallback へ切り替える。
- **Safe Default（安全側の既定値）**:
  - セキュリティ判定の障害時 → デフォルト「要確認（Review）」として通さない。
  - レコメンド/非重要UIの障害時 → デフォルト「通常表示」としてユーザー体験を止めない。
- **PII / プライバシー配慮**: State に個人情報（メールアドレス、クレジットカード番号等）を含めない、またはマスキングして送信する。
