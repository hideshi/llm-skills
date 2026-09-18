# TypeSafe AI Jev 3大プリミティブ・問いの設計・閾値設計リファレンス

## 1. 3つの意思決定プリミティブと公式SDK仕様 (JS/TS & Python)

TypeSafe AI（Jev）は単一の汎用型ではなく、3つの明確なプリミティブを提供します。
**JavaScript SDK は小文字の builder 関数（`choice`, `score`, `noul`）**、**Python SDK は大文字クラス（`Choice`, `Score`, `Noul`）** を使用します。

> **🌐 instructions / criteria の言語について（2026-09-18 調査）**:
> 公開ガイドでは「**英語が最高精度。他言語も動作するが同等ではない**」とされており、日本語の精度は公式に明記されていません。本リファレンスのコード例が英語なのはこのガイドに沿ったものです。
> - state（入力本文）が日本語の業務データの場合、instructions / criteria は**日本語版と英語版の両方を評価データセットで比較**し、精度が高い方を採用してください。
> - 評価セットには敬語・省略・曖昧な依頼・社内用語・複数用件を含む日本語実データを使用し、精度・確信度較正・保留率・レイテンシ・コストを計測して判断します。
> - ソース: apidog「How to Get a Jev API Key」/ AIフレンズ / ネクスト技術ブログ（いずれも2026-09-18確認）

### ① `choice`（多肢選択・排他分類）
- **用途**: カテゴリ分類、問い合わせ種別（例: 請求 / 技術 / 営業）、コンテンツモデレーション種別（例: スパム / ヘイト / 規約違反）などの排他分類。
- **TypeScript**:
  ```typescript
  import { choice } from '@typesafe-ai/sdk';

  const questions = {
    inquiry_type: choice('What type of inquiry is this?', {
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
      "inquiry_type": Choice(
          instructions="What type of inquiry is this?",
          criteria={
              "billing": "Payment, invoices, and subscription questions",
              "technical": "API errors, bugs, and integration problems",
              "sales": "Enterprise plans, demo requests, and pricing",
          }
      )
  }
  ```
- **応答形式**: `response.answers.inquiry_type`
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

## 2. 問い（instructions / criteria / state）の設計

Jev の判定精度は、閾値較正より先に**問いの質**で決まります。問いの設計が一次設計であり、閾値選定（§5）はその上に成り立つ二次調整です。

> **⚠️ 位置づけ**: 本節は公式ガイドではなく、一般的な設計原則（ヒューリスティック）です。最終的な良し悪しは必ず評価データセット上の実測（精度・確信度較正・保留率）で判断してください。

### instructions（問い文）の設計原則

- **1プリミティブ1問**: AND/OR を含む複合条件は、どの条件が確率を動かしたか解釈できず閾値較正が困難になるため、論点ごとに question を分割する（例: 「違反かつ緊急か」→ `isViolation` (noul) + `urgency` (score)）。
- **判定可能な文にする**: 「適切か」「良いか」等の曖昧な評価語を避け、観察可能な基準を書く（✕ `Is this response good?` / ○ `Does this response answer the user's question without adding unverified claims?`）。
- **否定形・二重否定を避ける**: `Does not violate...` より `Does ... violate ...?` の肯定形で聞く。
- **要件原文へのトレーサビリティ**: instructions は要件文書の原文フレーズ（Requirement ID 紐付け）から導出し、技術側の独断で判定基準を新設しない。要件にない基準が必要な場合は HITL 確認事項にする。

### criteria（選択肢）の設計原則（choice）

- **MECE（相互排他・網羅）**: 選択肢が重複すると確率が分散し confidence が下がる。境界が曖昧な2択は統合するか、区別のつく基準を書き分ける。
- **脱出選択肢を用意する**: どれにも当てはまらない入力を無理やり分類させないため `none` / `other` を用意し、その業務上の扱い（レビュー送り等）を決めておく。
- **各選択肢に境界の判る説明を書く**: ラベル名だけでなく、定義・典型例・反例を1〜2文で。選択肢間の差が「種類」ではなく「度合い」なら choice ではなく score を検討する。
- **粒度は業務アクションと1対1で**: 分類先がそのまま振り分け先の部署・処理になる粒度にする。Jev に聞くのはアクションが変わる粒度までとし、それより細かい分類が必要なら後段でマージする設計にする。
- **選択肢数は必要最小限に**: 選択肢が増えるほど1選択肢あたりの確率が下がり、確信を持った自動判定が難しくなる。数十カテゴリの大量分類は、大分類→小分類の2段階（階層化）を検討する。

### score（レベル定義）の設計原則

- **各レベルに行動アンカー（観察可能な具体特徴）を書く**: `Medium` だけでなく `Needs response within 24 hours` のように、レベル間の区別が入力から判定可能な定義にする。
- **段階数は3〜5を目安**: 隣接レベルの区別が人間にも付かない段階数は、モデルでも較正が崩れやすい。
- **順序尺度であることを意識**: 返り値の `score` は確率加重の期待値（1.85 等）であり、レベル間の「間隔」に業務的意味を持たせない。分岐に使う閾値は期待値ではなく `probabilities`（各レベルの確率分布）側で設計する（理由は後述）。

#### 期待値 `score` ではなく `probabilities` で分岐する理由

期待値は確率分布を1つの数に潰すため、**同じ期待値でも確信度がまったく異なる分布**があり得ます。3段階（Low=0, Medium=1, Critical=2）で、どちらも期待値 1.0 になる例:

| ケース | probabilities | score（期待値） | 中身 |
| :--- | :--- | :--- | :--- |
| A | `{"0": 0.0, "1": 1.0, "2": 0.0}` | 1.0 | 確実に Medium |
| B | `{"0": 0.5, "1": 0.0, "2": 0.5}` | 1.0 | Low と Critical に半々で分裂（≒不明） |

「`score >= 1.0` でエスカレーション」のような期待値分岐は、ケースB（50%の確率で Critical を見逃す）を素通りさせます。また期待値の計算は「Low→Medium と Medium→Critical の間隔が等しい」ことを暗に仮定しますが、業務インパクトは等間隔とは限りません（Critical の見逃しは Low の誤判定より遥かに重い、等）。

分岐は noul のデュアル閾値と同じ発想で、**アクションを起こすレベルの確率**に閾値を置き、分布が平坦な（不確実な）ケースをレビューに回す設計にしてください:

```typescript
const p = response.answers.urgency.probabilities;
if (p["2"] >= 0.8) return escalate();                     // Critical 確率が高い
if (p["2"] <= 0.1 && p["0"] >= 0.8) return normalQueue(); // 明らかに低緊急
return review();                                          // 分布が平坦・分裂 → レビュー
```

### noul（命題）の設計原則

- **単一命題にする**: 「A かつ B」「A または B」は分割する（instructions の1プリミティブ1問と同じ理由）。
- **Yes の向きを業務意味で統一する**: 「Yes = アクション側（ブロック・エスカレーション等）」に揃えると、閾値の向きの実装ミスを防げる。

### state（判定対象入力）の設計原則

- **判定に必要な情報だけを入れる**: 無関係な長文はトークンコスト増とノイズになる。一方、判定に必要な文脈（直前のやり取り等）を欠くと精度が落ちる。必要十分かどうかは評価セットで確認する。
- **フォーマットを固定する**: 呼出ごとに構造が変わると較正が不安定になるため、前処理でテンプレート化する（例: `Subject: ...\nBody: ...`）。
- **個人情報・機密情報の最小化**: state に含めるデータ項目はセキュリティ・プライバシー審査の対象。マスキング・除外の方針は審査プロセスと整合させる（SKILL.md スコープ境界参照）。
- **長文は切り出す**: 判定対象が長文の場合、関連箇所の抽出やチャンク分割を前処理で行い、全文投入との精度比較を評価セットで行う。

### 問いの反復検証プロセス

- **質問文はハイパーパラメータとして版管理する**: instructions / criteria / state テンプレートの変更履歴をコードと共に管理する。
- **A/B 比較で採用判断**: 言語（英語/日本語）、選択肢の粒度、説明文の有無などの候補は、精度・確信度較正・保留率・レイテンシ・コストを同一評価セットで比較して採用する。
- **変更したら閾値を再較正**: 質問文を変えると確率分布が変わるため、既存の `blockThreshold` / `allowThreshold` は無効とみなし、検証ステータスを `UNVALIDATED` に戻した上で §5 のプロセスで再選定する。

---

## 3. Safe Default（安全側への縮退）

**Safe Default** とは、モデルが安全に判断できないときに採用する、事前定義済みの業務上の縮退動作です。API障害や不確実性を、誤った自動実行に変えないための安全策です。

### 発動条件

- API障害・タイムアウト・Deadline超過
- 不正または検証不能なレスポンス
- 閾値ポリシーが未検証、欠損、または不正
- 確率・confidenceが自動処理の基準を満たさない

### 選定原則

- 誤った自動実行より被害が小さいこと
- 可能な限り可逆で、後から人が確認・修正できること
- 「安全」の意味を技術側だけで決めず、業務リスクと法的要件に基づいて定義すること
- Safe Defaultとその発動条件は、業務側ステークホルダーの承認を得ること

| ユースケース | Safe Default の例 |
| :--- | :--- |
| コンテンツ判定 | 自動許可・自動ブロックせず、人手レビューへ送る |
| 決済・送金 | 実行せず保留し、承認者へ通知する |
| 推薦・パーソナライズ | 推薦を表示せず、一般的なコンテンツを表示する |
| 問い合わせ分類 | 特定部署へ誤配送せず、汎用受付キューへ送る |

Safe Defaultは常に `REVIEW_REQUIRED` とは限りません。業務ごとに「保留」「何もしない」「汎用経路へ送る」など、被害を最小化する動作を選びます。

---

## 4. タイムアウト・リトライ・締め切り制約（Deadline Hierarchy）

プロジェクトのSLOを満たすため、固定値を決め打ちせず、以下のパラメータ関係式に基づいて時間予算（Time Budget）を設計します。

> **📖 用語注**: 「外側絶対Deadline」は本スキル固有の表現で、リトライを含む処理全体にかける壁時計上の絶対締め切りを指します。標準的には gRPC の **deadline**（呼出が超過してはならない絶対時刻。timeout が相対時間であるのに対する概念）や "overall timeout" / "total time budget" に相当します。

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

## 5. 実証的な閾値（Threshold）選定プロセス

固定の経験則（0.95, 0.05等）は**初期仮説に過ぎず、プロダクション投入前に検証が必須**です。

> **📖 用語注**: **較正（キャリブレーション, calibration）** とは、モデルが出力する確率・確信度の値が、実際の正解率とどれだけ一致しているかという性質です。`noul = 0.9`（違反確率90%）と出力したケースを100件集めたとき、実際に約90件が違反なら「較正が取れている」、70件しか違反でなければ「過信（較正が崩れている）」状態です。較正が崩れていると、閾値を守っていても目標FP/FN率を超過します。評価データセット上で予測確率ビン別の実正解率（reliability diagram）や ECE（Expected Calibration Error）で確認してください。本節の実証的閾値選定は、生の確率値の較正ズレを額面通り信じないための安全策でもあります。

1. **評価データセットの準備**:
   - クラス別発生率（Prevalence）、求めるPrecision/Recallの信頼区間、重要な境界ケースのカバレッジを満たすサンプルを用意。
2. **コスト行列（Cost Matrix）と目標値の定義**:
   - 目標: FP率（偽陽性率: 正常を誤って違反と判定する割合） $\le X\%$ (評価セット上、95%信頼上限)
   - 目標: FN率（偽陰性率: 違反を見逃す割合） $\le Y\%$ (評価セット上、95%信頼上限)
   - 状態: `未検証` → `検証済み` へ昇格。
3. **ROC / Precision-Recall 分析**:
   - 閾値を変化させたときの自動化率（Coverage）とエラー率のトレードオフを算出し、`blockThreshold` と `allowThreshold` を確定。
   - **用語と直感**: 自動化率（Coverage）は全リクエストのうち自動確定する割合（TCOモデルの P(auto) に相当）、エラー率は自動判定のうちの誤り割合（FP/FN）。閾値を緩めると自動化率は上がるがエラー率も上がり、絞るとその逆になる。**目標FP/FN率を満たす範囲内で自動化率が最大になる点**を選ぶことは、レビューコストと誤判定コストの経済的最適化に相当する。
4. **本番ドリフト監視とロールバック**:
   - レビュー率（中間帯比率）を常時監視し、質問文やモデル更新時は再評価を実施。
