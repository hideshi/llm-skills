# Jev 詳細ロジック設計書 (design.md / ADR 追記用)

## 1. 業務判断の責務 & ADR 参照
- **対象 Requirement ID**: `[例: REQ-SEC-01]`
- **機能名 / 責務**: 
- **承認ステータス**: `decision: approved` (承認者: ________ / 承認日: ________)
- **ADR 参照**: [ADR-00X: Jevによる○○判定の導入 / design.md 内のDecision節]
- **採用プリミティブ**: [Choice / Score / Noul]
- **Jev が決めること**: [例: 入力テキストが利用規約に違反している確率]
- **コードが決めること**: [例: 確率が閾値を超えた際のアカウント一時停止処理・DB更新]

---

## 2. 判定スキーマ & プリミティブ定義

```typescript
import { Choice, Score, Noul } from '@typesafe-ai/sdk';

/**
 * TypeSafe System One (Jev) 質問定義
 */
export const [Feature]Questions = {
  // Choice の場合:
  category: new Choice({
    instructions: '分類指示文...',
    criteria: {
      option_a: '条件Aの説明...',
      option_b: '条件Bの説明...',
    },
  }),

  // または Noul の場合:
  isViolation: new Noul({
    instructions: 'この入力は○○の規約に違反していますか？',
  }),
};
```

---

## 3. 閾値設計 & 3段階ハンドリング戦略

> **注記**: 以下の閾値は初期仮説値です。必ず `docs/eval/` 配下のラベル付きデータセットによる Precision/Recall 検証を経て確定してください。

### ハンドリングマトリクス
| 判定区分 | 確率・確信度条件 | 実行アクション | 誤判定時のリスク・コスト |
| :--- | :--- | :--- | :--- |
| **高信頼 (自動実行)** | [例: $p \ge 0.95$ または $p \le 0.05$] | Jevの判定に従い即座に自動処理を実行。 | 低 (自動化メリット大) |
| **中間帯 (確認・縮退)**| [例: $0.80 \le p < 0.95$] | ユーザーに確認を促す、または警告付きで処理。 | 中 (安全側に倒す) |
| **エスカレーション** | [例: 不確実 $0.05 < p < 0.80$] | 生成型LLMによる詳細推論、または人手キューへ移送。 | 高 (人手・高コスト) |

---

## 4. プロダクション実装コード例 (TypeScript / 公式SDK準拠)

```typescript
import { TypeSafeClient } from '@typesafe-ai/sdk';

const client = new TypeSafeClient({
  apiKey: process.env.TYPESAFE_API_KEY,
});

export interface DecisionResult {
  status: 'ALLOW' | 'BLOCK' | 'REVIEW_REQUIRED';
  reason?: string;
  source: 'JEV_AUTOMATED' | 'FALLBACK_LLM' | 'SAFE_DEFAULT';
  latencyMs: number;
}

export async function execute[Feature]Decision(stateText: string): Promise<DecisionResult> {
  const start = Date.now();

  try {
    // 1. Jev API 呼出 (タイムアウト・耐障害性考慮)
    const response = await client.systemOne({
      state: stateText,
      questions: [Feature]Questions,
    }, { timeout: 500 }); // 500ms でタイムアウト

    const pViolation = response.isViolation.probability;

    // 2. デュアル閾値による3段階ハンドリング (Noul の場合)
    if (pViolation >= 0.95) {
      return { status: 'BLOCK', source: 'JEV_AUTOMATED', latencyMs: Date.now() - start };
    }
    if (pViolation <= 0.05) {
      return { status: 'ALLOW', source: 'JEV_AUTOMATED', latencyMs: Date.now() - start };
    }

    // 3. 中間帯: 不確実性が高いためエスカレーション / 人手レビューへ
    return await fallbackToDeepAnalysis(stateText, 'UNCERTAIN_PROBABILITY');

  } catch (error) {
    // 4. API障害時のフォールバック & Safe Default
    console.error('TypeSafe API failed or timed out:', error);
    
    // クリティカル機能では Safe Default (安全側: REVIEW) に倒す
    return {
      status: 'REVIEW_REQUIRED',
      reason: 'SYSTEM_ERROR_FALLBACK',
      source: 'SAFE_DEFAULT',
      latencyMs: Date.now() - start,
    };
  }
}
```

---

## 5. 実装 & 評価・運用タスク (tasks.md 展開用)

- [ ] **環境設定 & シークレット管理**:
  - [ ] `TYPESAFE_API_KEY` の設定（開発・ステージング・本番環境）
  - [ ] `@typesafe-ai/sdk` パッケージのインストール
- [ ] **評価データセット構築 & 閾値検証**:
  - [ ] 最低 100 件のラベル付きテストデータ（Ground Truth）の作成
  - [ ] 閾値シミュレーション（Precision / Recall / レビュー率の測定と確定）
- [ ] **サービス実装**:
  - [ ] 質問定義（`Choice` / `Score` / `Noul`）の実装
  - [ ] 3段階分岐（自動 / 中間確認 / エスカレーション）および Safe Default の実装
  - [ ] タイムアウト（500ms）と限定リトライの実装
- [ ] **テスト実装**:
  - [ ] 閾値境界値テスト（閾値直下・一致・直上の振る舞い検証）
  - [ ] 中間帯（不確実領域）の確認・エスカレーション検証
  - [ ] APIタイムアウト、429、5xx 発生時の Safe Default 縮退テスト
- [ ] **監視・運用**:
  - [ ] メトリクス監視（Jev呼出成功率、p95レイテンシ、レビュー率）のダッシュボード設定
  - [ ] モデルドリフト・質問文変更時の再評価プロセスの定義
