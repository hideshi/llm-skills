# TypeSafe AI Jev 3大プリミティブ & 確信度・閾値設計リファレンス

## 1. 3つの意思決定プリミティブと公式SDK仕様 (JS/TS & Python)

TypeSafe AI（Jev）は単一の汎用型ではなく、3つの明確なプリミティブを提供します。**各プリミティブによって確信度の意味や返却構造が異なります。**

公式SDKでは、大文字の `new Choice()` ではなく、小文字の builder 関数（`choice()`, `score()`, `noul()`）を使用します。

### ① `choice`（多肢選択・排他分類）
- **用途**: カテゴリ分類、ルーティング、担当部署決定。
- **TypeScript 定義**:
  ```typescript
  import { choice } from '@typesafe-ai/sdk';

  const questions = {
    department: choice('Which team should handle this inquiry?', {
      billing: 'Payment, invoices, and subscription questions',
      technical: 'API errors, bugs, and integration problems',
      sales: 'Enterprise plans, demo requests, and pricing',
    }),
  };
  ```
- **応答形式**: `response.answers.department`
  - `choice: string` (選ばれたキー)
  - `probabilities: Record<string, number>` (各選択肢の確率分布)
  - `confidence: number` (選択肢間の「分布の集中度」)

### ② `score`（順序尺度・レベル評価）
- **用途**: 緊急度（Low/Med/High）、深刻度レベル（1〜5）、品質評価。
- **TypeScript 定義**:
  ```typescript
  import { score } from '@typesafe-ai/sdk';

  const questions = {
    urgency: score('Rate the urgency of this request', {
      low: 'General question, no immediate deadline',
      medium: 'Needs response within 24 hours',
      critical: 'Production outage or data breach',
    }),
  };
  ```
- **応答形式**: `response.answers.urgency`
  - `score: string` (選ばれたレベル)
  - `probabilities: Record<string, number>`
  - `confidence: number` (分布の集中度)

### ③ `noul`（Yes/No の命題確率判定）
- **用途**: スパム判定、ポリシー違反チェック、エスカレーション要否。
- **TypeScript 定義**:
  ```typescript
  import { noul } from '@typesafe-ai/sdk';

  const questions = {
    isViolation: noul('Does this input violate our safety guidelines?'),
  };
  ```
- **応答形式**: `response.answers.isViolation`
  - **`noul: number` (Yes である確率: 0.0 〜 1.0)**。※ 独立した confidence フィールドは存在しない。
- **デュアル閾値（Dual Threshold）のハンドリング**:
  誤検知（FP）コストと見逃し（FN）コストに基づき、明確に3分岐を実装する。
  ```typescript
  const pViolation = response.answers.isViolation.noul; // 0.0 〜 1.0

  if (pViolation >= BLOCK_THRESHOLD) {
    // 確信を持ってブロック (例: p >= 0.95)
    return { status: 'BLOCK', reason: 'CONFIRMED_VIOLATION' };
  } else if (pViolation <= ALLOW_THRESHOLD) {
    // 確信を持って通過 (例: p <= 0.05)
    return { status: 'ALLOW', reason: 'CONFIRMED_SAFE' };
  } else {
    // 中間帯: 不確実（0.05 < p < 0.95）→ レビューまたは生成型LLMへエスカレーション
    return { status: 'REVIEW_REQUIRED', reason: 'UNCERTAIN_PROBABILITY' };
  }
  ```

---

## 2. 実証的な閾値（Threshold）選定プロセス

固定の経験則（0.95, 0.80等）は**初期仮説に過ぎず、プロダクションでそのまま使用してはならない**。

1. **評価データセットの準備**:
   - 固定の100件ではなく、**「クラス別発生率（Prevalence）」「求めるPrecision/Recallの信頼区間」「重要な境界ケースのカバレッジ」** を満たすサンプル数を設計する。
2. **コスト行列（Cost Matrix）の定義**:
   - 誤検知（False Positive）の損害 vs 見逃し（False Negative）の損害を数値化。
3. **ROC曲線 / Precision-Recall 曲線の分析**:
   - 閾値を変化させたときの「自動化率（Coverage）」と「エラー率」のトレードオフを算出し、閾値を決定。
4. **本番ドリフト監視とロールバック**:
   - 運用中の平均確信度やレビュー率（中間帯の比率）を監視。質問文変更時やモデル更新時は必ず再評価を実施する。

---

## 3. タイムアウト・リトライ・締め切り制約（Deadline Hierarchy）

「p95 < 200ms」などの低遅延要件を満たすため、時間予算（Time Budget）を明確に階層化して設計します。

```text
[ユーザー要求全体のDeadline: 例 800ms]
  │
  ├── [Jev呼出全体のDeadline: 例 250ms]
  │     ├── 1試行のタイムアウト: 150ms
  │     ├── リトライ間隔 (Backoff): 30ms
  │     └── 最大試行回数: 2回 (初回 + リトライ1回)
  │
  └── [超過時のフォールバック処理 (Safe Default または LLM): 残り時間予算内]
```

- **Safe Default（安全側の既定値）**:
  - Jev の Deadline（250ms）を超過した場合、または 5xx / 429 発生時は、即座に Safe Default（セキュリティ判定なら「要確認」、レコメンドなら「デフォルト表示」）へ倒し、ユーザー要求全体のタイムアウトを防ぐ。
