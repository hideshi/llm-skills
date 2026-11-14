# Playwright

本文の手順（製品の経路で狙った画面に到達する、組み立てた成果物で取る、操作が分かる録画、画面の検証の3層）を、Playwright で行うときの資料。

- 確かめた版: Playwright 1.65.0（`@playwright/test`）、Chrome Headless Shell 158.0.8127.18、Node 22.23、Linux
- 確かめた日: 2026-11-13
- 【実行】は小さな画面を実際に動かして確かめたこと、【資料】は公式の資料か、配布物に入っている型の定義で読んだだけのこと

## 入れ方

- 【実行】`npm install -D @playwright/test` の後に、`npx playwright install chromium` でブラウザを入れる。ブラウザはプロジェクトの外（利用者のキャッシュ）に置かれる。
- 【資料】OS のライブラリが足りないときは `npx playwright install --with-deps chromium`。OS の包みを入れるので、管理者の権限が要る。

## 組み立てた成果物で動かす

- 試験の実行器の `webServer` の `command` に、配る形に組み立てて配信するコマンド（組み立ててからプレビューで配信する、など）を書く。開発用の配信を書かない。
- **`reuseExistingServer: true` だと、同じポートで動いているサーバーをそのまま使い、`command` を走らせない**（【実行】）。試したときは、組み立てた版ではなく、先に立てておいた別のサーバーの画面が返り、試験はそのまま通った。公式の例の `reuseExistingServer: !process.env.CI` も、手元では使い回す。証拠を取るときは `false` にするか（【資料】既にサーバーが動いていれば誤りで止まる）、開いた画面で版の印（組み立ての番号など）を確かめて記録に書く。

## 隔離と外への送信

- 試験用の利用者と、試験用のデータで動かす。本番の資格情報を使わない。ログインの状態を保存したファイルは秘密として扱い、版管理に入れない。
- 試験の配信先以外への要求を止めて、止めた要求を記録する（【実行】）。

```js
const blocked = []
await context.route(
  (url) => !url.href.startsWith('http://127.0.0.1:4123'),
  (route) => { blocked.push(route.request().url()); return route.abort() },
)
// 終わったら blocked を検証の記録に書く。分析の送信などが、ここに出る
```

- 【資料】Service Worker が要求を受け持つと、`route` から見えない。文脈の `serviceWorkers: 'block'` で止める。

## 画面の写し

- 狙った状態を表明で待ってから撮る（`await expect(page.getByText('受け付けました')).toBeVisible()` など）。一定時間の待機で代用しない。
- **日本語のフォントが無い環境では、日本語が豆腐（□）になる。フォントが一つも無いと、文字が消えて空の画面になる。どちらも撮影は成功で終わる**（【実行】）。撮った画像を開いて、文字が読めるかを見る。コンテナや CI で撮るなら、日本語のフォントを入れる。
- 【資料】`fullPage: true` で縦に長い画面を1枚に撮る。`animations: 'disabled'` と `caret: 'hide'` で、動きとカーソルの点滅を止める。
- 【資料】`mask` に指定した要素は、既定でピンクの箱で塗りつぶされる。見えない要素にも掛かる。伏せた行だけの表は、本文の決まりどおり中身が空の画面と同じ扱いになるので、伏せていない実際の行が映るかを確かめる。

## 録画

| 確かめること | 結果（【実行】） |
|---|---|
| 録画の大きさの既定 | 画面を 1280×720 にして大きさを指定しないと、録画は 800×450 に縮んだ。文字が読めなくなる。`recordVideo.size`（実行器では `video: { mode: 'on', size }`）を画面の大きさと同じにする |
| ファイルができる時 | `page.video().path()` で場所は先に分かるが、文脈（context）を閉じるまで中身は0バイト。閉じる前にハッシュを取ったり、組み立てに渡したりしない |
| 形式 | VP9 の webm、25 fps |

- 【資料】実行器の `video` の `'retain-on-failure'` などは、失敗した回の録画だけを残す。受入の証拠には、成功した回を `'on'` で撮る。
- 見せるために止めるのは `page.waitForTimeout` でよいが、条件がそろうのを待つのには使わない。止める前に、表明で読める状態を待つ。

### 操作を見せる

録画の側で、操作した位置と要素を重ねて見せられる（【実行】`recordVideo.showActions`、実行器では `video.show.actions`）。製品のコードは変えないので、本文の原則に合う。

```js
const context = await browser.newContext({
  viewport: { width: 1280, height: 720 },
  recordVideo: {
    dir: 'videos',
    size: { width: 1280, height: 720 },
    showActions: {
      duration: 1500,
      style: { title: 'display:none', highlight: 'outline: 3px solid red' },
    },
  },
})
```

- **操作の題は、既定で `Click getByTestId('confirm')` のような選び方の文字列を出す**（【実行】）。内部の識別子なので、業務の言葉の字幕にならない。`style.title` に `display:none` を書くと消えた。字幕は別に付ける。
- **重ねた装飾は、その時に撮った画面の写しにも写る**（【実行】）。写しや基準の画像の前に `await page.screencast.hideActions()` を呼ぶと消えた。
- 【資料】`page.screencast.showChapter(題)` で、場面の見出しを画面の中央に重ねられる。見出しが製品の要素を隠していないかは、完成した動画で見る。

## 画面の検証の3層

### 自動の表明

コンソールの誤りと、壊れた画像を数えて、0件を表明する（【実行】）。

```js
const errors = []
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()) })
page.on('pageerror', (e) => errors.push(String(e)))
// 画面を操作した後で
const broken = await page.$$eval('img', (imgs) =>
  imgs.filter((i) => i.complete && i.naturalWidth === 0).map((i) => i.getAttribute('src')))
expect(errors).toEqual([])
expect(broken).toEqual([])
```

- 【実行】読み込みに失敗した画像や、止めた要求も、コンソールの誤り（`Failed to load resource`）として出る。止めた要求を誤りから外すなら、外した理由を記録に書く。

### 基準の画像との比較

- **基準が無い初回は失敗し、そのときの画面を基準として書き出す**（【実行】`A snapshot doesn't exist at …, writing actual.`）。書き出された基準を開いて、正しい画面かを確かめてから版管理に入れる。
- 【実行】基準の名前に環境が入る（試した設定では `confirm-linux.png`。【資料】プロジェクトを分けた設定では、その名前も入る）。別の OS やブラウザで撮った基準とは比べられない。
- 【資料】`-u`（`--update-snapshots`）は、値を付けないと `changed` で、違った基準を全部書き換える。意図した変更のときだけ使い、基準の差分をレビューに回す。

### 走った件数

- 【実行】`-g` の名前が何にも当たらないと、`Error: No tests found` で終了コード1になる。`--pass-with-no-tests` を付けると0になる。この旗で、試験が無いことを隠さない。

## 公式の資料

- [録画](https://playwright.dev/docs/videos)
- [画面の写し](https://playwright.dev/docs/screenshots)
- [基準の画像との比較](https://playwright.dev/docs/test-snapshots)
- [試験の前に配信を立てる（webServer）](https://playwright.dev/docs/test-webserver)
- [録画への重ね書き（Screencast）](https://playwright.dev/docs/api/class-screencast)
- [通信の差し替えと Service Worker](https://playwright.dev/docs/network)
- [実行器の設定（use）](https://playwright.dev/docs/test-use-options)
