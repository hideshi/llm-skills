# Jev vs 生成LLM コスト & レイテンシ比較リファレンス (TCO算出モデル)

## 1. 単価リファレンス (2026-09-18 調査・一次情報基準)

| モデル / 判定手段 | 入力単価 (/1M tokens) | 出力単価 (/1M tokens) | 出力特性 | 想定RTTレイテンシ (p50 / p95) | 出典 / 取得日 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TypeSafe Jev** | **$0.042** | **$0.00 (無料)** | 構造化判定 (Choice/Score/Noul) | **80ms / 150ms** | typesafe.ai (2026-09) |
| **GPT-4o-mini** | $0.150 | $0.600 | 自然言語 / JSON Mode | 650ms / 1,200ms | openai.com/pricing (2026-09) |
| **Claude 3.5 Haiku** | $0.800 | $4.000 | 自然言語 / Tool Use | 800ms / 1,500ms | anthropic.com/pricing (2026-09) |
| **Gemini 1.5 Flash** | $0.075 | $0.300 | 自然言語 / Structured Output | 500ms / 1,000ms | ai.google.dev/pricing (2026-09) |
| **人手レビュー (参考)** | - | - | オペレーター目視確認 | 数分 〜 数時間 | 1件あたり 約 $0.10〜$0.50 想定 |

---

## 2. 期待総保有コスト (Expected TCO) 計算式

Jev導入時の総コストは、単なるAPI呼出費だけでなく、**「低信頼・中間帯時のフォールバック発生確率」** を含めた期待値で計算する必要があります。

$$\text{Expected Cost} = C_{jev} + P(review) \times C_{review} + P(fallback) \times C_{fallback} + C_{retry}$$

### 内訳:
1. **$C_{jev}$ (Jev呼出費)**:
   $$\frac{N \times (T_{state} + T_{instructions} + T_{criteria}) \times \$0.042}{1,000,000}$$
   *※ 単なる入力テキストだけでなく、State、Instructions、Choice criteria 等のメタデータトークンも含める。*
2. **$P(review) \times C_{review}$ (中間帯・人手確認コスト)**:
   不確実性により人間オペレーターへ回す割合 $\times$ 人件費。
3. **$P(fallback) \times C_{fallback}$ (低確信・LLMエスカレーションコスト)**:
   Jevで判定不能、またはエラー時に生成型LLM（GPT-4o-mini等）を呼ぶ割合 $\times$ LLM呼出コスト。
4. **$C_{retry}$ (リトライ・タイムアウト・障害オーバーヘッド)**:
   ネットワーク揺らぎやレート制限時のリトライ分（通常は全体の 1〜3% をバッファとして見込む）。

---

## 3. 入力トークン長 ($T_{state}$) 推定ガイドライン

- **短文・UI入力・インテント判定**: 150 〜 300 tokens (メタデータ含む)
- **中長文・コメント・レビュー・問い合わせ**: 600 〜 1,200 tokens (メタデータ含む)
- **長文・ドキュメント・RAGチャンク**: 2,500 〜 4,500 tokens (メタデータ含む)
