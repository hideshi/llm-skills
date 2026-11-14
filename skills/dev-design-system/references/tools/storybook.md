# Storybook

本文の手順（カタログは仕様の実演で、正本は仕様。仕様の状態ごとにカタログの表示があるかを照らす）を、Storybook で行うときの資料。story や試験のコードを書くのは実装の仕事で、ここでは照らし方だけを書く。

- 確かめた版: Storybook 10.6.7（`storybook`、`@storybook/html-vite`）、Node 22.23、Chromium 150、Linux。`@storybook/addon-a11y` も入れて組み立てたが、点検そのものは流していない
- 確かめた日: 2026-11-14
- 【実行】は小さなカタログを実際に組み立てて確かめたこと、【資料】は公式の資料で読んだだけのこと
- 公式の資料: https://storybook.js.org/docs/writing-stories 、https://storybook.js.org/docs/writing-tests/accessibility-testing 、https://storybook.js.org/docs/writing-tests/visual-testing
- 同じ版の資料が、この群のほかの単位にもある（試験の件数の数え方、受入の証拠）。版を上げるときは、片方だけを直さない。

## 仕様と story の対応

- 【資料】story は「ある引数を与えたときの部品の描かれた状態」を表す。仕様の状態1つに、story を1つ対応させるのが照らしやすい（例: 既定、無効、読み込み中、エラー）。
- 【実行】組み立てた後の `index.json` に、story の識別子（`parts-button--disabled` のような形）と札（`play-fn` など）が並ぶ。照らすときは、仕様の部品の状態の一覧と、この一覧を突き合わせる。

```sh
NODE_OPTIONS=--max-old-space-size=1024 timeout 400 npx storybook build --quiet -o storybook-static
python3 -c "import json;print(list(json.load(open('storybook-static/index.json'))['entries']))"
```

- 仕様に無い状態の story があれば、仕様に足すか story を消すかを決める（カタログを正本にしない）。

## テーマ

- テーマ（明るい、暗い）が要る案件では、テーマごとに同じ story を表示して確かめる（この資料の勧め。テーマの切り替えの作り方は公式の資料で確かめる）。

## アクセシビリティの点検の設定

- 【資料】点検は axe-core による。`parameters.a11y.test` は `'off'`、`'todo'`、`'error'` のどれか。**`'todo'` は画面に警告を出すだけで、CI では落ちない**（資料は、CI にはアクセシビリティの誤りも警告も出力も出ないと書いている）。CI で落としたいなら `'error'` にする。
- 【資料】自動の点検で見つかるのは、基準の一部だけ。キーボードの一巡と読み上げの確かめは、人の手順として残す。

## 見た目の比較

- 【資料】公式の見た目の比較は、外部のサービス（Chromatic）に story を送って写しを取る。画面の写しが外へ出るので、人の承認が要る選択肢にする。承認が無ければ、手元で写しを取って比べる形（受入の証拠の資料を見る）にする。

## 隔離

- 【実行】組み立ては一時の場所で、Node のメモリ上限（`NODE_OPTIONS=--max-old-space-size=1024`）と時間の上限（`timeout`）を付けて流した。組み立てた物は、`127.0.0.1` だけで待ち受ける配信で開いた。
- 開いている間のブラウザの通信を記録し、許した宛先（手元の配信）以外への要求が無いことを確かめる。試験の道具で開くなら、許した宛先以外を止めて、止めた要求を残す。Playwright なら次の形（宛先とポートは手元の配信に合わせる）。

```js
const blocked = []
await context.route((url) => !url.href.startsWith('http://127.0.0.1:6006'),
  (route) => { blocked.push(route.request().url()); return route.abort() })
// 終わったら blocked を検証の記録に書く。空でなければ、送ろうとした所を調べる
```
- 【資料】`core.disableTelemetry: true` で利用の統計を送らない。これは Storybook 自身の送信だけで、story の中の通信は止めない。
- story に本番のデータや資格情報を入れない。データは作り物にする。
