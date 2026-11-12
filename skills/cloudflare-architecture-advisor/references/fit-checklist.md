# 向かない条件を見る観点

- 確認日: 2026-11-12（各ページが開けることと、下に書いた公式の記述の箇所）

公式の構成図は「こう組める」を示すが、「この条件なら向かない」はあまり書かない。構成案を出すときは、この一覧の問いを三案のそれぞれに当てる。数値はここに持たない。数値が要る問いは、`cloudflare-product-survey` で該当ページを読んで答える。

## 1. 先に決めておく区別

構成の説明で混ぜない。

1. **Worker のグローバル変数を、共有状態の置き場にしない。** 公式は、同じ利用者の要求が同じインスタンスに届く保証が無いので、グローバルの状態を使ったり書き換えたりしないよう勧めている（[How Workers works](https://developers.cloudflare.com/workers/reference/how-workers-works/)）。共有状態の置き場は [ストレージの選び方](https://developers.cloudflare.com/workers/platform/storage-options/) で選ぶ。クライアントをまたぐ調停や、強い整合とトランザクションが要る単位は Durable Object にする（同ページの「Global coordination & stateful serverless」の行、[Rules of Durable Objects](https://developers.cloudflare.com/durable-objects/best-practices/rules-of-durable-objects/) の「Use Durable Objects for stateful coordination, not stateless request handling」）。
2. **Binding と Service Binding は別の概念として扱う。** Binding は Worker から製品の資源につなぐ仕組み全般、Service Binding は Worker から別の Worker を呼ぶ仕組み（[Bindings](https://developers.cloudflare.com/workers/runtime-apis/bindings/)、[Service bindings](https://developers.cloudflare.com/workers/runtime-apis/bindings/service-bindings/)）。
3. **Queue、Workflow、Cron Trigger を「非同期」に畳み込まない。** それぞれ、メッセージの受け渡し、段階を持つ長い処理、時刻での起動、と役割が違う（[Queues](https://developers.cloudflare.com/queues/)、[Workflows](https://developers.cloudflare.com/workflows/)、[Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/)）。

## 2. 案ごとに当てる問い

| 問い | 確かめる公式ページ |
| :--- | :--- |
| 1 回の要求で使う CPU 時間は、選ぶプランの上限に収まるか。待ち時間（I/O の待ち）は数えるか | [Workers の Limits](https://developers.cloudflare.com/workers/platform/limits/)、[Durable Objects の Limits](https://developers.cloudflare.com/durable-objects/platform/limits/) |
| 前提のプラン（Free か Paid か）で、使う製品が提供されているか | 各製品の文書の冒頭と Pricing |
| Durable Object を何の単位で分けるか。1 つの Object に全部の要求を集めていないか | [Rules of Durable Objects](https://developers.cloudflare.com/durable-objects/best-practices/rules-of-durable-objects/) の「Model your Durable Objects around your "atom" of coordination」「Do not use a single Durable Object as a global singleton」 |
| 1 つの Object の処理量と容量の上限に、最も混む単位が当たらないか | 同ページの「Message throughput limits」、Durable Objects の Limits |
| 単位をまたぐ一覧や集計が要るか。要るなら、Object とは別の置き場（D1 など）が要らないか | [ストレージの選び方](https://developers.cloudflare.com/workers/platform/storage-options/) |
| メモリに置いた状態と、保存した状態を区別しているか。予期しない停止で失って困るものをメモリだけに置いていないか | Rules of Durable Objects の「Understand the difference between in-memory state and persistent storage」「Design for unexpected shutdowns」 |
| 長い処理を 1 回の呼び出しに詰めていないか。起動の種類（HTTP、Cron Trigger、Queue の受け手、alarm など）ごとの経過時間の上限に収まるか。区切って保存し、続きを別の呼び出しや Workflows に回せるか | Workers の Limits の「Duration」と「Wall time limits by invocation type」、[Workflows](https://developers.cloudflare.com/workflows/) |
| 互換日付（compatibility date）で固定できる挙動と、日付と関係なく Cloudflare が更新する部分を分けているか | [Compatibility dates](https://developers.cloudflare.com/workers/configuration/compatibility-dates/) |
| 手元の開発環境と本番の差で、試験の結果が変わらないか | [Local development](https://developers.cloudflare.com/workers/local-development/) |
| 新規の静的サイトや画面に、公式は Pages と Workers のどちらを案内しているか。移す場合、機能の差は何か | [Pages](https://developers.cloudflare.com/pages/) の冒頭、[Migrate from Pages](https://developers.cloudflare.com/workers/static-assets/migration-guides/migrate-from-pages/) の Compatibility matrix |
| 使う製品の提供状態（一般提供、ベータ、クローズドベータ）と、地域・拠点の条件は何か | 各製品の文書と [Changelog](https://developers.cloudflare.com/changelog/) |
| 公式の構成図に近い型があるか。あれば、その図との差分は何か | [Reference Architecture Diagrams](https://developers.cloudflare.com/reference-architecture/diagrams/) |

## 3. この一覧を直すとき

- 観点を足すときは、確かめる公式ページを必ず添える。添えられない観点は載せない。
- 特定の案件の経緯が分かる書き方をしない。
- ページの見出しが変わったり URL が転送されたりしたら、直して確認日を更新する。
