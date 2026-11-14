# HTTP の場合

[SKILL.md](../SKILL.md) の手順を、HTTP で画面やデータを返すアプリに当てはめるときに、何を観測するかの具体。どの値が正しいかの正本は、案件の安全の方針と設計の判断。

## 応答だけで観測するもの

| 項目 | 観測するもの | 判定の注意 |
|---|---|---|
| 埋め込みの拒否 | `Content-Security-Policy` の `frame-ancestors`、`X-Frame-Options` | 報告だけの形（`Content-Security-Policy-Report-Only`）の `frame-ancestors` では止まらない。データの窓口にだけあり、画面の文書に無い、という誤りがよくある |
| 内容の種類の推測の抑止 | `X-Content-Type-Options: nosniff` | `Content-Type` 自体が実際の中身と違えば効き目が薄い |
| 読んでよい資源の制限 | `Content-Security-Policy`、`Content-Security-Policy-Report-Only` | 報告だけの形なら、観測だけで止めてはいない |
| 暗号化した通信の強制 | `Strict-Transport-Security` | 暗号化しない手元の環境で無いのは「環境による」 |
| 版や構成を明かす見出し | `Server`、`X-Powered-By` | 消しても他の手がかりで推測できる。穴をふさぐものではない |
| 別の出どころからの呼び出し | 応答の `Access-Control-Allow-Origin` と、資格情報を許す見出し | 全部を許す値と資格情報の許可が同時なら問題。開発用の環境だけなら「環境による」 |
| Cookie の属性 | `Set-Cookie` の `Secure`、`HttpOnly`、`SameSite` | 値は記録に写さない。画面のスクリプトが読む方式の確かめの値の Cookie に `HttpOnly` があれば、ログインが壊れうる |
| 外から読む資源 | 外のサーバーの `script` と `link rel=stylesheet` の `integrity` と `crossorigin` | 接続の準備だけの宣言（`preconnect`、`dns-prefetch`）は対象外。ファイルの先頭の古い版の文字列は、実際の本体の版と突き合わせる |
| 内部の情報の露出 | 本文のスタック、デバッグの画面、一覧の表示 | 本文が本当にスタックか、エラーという単語があるだけかを見る |
| 暗号化しない資源の混在 | 暗号化した画面の中の `http:` の読み込み | — |

## 送ってよい要求

- `GET` と `HEAD` の、普通の利用者と同じ要求だけ。`POST` などの状態を変える要求は送らない。`GET` でも状態を変えうる所在（ログアウト、確定や配信停止のリンク、一度きりの所在）は踏まない。
- 許した数の上限と間隔を守る。応答の `Location` が許した範囲の外なら追わない。
- 要求と応答の記録から、`Cookie`、`Authorization`、`Set-Cookie` の値を消してから残す。
