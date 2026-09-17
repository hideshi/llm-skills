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

### 【TypeScript / JavaScript の場合】
```typescript
import { choice, noul, score, TypeSafeClient } from '@typesafe-ai/sdk';

/**
 * TypeSafe System One (Jev) 質問定義
 */
export const [Feature]Questions = {
  // Choice の場合:
  category: choice('分類指示文...', {
    option_a: '条件Aの説明...',
    option_b: '条件Bの説明...',
  }),

  // または Noul の場合:
  isViolation: noul('この入力は○○の規約に違反していますか？'),
};
```

### 【Python の場合】
```python
from typesafe_sdk import TypeSafeClient, choice, noul, score

questions = {
    "is_violation": noul("Does this input violate safety guidelines?"),
}
```

---

## 3. 閾値設計 & 3段階ハンドリング戦略 (Noul の場合)

> **注記**: 以下の閾値（0.95 / 0.05）は初期仮説値です。必ずラベル付きデータセットによる検証を経て確定してください。

### ハンドリングマトリクス
| 判定区分 | 確率条件 ($p = \text{noul}$) | 実行アクション | 理由・リスク |
| :--- | :--- | :--- | :--- |
| **① BLOCK 判定** | $p \ge 0.95$ (blockThreshold) | 即時ブロック・遮断を実行 | 確信を持って違反と判定。誤検知リスク極小。 |
| **② ALLOW 判定** | $p \le 0.05$ (allowThreshold) | 即時通過・後続処理を実行 | 確信を持って安全と判定。見逃しリスク極小。 |
| **③ REVIEW 判定 (中間帯)** | $0.05 < p < 0.95$ | 人手キューまたは生成LLMへ移送 | 不確実領域のため安全側に倒して確認。 |

---

## 4. プロダクション実装コード例 (TypeScript / 公式SDK準拠)

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

export async function executeSafetyDecision(stateText: string): Promise<DecisionResult> {
  const start = Date.now();

  try {
    // 1. Jev API 呼出 (タイムアウト 250ms 設定)
    const response = await client.systemOne({
      state: stateText,
      questions: safetyQuestions,
    }, { timeout: 250 });

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
    // 3. API障害・タイムアウト時の Safe Default (安全側に倒す)
    console.error('TypeSafe API failed or timed out:', error);
    return {
      status: 'REVIEW_REQUIRED',
      reason: 'SYSTEM_ERROR_TIMEOUT_SAFE_DEFAULT',
      source: 'SAFE_DEFAULT',
      latencyMs: Date.now() - start,
    };
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
  - [ ] Precision / Recall / 自動化率シミュレーションに基づく `blockThreshold` と `allowThreshold` の確定
- [ ] **サービス実装 & 耐障害性**:
  - [ ] 質問定義（`choice` / `score` / `noul`）の実装
  - [ ] 3段階分岐ロジックと Safe Default の実装
  - [ ] 呼出Deadline（250ms）とタイムアウトハンドリングの実装
- [ ] **テスト実装**:
  - [ ] 閾値境界値テスト（閾値直下・一致・直上の挙動確認）
  - [ ] 中間帯（不確実領域）の REVIEW 遷移テスト
  - [ ] タイムアウトおよび 5xx / 429 エラー時の Safe Default 縮退テスト
- [ ] **監視・運用**:
  - [ ] メトリクス監視（Jev呼出成功率、p95レイテンシ、REVIEW率）の設定
  - [ ] モデルドリフト・質問文変更時の定期再評価プロセスの定義
