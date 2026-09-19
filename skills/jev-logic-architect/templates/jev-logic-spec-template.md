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

> **💡 構成の注意**: SDK（TS/Python）例は**質問スキーマの定義のみ**を示します。`state`（判定対象の入力データ。文字列・オブジェクト・配列を受け付ける）は呼出時に渡します（§4 の実装例を参照）。HTTP 例はリクエスト全体の契約を示すため `state` を含みます。
>
> **💡 問いの設計**: 以下のコード例は構文サンプルです。instructions / criteria / state の中身の設計原則（1プリミティブ1問、MECE、脱出選択肢、行動アンカー、state の必要十分性等）は `references/jev-design-patterns.md` §2 を参照し、要件原文（Requirement ID 紐付け）から導出してください。

### 【TypeScript / JavaScript の場合】(小文字 builder 関数)
```typescript
import { choice, noul, score } from '@typesafe-ai/sdk';

// 質問スキーマの定義。state（判定対象データ）は呼出時に渡す（§4 参照）
export const safetyQuestions = {
  // Noul: Yes/No 確率判定（任意: criteria で Yes/No 各側の定義を明示可能。HTTP 例を参照）
  isViolation: noul('Does this input violate our safety guidelines?'),

  // Choice: 排他選択肢 (オブジェクト形式)
  category: choice('What category does this violation belong to?', {
    hate_speech: 'Hate speech or discriminatory language',
    harassment: 'Personal attacks or threats',
    spam: 'Commercial spam or unsolicited promotion',
    none: 'The input does not match any violation category',
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
from typesafe_sdk import Choice, Noul, Score

# 質問スキーマの定義。state（判定対象データ）は呼出時に渡す（§4 参照）
safety_questions = {
    # 任意: criteria で Yes/No 各側の定義を明示可能（HTTP 例を参照）
    "is_violation": Noul(
        instructions="Does this input violate our safety guidelines?"
    ),
    "category": Choice(
        instructions="What category does this violation belong to?",
        criteria={
            "hate_speech": "Hate speech or discriminatory language",
            "harassment": "Personal attacks or threats",
            "spam": "Commercial spam or unsolicited promotion",
            "none": "The input does not match any violation category",
        }
    ),
    "severity": Score(
        instructions="Rate the severity of this issue",
        criteria=[
            "Low: Minor nuisance, no harm",
            "Medium: Disruptive behavior",
            "Critical: Severe threat or illegal content",
        ],
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
        "instructions": "Does this input violate our safety guidelines?",
        "criteria": {
          "true": "The input violates the safety guidelines",
          "false": "The input does not violate the safety guidelines"
        }
      },
      "category": {
        "type": "choice",
        "instructions": "What category does this belong to?",
        "criteria": {
          "hate_speech": "Hate speech...",
          "harassment": "Personal attacks or threats",
          "spam": "Commercial spam...",
          "none": "The input does not match any violation category"
        }
      },
      "severity": {
        "type": "score",
        "instructions": "Rate the severity",
        "criteria": ["Low...", "Medium...", "Critical..."]
      }
    }
  }
  ```
- **Response Body**:
  ```json
  {
    "model": "jev-2026-09",
    "answers": {
      "isViolation": {
        "type": "noul",
        "noul": 0.982
      },
      "category": {
        "type": "choice",
        "choice": "hate_speech",
        "confidence": 0.88,
        "probabilities": { "hate_speech": 0.91, "harassment": 0.04, "spam": 0.03, "none": 0.02 }
      },
      "severity": {
        "type": "score",
        "score": 1.85,
        "confidence": 0.91,
        "legend": { "0": "Low...", "1": "Medium...", "2": "Critical..." },
        "probabilities": { "0": 0.02, "1": 0.11, "2": 0.87 }
      }
    },
    "usage": {
      "input_tokens": 142,
      "output_tokens": 48
    }
  }
  ```

---

## 3. 閾値設計 & 3段階ハンドリング戦略 (Noul の場合)

> **⚠️ 注意**: 以下の閾値は初期設計仮説です。本番運用前に必ず評価データセット（Ground Truth）上で目標指標をクリアしていることを実証してください。

### ハンドリングマトリクス (検証ステータス連動)

| ポリシー状態 (`validationStatus`) | 確率条件 ($p = \text{noul}$) | 判定結果 (`status`) | 実行アクション / 理由 |
| :--- | :--- | :--- | :--- |
| **`PENDING` (未検証・初期設計時)** | **全確率領域 ($0.0 \le p \le 1.0$)** | **`REVIEW_REQUIRED`** | **自動化禁止。実証前は全件レビューまたは安全側縮退。** |
| **`REJECTED` / `NEEDS_MORE_DATA`** | **全確率領域** | **`REVIEW_REQUIRED`** | **自動化禁止。差し戻し先は共有語彙に従う（architect / eval-set）。** |
| **`VALIDATED` (実証検証完了後)** | $p \ge \text{blockThreshold}$<br>*(例: 0.95)* | **`BLOCK`** | 即時ブロック。目標FP率（偽陽性率）をクリアした高確信領域。 |
| **`VALIDATED` (実証検証完了後)** | $p \le \text{allowThreshold}$<br>*(例: 0.05)* | **`ALLOW`** | 即時通過。目標FN率（偽陰性率）をクリアした高確信領域。 |
| **`VALIDATED` (実証検証完了後)** | $\text{allowThreshold} < p < \text{blockThreshold}$ | **`REVIEW_REQUIRED`** | 不確実領域のため安全側に倒して確認・エスカレーション。 |

*※ 上記の 0.95 / 0.05 は説明用の仮説値です。本番運用値は評価データセット検証を経て `DecisionPolicy` に注入されます。*

---

## 4. プロダクション実装コード例 (TypeScript / 公式SDK準拠 / 外側絶対Deadline)

```typescript
import { TypeSafeClient, noul } from '@typesafe-ai/sdk';

// SDKが TYPESAFE_API_KEY 環境変数を自動的に読み込む。
const client = new TypeSafeClient();

export const safetyQuestions = {
  isViolation: noul('Does this input violate our safety guidelines?'),
};

export interface DecisionPolicy {
  blockThreshold: number;      // 例: 0.95 (評価データセット実証値)
  allowThreshold: number;      // 例: 0.05 (評価データセット実証値)
  validationStatus: 'PENDING' | 'VALIDATED' | 'REJECTED' | 'NEEDS_MORE_DATA';
}

/**
 * ポリシーの健全性を検証 (範囲、逆転、NaN、未検証状態の防御)
 */
export function isValidPolicy(policy: DecisionPolicy): boolean {
  return (
    policy.validationStatus === 'VALIDATED' &&
    Number.isFinite(policy.allowThreshold) &&
    Number.isFinite(policy.blockThreshold) &&
    0 <= policy.allowThreshold &&
    policy.allowThreshold < policy.blockThreshold &&
    policy.blockThreshold <= 1
  );
}

export interface DecisionResult {
  status: 'ALLOW' | 'BLOCK' | 'REVIEW_REQUIRED';
  reason: string;
  source: 'JEV_AUTOMATED' | 'FALLBACK_REVIEW' | 'SAFE_DEFAULT';
  latencyMs: number;
}

// プロジェクトSLOから導出した時間予算パラメータ（記入例）
// JS SDKの timeout は1試行あたりで、リトライ全体の予算はないため外側絶対Deadlineが必要。
// 日本から米国エンドポイントへ呼ぶ場合、太平洋横断RTTが約100〜160msあるため
// ATTEMPT_TIMEOUT_MS=150 は仮説値に過ぎず、PoC実測で再設定すること。
const JEV_TOTAL_BUDGET_MS = 350; // 外側絶対締め切り
const ATTEMPT_TIMEOUT_MS = 150;  // 1試行あたりのタイムアウト
const MAX_RETRIES = 1;           // 最大リトライ回数
const BACKOFF_MS = 20;

export async function executeSafetyDecision(
  stateText: string,
  policy: DecisionPolicy,
): Promise<DecisionResult> {
  const start = Date.now();

  // 1. 安全性ガード: 実証未検証、または不正な閾値設定（逆転・NaN・範囲外）の場合は自動化を禁止
  if (!isValidPolicy(policy)) {
    return {
      status: 'REVIEW_REQUIRED',
      reason: 'POLICY_NOT_VALIDATED_OR_INVALID_THRESHOLDS',
      source: 'SAFE_DEFAULT',
      latencyMs: Date.now() - start,
    };
  }

  const controller = new AbortController();
  const deadlineTimer = setTimeout(() => controller.abort(), JEV_TOTAL_BUDGET_MS);

  try {
    // 2. 外側絶対Deadline + SDK内試行制限による呼出
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

    // 3. 実証済みポリシーに基づく3段階ハンドリング
    if (pViolation >= policy.blockThreshold) {
      return { status: 'BLOCK', reason: `VIOLATION_CONFIRMED (p=${pViolation})`, source: 'JEV_AUTOMATED', latencyMs: Date.now() - start };
    }
    if (pViolation <= policy.allowThreshold) {
      return { status: 'ALLOW', reason: `SAFE_CONFIRMED (p=${pViolation})`, source: 'JEV_AUTOMATED', latencyMs: Date.now() - start };
    }

    // 中間帯 (allowThreshold < p < blockThreshold): 不確実なためレビュー/エスカレーションへ
    return { status: 'REVIEW_REQUIRED', reason: `UNCERTAIN_PROBABILITY (p=${pViolation})`, source: 'FALLBACK_REVIEW', latencyMs: Date.now() - start };

  } catch (error) {
    // 4. API障害・Deadline超過時の Safe Default (安全側に倒す)
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
  - [ ] 評価セットの起票・スキーマ整合・freeze → **`jev-eval-set`**（`datasetStatus: frozen` + `datasetVersion`）
  - [ ] ラベリング方法論・一致率等の品質管理 → データ整備プロセス（`jev-eval-set` と併用）
  - [ ] 誤判定コスト・リスク・法的要件・レビュー可能件数から目標FP率・FN率等のゲート基準を**プロジェクト入力として**定義（数値はスキルに焼かない）
  - [ ] frozen セット上での閾値較正・`validationStatus`・shadow 記録（本番非適用）→ **`jev-calibration`**
- [ ] **サービス実装 & 耐障害性**:
  - [ ] 質問定義（`choice` / `score` / `noul`）の実装（instructions / criteria / state の設計原則は `references/jev-design-patterns.md` §2 を参照。質問文は版管理し、変更時は閾値を再較正する）
  - [ ] 3段階分岐ロジックと、業務側ステークホルダーが承認した Safe Default の実装（定義・選定原則は `references/jev-design-patterns.md` §3 を参照）
  - [ ] 外側絶対Deadline（`JEV_TOTAL_BUDGET_MS`）とAbortControllerの実装
- [ ] **テスト実装**:
  - [ ] 閾値境界値テスト（閾値直下・一致・直上の挙動確認）
  - [ ] 中間帯（不確実領域）の REVIEW 遷移テスト
  - [ ] タイムアウトおよび 5xx / 429 エラー時の Safe Default 縮退テスト
- [ ] **監視・運用**:
  - [ ] メトリクス監視（Jev呼出成功率、p95レイテンシ、REVIEW率）の設定
  - [ ] モデルドリフト・質問文変更時の定期再評価プロセスの定義
