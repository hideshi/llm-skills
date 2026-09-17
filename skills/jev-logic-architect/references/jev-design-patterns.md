# TypeSafe AI Jev 3大プリミティブ & 確信度・閾値設計リファレンス

## 1. 3つの意思決定プリミティブと公式SDK仕様 (JS/TS & Python)

TypeSafe AI（Jev）は単一の汎用型ではなく、3つの明確なプリミティブを提供します。
**JavaScript SDK は小文字の builder 関数（`choice`, `score`, `noul`）**、**Python SDK は大文字クラス（`Choice`, `Score`, `Noul`）** を使用します。

### ① `choice`（多肢選択・排他分類）
- **用途**: カテゴリ分類、ルーティング、担当部署決定。
- **TypeScript**:
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
- **Python**:
  ```python
  from typesafe_sdk import Choice

  questions = {
      "department": Choice(
          instructions="Which team should handle this inquiry?",
          criteria={
              "billing": "Payment, invoices, and subscription questions",
              "technical": "API errors, bugs, and integration problems",
              "sales": "Enterprise plans, demo requests, and pricing",
          }
      )
  }
  ```
- **応答形式**: `response.answers.department`
  - `choice: string` (選ばれたキー)
  - `probabilities: Record<string, number>` (各選択肢の確率分布)
  - `confidence: number` (選択肢間の「分布の集中度」)

### ② `score`（順序尺度・レベル評価）
- **用途**: 緊急度（Low/Med/High）、深刻度レベル（0〜N）、品質評価。
- **TypeScript (※ 0始まりの順序付き配列を渡す)**:
  ```typescript
  import { score } from '@typesafe-ai/sdk';

  const questions = {
    urgency: score('Rate the urgency of this request', [
      'Low: General question, no immediate deadline',
      'Medium: Needs response within 24 hours',
      'Critical: Production outage or data breach',
    ]),
  };
  ```
- **Python (※ criteria にリストを渡す)**:
  ```python
  from typesafe_sdk import Score

  questions = {
      "urgency": Score(
          instructions="Rate the urgency of this request",
          criteria=[
              "Low: General question, no immediate deadline",
              "Medium: Needs response within 24 hours",
              "Critical: Production outage or data breach",
          ],
      )
  }
  ```
- **応答形式 (TypeScript: `response.answers.urgency`, Python: `response.answers["urgency"]`)**:
  - **`score: number` (確率加重された期待値。整数とは限らない)**
  - `confidence: number` (分布の集中度)
  - `legend: Record<string, string>` (スコア番号をキーとする辞書: `{"0": "Low...", "1": "Medium...", "2": "Critical..."}`)
  - `probabilities: Record<string, number>` (スコア番号をキーとする辞書: `{"0": 0.02, "1": 0.11, "2": 0.87}`)

### ③ `noul`（Yes/No の命題確率判定）
- **用途**: スパム判定、ポリシー違反チェック、エスカレーション要否。
- **TypeScript**:
  ```typescript
  import { noul } from '@typesafe-ai/sdk';

  const questions = {
    isViolation: noul('Does this input violate our safety guidelines?'),
  };
  ```
- **Python**:
  ```python
  from typesafe_sdk import Noul

  questions = {
      "is_violation": Noul(
          instructions="Does this input violate our safety guidelines?"
      )
  }
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

## 2. タイムアウト・リトライ・締め切り制約（Deadline Hierarchy）

プロジェクトのSLOを満たすため、固定値を決め打ちせず、以下のパラメータ関係式に基づいて時間予算（Time Budget）を設計します。

### パラメータ関係式:
$$\text{requestDeadlineMs} \ge \text{jevTotalBudgetMs} + \text{fallbackBudgetMs}$$
$$\text{jevTotalBudgetMs} \ge (\text{attemptTimeoutMs} \times (\text{maxRetries} + 1)) + \text{backoffBudgetMs}$$

### 設定例（レイテンシSLOが厳しいオンライン対話の場合）:
- `requestDeadlineMs`: 800ms (ユーザー要求全体の打ち切り)
- `jevTotalBudgetMs`: 350ms (Jev判定全体の絶対締め切り)
- `attemptTimeoutMs`: 150ms (SDKの1回呼出タイムアウト)
- `maxRetries`: 1回 (リトライ最大1回)
- `backoffInitialMs`: 20ms
- `fallbackBudgetMs`: 450ms (超過時のSafe Defaultまたは軽量LLMエスカレーション用)

### 外側絶対Deadlineの実装パターン (AbortController):
```typescript
const controller = new AbortController();
const deadline = setTimeout(() => controller.abort(), JEV_TOTAL_BUDGET_MS);

try {
  const response = await client.systemOne(request, {
    timeout: ATTEMPT_TIMEOUT_MS,
    retry: {
      maxRetries: MAX_RETRIES,
      backoffInitialMs: BACKOFF_MS,
    },
    signal: controller.signal,
  });
  return handleResponse(response);
} catch (error) {
  // タイムアウトまたは障害時は即座に Safe Default へ縮退
  return getSafeDefault();
} finally {
  clearTimeout(deadline);
}
```

---

## 3. 実証的な閾値（Threshold）選定プロセス

固定の経験則（0.95, 0.05等）は**初期仮説に過ぎず、プロダクション投入前に検証が必須**です。

1. **評価データセットの準備**:
   - クラス別発生率（Prevalence）、求めるPrecision/Recallの信頼区間、重要な境界ケースのカバレッジを満たすサンプルを用意。
2. **コスト行列（Cost Matrix）と目標値の定義**:
   - 目標: FP率 $\le X\%$ (評価セット上、95%信頼上限)
   - 目標: FN率 $\le Y\%$ (評価セット上、95%信頼上限)
   - 状態: `未検証` → `検証済み` へ昇格。
3. **ROC / Precision-Recall 分析**:
   - 閾値を変化させたときの自動化率（Coverage）とエラー率のトレードオフを算出し、`blockThreshold` と `allowThreshold` を確定。
4. **本番ドリフト監視とロールバック**:
   - レビュー率（中間帯比率）を常時監視し、質問文やモデル更新時は再評価を実施。
