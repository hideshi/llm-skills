# Jev vs 生成LLM コスト & レイテンシ比較リファレンス (TCO算出モデル)

## 1. 単価リファレンス (2026-09-18 調査・一次情報基準)

| 判定手段 | 入力単価 (/1M tokens) | 出力単価 (/1M tokens) | 出力特性 | 想定レイテンシ (PoC前の参考仮説値) | 一次情報ソース / 取得日 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TypeSafe Jev** | **$0.042** | **$0.00 (無料)** | 構造化判定 (choice/score/noul) | ベンチマーク公称 70〜150ms (RTT未含) | typesafe.ai (2026-09-18) |
| **GPT-4o-mini** | $0.150 | $0.600 | 自然言語 / JSON Mode | ベンチマーク公称 600〜1,200ms | openai.com/pricing (2026-09-18) |
| **Claude 3.5 Haiku** | $0.800 | $4.000 | 自然言語 / Tool Use | ベンチマーク公称 800〜1,500ms | anthropic.com/pricing (2026-09-18) |
| **Gemini 1.5 Flash** | $0.075 | $0.300 | 自然言語 / Structured Output | ベンチマーク公称 500〜1,000ms | ai.google.dev/pricing (2026-09-18) |
| **人手レビュー** | - | - | オペレーター目視確認 | 数分 〜 数時間 | 1件あたり $0.10〜$0.50 (想定人件費) |

> **⚠️ 注意（レイテンシの扱い）**:
> 上記レイテンシはベンダー公開値または参考公称値であり、ネットワークRTT・リージョン・入力長・コールドスタートを含みません。**設計判断におけるp50/p95値は、自環境でのPoC実測値を必ず使用してください。**

---

## 2. 月間期待総保有コスト (Expected Monthly TCO) 計算モデル

単位（月間総額 $）を厳密に揃えたTCO計算式です。

$$\text{Expected Monthly Cost} = N \times C_{\text{jev\_req}} + N \times P(\text{review}) \times C_{\text{review\_case}} + N \times P(\text{fallback}) \times C_{\text{fallback\_case}} + C_{\text{retry\_overhead}} + C_{\text{fixed\_ops}}$$

### 各項の定義と次元:
- **$N$**: 月間リクエスト総数 (requests/month)
- **$C_{\text{jev\_req}}$ (Jev 1回あたり呼出単価 [$])**:
  $$C_{\text{jev\_req}} = \frac{(T_{\text{state}} + T_{\text{instructions}} + T_{\text{criteria}}) \times \$0.042}{1,000,000}$$
- **$P(\text{review})$**: 人手確認・レビュー経路へ回る確率 ($0.0 \le P \le 1.0$)
- **$C_{\text{review\_case}}$**: 人手レビュー1件あたりの人件費コスト ($/case, 例: $0.10)
- **$P(\text{fallback})$**: 生成型LLMによるエスカレーションまたはAPI障害時フォールバックへ回る確率 ($0.0 \le P \le 1.0$)
  *※ レビューとフォールバックは原則排他的な経路としてモデル化（$P(\text{auto}) + P(\text{review}) + P(\text{fallback}) = 1.0$）*
- **$C_{\text{fallback\_case}}$**: 代替LLM（GPT-4o-mini等）の1回あたり呼出コスト ($/case)
  $$C_{\text{fallback\_case}} = \frac{T_{\text{in}} \times P_{\text{in}} + T_{\text{out}} \times P_{\text{out}}}{1,000,000}$$
- **$C_{\text{retry\_overhead}}$**: 429/タイムアウト再試行に伴う追加コスト (通常は $N \times C_{\text{jev\_req}} \times 0.01\sim 0.03$)
- **$C_{\text{fixed\_ops}}$**: 監視、ログ保管、定期評価データセット保守等の固定運用費 ($/month)

---

## 3. 入力トークン長 ($T_{\text{state}}$) 推定ガイドライン

- **短文・UI入力・インテント判定**: 150 〜 300 tokens (State本文 + instructions + criteria)
- **中長文・コメント・レビュー・問い合わせ**: 600 〜 1,200 tokens
- **長文・ドキュメント・RAGチャンク**: 2,500 〜 4,500 tokens
