# 仕様の追従

MCPの仕様は、版の間で仕組みが入れ替わる（2026-07-28 の版では、プロトコルのセッションと初期化の手順が無くなり、サーバーからクライアントへの要求は MRTR に置き換わった）。このスキルの不変条件は仕組みに依存しない言い方で書いてあるが、各不変条件をどの仕組みで守るかは版ごとに違う。使う前に、この資料の手順で確かめる。

## 確かめた版

| 項目 | 内容 |
|---|---|
| 確かめた版 | 2026-07-28（[Versioning](https://modelcontextprotocol.io/specification/versioning) で現行と表示） |
| 確かめた日 | 2026-11-11（同日、下の表の規定を各ページの原文の文と1つずつ照合し直した） |
| 前の版 | 2025-11-25 |
| 対象外 | 拡張の版（tasks 拡張の版番号は未確認） |

## 各節のURL（2026-07-28）

| 節 | URL | このスキルで使う所 |
|---|---|---|
| 版の一覧 | https://modelcontextprotocol.io/specification/versioning | 現行の版の確認 |
| 変更履歴 | https://modelcontextprotocol.io/specification/2026-07-28/changelog | Major changes と Deprecated |
| 非推奨の一覧 | https://modelcontextprotocol.io/specification/2026-07-28/deprecated | 撤去の時期 |
| ツール | https://modelcontextprotocol.io/specification/2026-07-28/server/tools | INV-1, 3, 4, 15 |
| 確認（elicitation） | https://modelcontextprotocol.io/specification/2026-07-28/client/elicitation | INV-8, 11 |
| MRTR | https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr | INV-8, 9 |
| 認可 | https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization | INV-6, 7 |
| クライアントの登録 | https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/client-registration | INV-7（登録の方式は持たない範囲） |
| 認可の安全上の注意 | https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/security-considerations | INV-6 |
| セキュリティの実践 | https://modelcontextprotocol.io/specification/2026-07-28/basic/security_best_practices | INV-6, 9 |
| Streamable HTTP | https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http | 実装 |
| tasks 拡張 | https://modelcontextprotocol.io/extensions/tasks/overview | 長時間の処理を持つ場合だけ |

## 2026-07-28 で確かめた要点

不変条件と仕組みの対応。引用は確かめた日の原文の要約で、強さの語は原文のまま。

| 不変条件 | この版での仕組みと規定 |
|---|---|
| INV-1 | クライアントは、信頼できるサーバーのものでない限り、ツールの注釈を信頼できないものとして扱う（MUST）。注釈で守りを作らない根拠 |
| INV-3 | `tools/list` は、要求したクライアントに今使えるツールを返す（MUST）。認可に応じた絞り込みは MAY。存在しないツールの呼び出しは JSON-RPC のエラーで返す。ページの例のコードは `-32602`（例であり、値を定める規定の文は見つからなかった）。「存在しないツールと同じ応答」は、この版でサーバーが実際に返す値と、同じ値・同じ文言にそろえる |
| INV-6 | 無効・期限切れのトークンに401（MUST）。実行時のスコープ不足に403と `error="insufficient_scope"`（SHOULD。ただし同じページの表では「適切な状態コードを返す MUST」の下に403がある）。サーバーは自分を宛先として発行されたトークンだけを受け付ける（MUST）、ほかのトークンを受け付けず中継しない（MUST NOT）。Protected Resource Metadata（RFC 9728）を実装する（MUST）。具体的なスコープ名は定めていない |
| INV-8 | クライアントは、確認に対応するなら、要求ごとに `_meta` の `io.modelcontextprotocol/clientCapabilities` に `elicitation` を宣言する（MUST）。空の `elicitation: {}` は form モードだけの対応として扱う。サーバーからの確認は、`tools/call` の結果に `resultType: "input_required"` と `inputRequests` を返し、クライアントが `inputResponses` と `requestState` を付けて同じ要求を送り直す（MRTR）。応答は `accept`・`decline`・`cancel`。サーバーは、クライアントが宣言していない種類の入力の要求を `inputRequests` に入れない（MUST NOT） |
| INV-9 | `requestState` は攻撃者が操作できる入力として扱う（MUST）。認可や業務の判断に影響するなら完全性を守る（MUST。例として HMAC か AEAD）。主体・短い期限・元の要求の識別子（メソッドと引数のダイジェスト）を入れて検証する（SHOULD）。これらだけでは1回だけの使用は保証されず、1回だけ使う必要があるサーバーはサーバー側で強制する（MUST）。なお、セキュリティの実践の「状態のハンドルを持つことを認証として扱わない（MUST NOT）」は、ツールの引数で渡すハンドルについての規定で、確認の状態に当てはめるのはこのスキルの設計 |
| INV-11 | form モードでパスワード、APIキー、アクセストークン、支払いの資格情報などを求めない（MUST NOT）。そうした情報には url モードを使う（MUST）。このスキルは、どのモードでも確認の中で秘密情報を求めない（設計） |
| INV-15 | サーバーはツールの呼び出しの回数を制限する（MUST、ツールの安全上の注意）。単位（アカウント×クライアント）は設計 |

そのほかの変更で、実装に響くもの: すべての結果に `resultType` が必須になった。この版だけに対応するサーバーは、旧版のクライアントから届いた `Mcp-Session-Id` を無視し、セッションIDを発行も返しもしない（SHOULD、Streamable HTTP の節）。ヘッダーと本文の食い違いなどのエラーコードが付け直された（例: `MissingRequiredClientCapability` は `-32021`）。動的クライアント登録（DCR）は非推奨になり、Client ID Metadata Documents（CIMD）へ移る。

## 使う前の確認手順

1. [Versioning](https://modelcontextprotocol.io/specification/versioning) で現行の版を見る。上の「確かめた版」と同じなら、手順4だけを行う。
2. 違えば、その版の changelog の Major changes と Deprecated を読む。セッション、確認の仕組み、能力の宣言、エラーコード、認可、ツールの一覧に関わる項目に印を付ける。
3. elicitation、authorization（クライアントの登録を含む）、MRTR（または後継の仕組み）、security_best_practices、tools の節を読み直し、上の対応表を新しい版で書き直す。不変条件そのものを変える必要があれば、新しいIDを末尾に足すか、欠番にする。
4. 対象のクライアントが宣言する版と能力を実測で確かめる（どの版で接続し、確認に対応するか）。仕様の版と、実際のクライアントの対応は別に記録する。
5. 成果物に、使った版、確かめた日、読み直した節を書く。

## 確かめていないこと（2026-11-11）

- tasks 拡張の仕様本体（拡張のリポジトリ）と、その版。長時間の処理で確認を求める経路（`tasks/update` で入力を返す）は、MRTR とは別の経路なので、使うときは INV-8〜10 の守りが同じく効くかを確かめる。
- 存在しないツールに返すエラーコードを定める規定の文（例の値 `-32602` だけを確かめた）。
- 401 の `WWW-Authenticate` に `resource_metadata` を入れることを求める規定の強さ（例と流れの図にあり、403 の節には「401 の応答とそろえるため」として `resource_metadata` を入れる記述があるが、401 に入れることを求める規定の文は見つからなかった）。
- セキュリティの実践の文書は、仕様の下（上の表のURL）と、docs の下（`/docs/2026-07-28/tutorials/security/security_best_practices`）の両方で見つかった。どちらが正本かは確かめていない。
- 特定のクライアントでの表示（確認の文の折りたたみなど）。クライアントごとに実測する。
