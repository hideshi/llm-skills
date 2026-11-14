# Alloy

本文の手順を、Alloy Analyzer（Alloy 6）で行うときの資料。

- 確かめた版: Alloy 6.2.0（`org.alloytools.alloy.dist.jar`）、Java 21 の上で
- 確かめた日: 2026-11-12
- 【実行】は小さなモデルを実際に動かして確かめたこと、【資料】は公式の資料で読んだだけのこと

## 入れ方

- 【資料】Java 17 以上が要る。[GitHub のリリース](https://github.com/AlloyTools/org.alloytools.alloy/releases)から `org.alloytools.alloy.dist.jar` を取る（OS ごとの入れ物もある）。
- 【資料】6.2.0 で、画面を使わないコマンドの使い方が加わった。

## 動かし方（【実行】）

| したいこと | コマンド |
|---|---|
| 版を確かめる | `java -jar org.alloytools.alloy.dist.jar version` |
| モデルの中のコマンドを並べる | `java -jar org.alloytools.alloy.dist.jar commands model.als` |
| 全部のコマンドを流し、結果をフォルダに書く | `java -jar org.alloytools.alloy.dist.jar exec -q -f -c '*' -t json model.als` |
| 1つだけ流す（番号か名前） | `exec -c 2 ...` または `exec -c Neg ...` |
| 解き手を変える | `exec -s minisat ...`（一覧は `solvers`。既定は SAT4J） |

- `exec` は、モデルと同じ名前のフォルダ（例: `model/`）に `receipt.json` と、見つかった解ごとの `<コマンド名>-solution-0.json` を書く。中身があるフォルダに書くには `-f` が要る。
- `-o -` で解を標準出力に出せる。ただし、解が無いときは何も出ない。結果の判断には `receipt.json` を使う。
- 使える旗の一覧は `java -jar org.alloytools.alloy.dist.jar help exec`。

範囲の書き方の例（【実行】）:

```text
run show { some Account } for 3 but 4 Int, 3 steps
check NoOverdraft for 3 but 4 Int, 5 steps
```

- `for 3` は各集合を最大3個まで、`but 4 Int` は整数のビット幅を4（-8〜7）にする、`5 steps` は時間の長さを5までにする。
- 【資料】`steps` を書かない、時間を含むモデルは、既定で10ステップまで。上限なしの `1.. steps` は、外の検査器（NuSMV か nuXmv）を入れて PATH に置く必要がある。

## 結果の読み方

本文の「書いた／構文が通った／検査を実行した／性質が成り立った」の区別は、次で判断する。

| 区別 | 見る所（【実行】、6.2.0） |
|---|---|
| 構文や名前の誤り | 終了コード1。`Syntax error in <ファイル> at line L column C:` に続けて理由（`The name "B" cannot be found.` など） |
| `run` で例が見つかった | `receipt.json` のそのコマンドに `"solution"` がある。解のファイルができる |
| `run` で例が見つからない | `"solution"` が無い。述語が矛盾しているか、範囲が小さすぎる |
| `check` で反例が見つかった | `"solution"` がある。解のファイルが反例 |
| `check` で範囲の中に反例なし | `"solution"` が無い |

- 構文が通れば、例や反例の有無にかかわらず終了コードは0。終了コードで性質の成否を判断しない。
- `check` で反例が無いことは、書いた範囲（個数、整数の幅、ステップ数）の中でだけ言える。報告には、`receipt.json` の `source`（範囲を含むコマンドの文）を添える。

## 落とし穴

- **`run` で例が見つからないのは、良い知らせとは限らない**。事実（`fact`）が強すぎて、どんな状態も許さないことがある。その場合、どの `check` も反例なしになる。性質を検査する前に、`run` で例が作れること（モデルが空でないこと）を確かめる。本文の「初期状態が存在するか」の確認に当たる。
- **整数の幅で、桁あふれが起きる**。既定の幅は小さいので、金額のような数は `but N Int` で幅を広げるか、`-n`（桁あふれした解を除く）を使う。幅を変えて結果が変わらないかを見る。
- **時間を含むモデルでは、事実は最初の状態にしか効かない**（【資料】）。すべての時点で成り立たせたいなら `always` を付ける。
- **範囲を小さくしすぎると、反例が出ない**。範囲を変えて2回以上流し、結果が変わらないかを見る。
- 構文の警告（`== is redundant` など）は終了コードに出ない。出力を読んで、意図した式かを確かめる。

## 公式の資料

- [AlloyTools/org.alloytools.alloy（README とリリース）](https://github.com/AlloyTools/org.alloytools.alloy)
- [Alloy のコマンドと範囲（alloy.readthedocs.io）](https://alloy.readthedocs.io/en/latest/language/commands.html)
- [Alloy の時間の書き方](https://alloy.readthedocs.io/en/latest/language/time.html)
- [ダウンロードと、時間を含むモデルの検査器](https://alloytools.org/download.html)
