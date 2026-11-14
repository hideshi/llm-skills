# Vitest

本文の手順（テストする境界、正しい理由で落ちたかの確かめ、失敗を隠さない）を、Vitest で行うときの資料。Vite を使うフロントエンド（Vue など）を想定する。

- 確かめた版: Vitest 5.1.0、Node 22.23
- 確かめた日: 2026-11-12
- 【実行】は小さな試験を実際に動かして確かめたこと、【資料】は公式の資料で読んだだけのこと

## 入れ方と前提

- 【資料】Vitest 5 は Vite 6.4 以上と Node 22.12 以上が要る。アプリと同じ `vite.config` を読むので、別名（`@/` など）や変換の設定を二重に持たない。
- 【資料】大域の `describe`・`test`・`expect` は既定では無い。`vitest` から読み込むか、設定の `globals` を有効にする。Jest から移るときの違いは、公式の移行の手引きを見る。

## 表を元にした一括のテスト

テストケース表の行を、そのまま表にして回す（【実行】）。

```js
import { describe, test, expect } from 'vitest'
import { total } from './price.js'

describe('total', () => {
  // 表の識別子を名前の先頭に入れると、結果と表を突き合わせやすい
  test.each([
    ['TC-01 空', [], 0],
    ['TC-02 二件', [1, 2], 3],
    ['TC-03 値引きの境界', [10000], 9000],
  ])('%s', (_id, input, want) => {
    expect(total(input)).toBe(want)
  })
})
```

- `test.each` は行の配列を引数に展開する。`test.for` は展開せず、行をそのまま1つ目の引数に渡し、2つ目に試験の文脈を渡す（【実行】）。
- 【資料】画面の部品の試験では、環境を `jsdom` か `happy-dom` にする（既定は `node`）。本物のブラウザで確かめるなら、ブラウザで動かす方式がある。

## 正しい理由で落ちたかを確かめる

| 確かめること | コマンド（【実行】） |
|---|---|
| 一回だけ流す（見張りの状態にしない） | `npx vitest run` |
| 件数 | 終わりの `Tests  1 failed \| 3 passed \| 1 skipped (5)` の行。機械で読むなら `npx vitest run --reporter=json --outputFile=r.json` の `numTotalTests`・`numPassedTests`・`numFailedTests`・`numPendingTests` |
| 試験の名前の一覧（表の行まで） | `npx vitest list --no-static-parse`。`each` と `for` の行が1件ずつ展開される |
| 狙った理由で落ちたか | 失敗の場所（ファイルと行）と、期待した値と得た値の差を読む。読み込みの誤りや準備の失敗で落ちたのは、RED と数えない |

## 落とし穴

- **`-t` の名前を打ち間違えると、全部が skip されて成功する**（【実行】）。`npx vitest run -t 'nothing-matches'` は `Tests  5 skipped (5)` を出して終了コード0で終わる。RED や GREEN を確かめるときは、件数の行で、走った件数が書いた件数と合うかを見る。
- **`vitest list` は、既定では `each` と `for` を展開しない**（【実行】）。5 からはファイルを読むだけで数えるので、`total > %s` のように型紙の名前が1件だけ出る。表の行の件数と比べるときは `--no-static-parse` を付ける。
- **試験のファイルが見つからないと、終了コード1**（【実行】）。ただし `--passWithNoTests` を付けると0になる。この旗を、試験が無いことを隠すために使わない。
- `test.skip`・`test.todo`・`.only` を残さない。`.only` が残ると、ほかの試験が黙って走らなくなる。件数の行で確かめる。
- 【資料】モジュールの差し替え（`vi.mock`）はファイルの先頭に持ち上げられる。5 からは関数やブロックの中で呼ぶと誤りになる。
- 時刻や乱数は `vi.useFakeTimers` などで固定する。試験が終わったら元に戻す。

## 公式の資料

- [Vitest の手引き](https://vitest.dev/guide/)
- [コマンドの旗（CLI）](https://vitest.dev/guide/cli)
- [test の API（each と for）](https://vitest.dev/api/test)
- [Jest からの移行](https://vitest.dev/guide/migration/jest)
