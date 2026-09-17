# Jev 詳細ロジック設計書 (design.md / ADR 追記用)

## 1. 業務判断の責務 & ADR 参照
- **対象 Requirement ID**: `[例: REQ-SEC-01]`
- **機能名 / 責務**: 
- **承認ステータス**: `decision: approved` (承認者: ________ / 承認日: ________)
- **ADR 参照**: [ADR-00X: Jevによる○○判定の導入 / design.md 内のDecision節]
- **採用プリミティブ**: [choice / score / noul]
- **Jev が決めること**: [例: 入力テキストが安全基準に違反している確率]
- **コードが決めること**: [例: 確率が閾値を超えた際のアカウント一時停止処理・DB更新]

---

## 2. 判定スキーマ & プリミティブ定義

### 【TypeScript / JavaScript の場合】(小文字 builder 関数)
```typescript
import { choice, noul, score, TypeSafeClient } from '@typesafe-ai/sdk';

export const safetyQuestions = {
  // Noul: Yes/No 確率判定
  isViolation: noul('Does this input violate our safety guidelines?'),

  // Choice: 排他選択肢 (オブジェクト形式)
  category: choice('What category does this violation belong to?', {
    hate_speech: 'Hate speech or discriminatory language',
    harassment: 'Personal attacks or threats',
    spam: 'Commercial spam or unsolicited promotion',
  }),

  // Score: 順序尺度 (0始まりの順序付き配列)
  severity: score('Rate the severity of this issue', [
    'Low: Minor nuisance, no harm',
    'Medium: Disruptive behavior',
    'Critical: Severe threat or illegal content',
  ]),
};
```

### 【Python の場合】(大文字 クラス)
```python
from typesafe_sdk import TypeSafeClient, Choice, Noul, Score

safety_questions = {
    "is_violation": Noul(
        instructions="Does this input violate our safety guidelines?"
    ),
    "category": Choice(
        instructions="What category does this violation belong to?",
        criteria={
            "hate_speech": "Hate speech or discriminatory language",
            "harassment": "Personal attacks or threats",
            "spam": "Commercial spam or unsolicited promotion",
        }
    ),
    "severity": Score(
        instructions="Rate the severity of this issue",
        levels=[
            "Low: Minor nuisance, no harm",
            "Medium: Disruptive behavior",
            "Critical: Severe threat or illegal content",
        ]
    ),
}
```

### 【HTTP REST API の場合】(SDK非対応言語: Go, Rust等)
- **Endpoint**: `POST https://api.typesafe.ai/v1/systemone`
- **Headers**:
  - `Authorization: Bearer <TYPESAFE_API_KEY>`
  - `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "state": "User submitted comment text...",
    "questions": {
      "isViolation": {
        "type": "noul",
        "instructions": "Does this input violate our safety guidelines?"
      },
      "category": {
        "type": "choice",
        "instructions": "What category does this belong to?",
        "criteria": {
          "hate_speech": "Hate speech...",
          "spam": "Commercial spam..."
        }
      },
      "severity": {
        "type": "score",
        "instructions": "Rate the severity",
        "levels": ["Low...", "Medium...", "Critical..."]
      }
    }
  }
  ```
- **Response Body**:
  ```json
  {
    "answers": {
      "isViolation": { "noul": 0.982 },
      "category": { "choice": "hate_speech", "confidence": 0.94, "probabilities": { "hate_speech": 0.94, "spam": 0.06 } },
      "severity": { "score": 2.85, "confidence": 0.91, "probabilities": [0.02, 0.11, 0.87], "legend": ["Low...", "Medium...", "Critical..."] }
    }
  }
  ```

---

## 3. 閾値設計 & 3段階ハンドリング戦略 (Noul の場合)

> **⚠️ 注意**: 以下の閾値は初期設計仮説です。本番運用前に必ず評価データセット（Ground Truth）上で目標指標をクリアしていることを実証してください。

### 目標評価指標 & 状態
- **目標 FP率 (False Positive)**: $\le 1.0\%$ (評価セット上、95%信頼上限)
- **目標 FN率 (False Negative)**: $\le 0.5\%$ (評価セット上、95%信頼上限)
- **検証ステータス**: `未検証 (初期仮説)`

### ハンドリングマトリクス
| 判定区分 | 確率条件 ($p = \text{noul}$) | 実行アクション | 理由・縮退先 |
| :--- | :--- | :--- | :--- |
| **① BLOCK 判定** | $p \ge 0.95$ (blockThreshold) | 即時ブロック・遮断を実行 | 目標FP率をクリアした高確信領域。 |
| **② ALLOW 判定** | $p \le 0.05$ (allowThreshold) | 即時通過・後続処理を実行 | 目標FN率をクリアした高確信領域。 |
| **③ REVIEW 判定 (中間帯)** | $0.05 < p < 0.95$ | 人手キューまたは生成LLMへ移送 | 不確実領域のため安全側に倒して確認・縮退。 |

---

## 4. プロダクション実装コード例 (TypeScript / 公式SDK準拠 / 外側絶対Deadline)

```typescript
import { TypeSafeClient, noul } from '@typesafe-ai/sdk';

const client = new TypeSafeClient({
  apiKey: process.env.TYPESAFE_API_KEY,
});

export const safetyQuestions = {
  isViolation: noul('Does this input violate our safety guidelines?'),
};

export interface DecisionResult {
  status: 'ALLOW' | 'BLOCK' | 'REVIEW_REQUIRED';
  reason: string;
  source: 'JEV_AUTOMATED' | 'FALLBACK_REVIEW' | 'SAFE_DEFAULT';
  latencyMs: number;
}

// プロジェクトSLOから導出した時間予算パラメータ
const JEV_TOTAL_BUDGET_MS = 350; // 外側絶対締め切り
const ATTEMPT_TIMEOUT_MS = 150;  // 1試行あたりのタイムアウト
const MAX_RETRIES = 1;           // 最大リトライ回数
const BACKOFF_MS = 20;

export async function executeSafetyDecision(stateText: string): Promise<DecisionResult> {
  const start = Date.now();
  const controller = new AbortController();
  const deadlineTimer = setTimeout(() => controller.abort(), JEV_TOTAL_BUDGET_MS);

  try {
    // 1. 外側絶対Deadline + SDK内試行制限による呼出
    const response = await client.systemOne({
      state: stateText,
      questions: safetyQuestions,
    }, {
      timeout: ATTEMPT_TIMEOUT_MS,
      retry: {
        maxRetries: MAX_RETRIES,
        backoffInitialMs: BACKOFF_MS,
        backoffMaxMs: BACKOFF_MS,
      },
      signal: controller.signal,
    });

    const pViolation = response.answers.isViolation.noul;

    // 2. 表と完全に一致した3段階ハンドリング
    if (pViolation >= 0.95) {
      return { status: 'BLOCK', reason: 'CONFIRMED_VIOLATION', source: 'JEV_AUTOMATED', latencyMs: Date.now() - start };
    }
    if (pViolation <= 0.05) {
      return { status: 'ALLOW', reason: 'CONFIRMED_SAFE', source: 'JEV_AUTOMATED', latencyMs: Date.now() - start };
    }

    // 中間帯 (0.05 < p < 0.95): 不確実なためレビュー/エスカレーションへ
    return { status: 'REVIEW_REQUIRED', reason: `UNCERTAIN_PROBABILITY (p=${pViolation})`, source: 'FALLBACK_REVIEW', latencyMs: Date.now() - start };

  } catch (error) {
    // 3. API障害・Deadline超過時の Safe Default (安全側に倒す)
    console.error('TypeSafe API failed or deadline exceeded:', error);
    return {
      status: 'REVIEW_REQUIRED',
      reason: 'SYSTEM_ERROR_OR_DEADLINE_EXCEEDED',
      source: 'SAFE_DEFAULT',
      latencyMs: Date.now() - start,
    };
  } finally {
    clearTimeout(deadlineTimer);
  }
}
```

---

## 5. 実装 & 評価・運用タスク (tasks.md 展開用)

- [ ] **環境設定 & シークレット管理**:
  - [ ] `TYPESAFE_API_KEY` の設定
  - [ ] プロジェクトのスタックに応じたSDK導入（JS/TS: `@typesafe-ai/sdk`, Python: `typesafe-sdk`, その他: HTTP API契約）
- [ ] **評価データセット構築 & 実証的閾値決定**:
  - [ ] 発生頻度・クラス別カバレッジ・境界ケースを満たす評価データセットの作成
  - [ ] 目標FP率（$\le 1\%$）およびFN率（$\le 0.5\%$）を達成する `blockThreshold` と `allowThreshold` の確定（検証ステータス更新）
- [ ] **サービス実装 & 耐障害性**:
  - [ ] 質問定義（`choice` / `score` / `noul`）の実装
  - [ ] 3段階分岐ロジックと Safe Default の実装
  - [ ] 外側絶対Deadline（`JEV_TOTAL_BUDGET_MS`）とAbortControllerの実装
- [ ] **テスト実装**:
  - [ ] 閾値境界値テスト（閾値直下・一致・直上の挙動確認）
  - [ ] 中間帯（不確実領域）の REVIEW 遷移テスト
  - [ ] タイムアウトおよび 5xx / 429 エラー時の Safe Default 縮退テスト
- [ ] **監視・運用**:
  - [ ] メトリクス監視（Jev呼出成功率、p95レイテンシ、REVIEW率）の設定
  - [ ] モデルドリフト・質問文変更時の定期再評価プロセスの定義
