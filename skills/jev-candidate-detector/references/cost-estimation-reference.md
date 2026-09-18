# Jev vs 生成LLM コスト & レイテンシ比較リファレンス (TCO算出モデル)

## 1. 単価リファレンス (2026-09-18 調査・一次情報基準)

| 判定手段 | 入力単価 (/1M tokens) | 出力単価 (/1M tokens) | 出力特性 | 想定レイテンシ (PoC前の参考仮説値) | 一次情報ソース / 取得日 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TypeSafe Jev** | **USD 0.042** | **USD 0.00 (無料)** | 構造化判定 (choice/score/noul) | ベンチマーク公称 70〜150ms (RTT未含) | typesafe.ai (2026-09-18) |
| **GPT-4o-mini** | USD 0.150 | USD 0.600 | 自然言語 / JSON Mode | ベンチマーク公称 600〜1,200ms | openai.com/pricing (2026-09-18) |
| **Claude 3.5 Haiku** | USD 0.800 | USD 4.000 | 自然言語 / Tool Use | ベンチマーク公称 800〜1,500ms | anthropic.com/pricing (2026-09-18) |
| **Gemini 1.5 Flash** | USD 0.075 | USD 0.300 | 自然言語 / Structured Output | ベンチマーク公称 500〜1,000ms | ai.google.dev/pricing (2026-09-18) |
| **人手レビュー** | - | - | オペレーター目視確認 | 数分 〜 数時間 | 1件あたり 0.10〜0.50 USD (想定人件費) |

> **⚠️ 注意（レイテンシの扱い）**:
> 上記レイテンシはベンダー公開値または参考公称値であり、ネットワークRTT・リージョン・入力長・コールドスタートを含みません。**設計判断におけるp50/p95値は、自環境でのPoC実測値を必ず使用してください。**
>
> **🌏 日本からの呼出しにおける地理的オーバーヘッド（2026-09-18 調査）**:
> クライアントが日本にありAPIエンドポイントが米国にある場合、太平洋横断RTT（東京↔米西海岸: 約100〜120ms、米東海岸: 約140〜160ms）が上乗せされます。新規接続時はTLSハンドシェイク（1〜2 RTT）がさらに加わります。
> - 参考実測: 米国内からのTTFT 約40〜80msに対し、東京からは OpenAI 235〜480ms / Anthropic 260〜520ms（概ね2倍前後）との報告がある。
> - したがって公称70〜150msの判定APIでも、日本発では実効170〜310ms程度になり得る。**p95 < 200ms級の要件判定はクライアント所在地を考慮すること。**
> - ソース: hatsnet RTT matrix / WonderNetwork / Verizon Global Latency SLA / dataku.ai（いずれも2026-09-18確認）

---

## 2. 月間期待総保有コスト (Expected Monthly TCO) 計算モデル

単位（月間総額 USD）を厳密に揃えたTCO計算式です。通貨記号 `$` は Markdown の数式区切りと衝突するため、金額はすべて `USD` と表記します。

$$
\text{Expected Monthly Cost} = N \times C_{\mathrm{jev}} + N \times P(\mathrm{review}) \times C_{\mathrm{review}} + N \times P(\mathrm{fallback}) \times C_{\mathrm{fallback}} + C_{\mathrm{retry}} + C_{\mathrm{ops}}
$$

### 各項の定義と次元

- **N**: 月間リクエスト総数 (requests/month)
- **C_jev** (Jev 1回あたり呼出単価 [USD])。0.042 は入力 1M tokens あたりの単価（出力は無料）:

$$
C_{\mathrm{jev}} = \frac{(T_{\mathrm{state}} + T_{\mathrm{instructions}} + T_{\mathrm{criteria}}) \times 0.042}{1000000}
$$

- **P(review)**: 人手確認・レビュー経路へ回る確率 (0.0 ≦ P ≦ 1.0)
- **C_review**: 人手レビュー1件あたりの人件費コスト (USD/case, 例: 0.10 USD)
- **P(fallback)**: 生成型LLMによるエスカレーションまたはAPI障害時フォールバックへ回る確率 (0.0 ≦ P ≦ 1.0)
  - ※ レビューとフォールバックは原則排他的な経路としてモデル化（P(auto) + P(review) + P(fallback) = 1.0）
- **C_fallback**: 代替LLM（GPT-4o-mini等）の1回あたり呼出コスト (USD/case)

$$
C_{\mathrm{fallback}} = \frac{T_{\mathrm{in}} \times P_{\mathrm{in}} + T_{\mathrm{out}} \times P_{\mathrm{out}}}{1000000}
$$

- **C_retry**: 429/タイムアウト再試行に伴う追加コスト（通常は N × C_jev × 0.01〜0.03）
- **C_ops**: 監視、ログ保管、定期評価データセット保守等の固定運用費 (USD/month)

### ベースライン（従来の生成LLMのみ）の比較式

$$
\text{Baseline Monthly Cost} = N \times \frac{T_{\mathrm{in}} \times P_{\mathrm{in}} + T_{\mathrm{out}} \times P_{\mathrm{out}}}{1000000}
$$

（現行利用中のLLMの単価を使用。C_fallback と同形だが、全リクエストに適用する点が異なる）

### 経路分岐率 (P(auto) / P(review) / P(fallback)) の設定ガイドライン

- 評価データセットによる実測値がある場合はそれを使用する。
- **実測値がない場合は楽観値を推測で置かず、保守的デフォルト（例: P(auto) = 80%, P(fallback) = 15%, P(review) = 5%）を使用**し、レポートに「仮定値」である旨を明記する。
- 可能であれば分岐率を変えた感度分析（楽観 / 標準 / 悲観）を併記する。

---

## 3. 入力トークン長の推定ガイドライン

> **⚠️ 二重計上の防止**: 以下のレンジは **T_state + T_instructions + T_criteria の合計値** に対応する。C_jev 計算時に instructions / criteria を別途加算しないこと。

- **短文・UI入力・インテント判定**: 150 〜 300 tokens (State本文 + instructions + criteria)
- **中長文・コメント・レビュー・問い合わせ**: 600 〜 1,200 tokens
- **長文・ドキュメント・RAGチャンク**: 2,500 〜 4,500 tokens
