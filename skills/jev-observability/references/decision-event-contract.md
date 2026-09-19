# 判定イベント契約ガイド（Jev）

1 回の Jev 判定（または判定＋コード分岐の完了）を 1 イベントとして残すときの推奨フィールド。**値の例示にプロジェクト固有の本番数値を焼かない。**

## 必須（推奨）

| フィールド | 意味 |
| :--- | :--- |
| `requirementId` | 業務判断の ID（行番号禁止） |
| `primitive` | `choice` / `score` / `noul` |
| `modelId` | 使用モデル（入力または実行時） |
| `thresholdVersion` または閾値参照 | 適用したポリシー版 |
| `validationStatus` | 実行時に有効だったゲート状態 |
| `route` | `auto` / `review` / `fallback` / `safe_default` 等（プロジェクト語彙に合わせる） |
| `latencyMs` | 呼出〜決定までの時間 |
| `outcome` | 成功 / 失敗 / タイムアウト / 例外 |
| `timestamp` | イベント時刻（TZ 方針はプロジェクト入力） |

## プリミティブ依存（該当時）

| フィールド | 意味 |
| :--- | :--- |
| `choice` / `probabilities` / `confidence` | choice |
| `score` / `probabilities` / `confidence` | score |
| `noul` | noul の確率 |

## 任意・要審査

| フィールド | 注意 |
| :--- | :--- |
| 入力本文・チケット全文 | デフォルト禁止。残すならマスキングと審査 |
| ユーザー ID・顧客 ID | 最小化。ハッシュ化方針は入力 |
| デバッグ用 raw レスポンス | 保持期間を短く |

## やらないこと

- イベントをプロンプト全文のダンプ置き場にしない
- 「とりあえず全部残す」を既定にしない
