# Jev 詳細ロジック設計書 (design.md 追記用)

## 1. 対象業務ロジックの概要
- **機能名**: 
- **目的**: 
- **配置レイヤー**: [例: BFF層 / ドメインサービス / APIゲートウェイ]

---

## 2. Jev スキーマ & TypeScript 型定義

```typescript
/**
 * Jev 判定用スキーマ定義
 */
export const [Feature]JevSchema = {
  // スキーマ定義
} as const;

/**
 * 判定結果の型定義
 */
export interface [Feature]DecisionResult {
  // 型定義
}
```

---

## 3. 確信度（Confidence）設計とフォールバック戦略

| 確信度範囲 (Score) | 判定区分 | 実行アクション |
| :--- | :--- | :--- |
| **0.95 〜 1.00** | **高信頼 (Automated)** | Jev の結果をそのまま採用し、即時後続処理を実行。 |
| **0.80 〜 0.94** | **要確認 (Degraded)** | [例: ユーザーに確認プロンプトを提示 / デフォルト安全側に倒す] |
| **0.00 〜 0.79** | **エスカレーション (Fallback)** | 生成LLM（Claude/GPT）による詳細コンテキスト再推論、または人手レビュー。 |

---

## 4. 実装コード例 (TypeScript)

```typescript
import { JevClient } from '@typesafe-ai/jev';

const jev = new JevClient({
  apiKey: process.env.JEV_API_KEY,
});

export async function execute[Feature]Decision(input: string): Promise<[Feature]DecisionResult> {
  const start = Date.now();
  
  // 1. Jev による超高速判定 (~100ms)
  const decision = await jev.classify({
    input,
    schema: [Feature]JevSchema,
  });

  // 2. 確信度に応じたフォールバック
  if (decision.confidence < 0.80) {
    return await fallbackToDeepAnalysis(input);
  }

  return {
    value: decision.value,
    confidence: decision.confidence,
    latencyMs: Date.now() - start,
  };
}
```

---

## 5. 仕様駆動開発（tasks.md）へのタスク展開案
- [ ] Jev API クライアント環境変数（`JEV_API_KEY`）の設定
- [ ] `[Feature]DecisionService` の実装と型定義
- [ ] 低確信度時のフォールバック先（生成LLMまたは人手レビュー）の実装
- [ ] 単体テスト（高確信度パターン・低確信度パターンの境界値検証）
