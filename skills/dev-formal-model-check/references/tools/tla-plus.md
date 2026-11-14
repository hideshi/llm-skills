# TLA+（TLC）

本文の手順を、TLA+ のモデル検査器 TLC で行うときの資料。

- 確かめた版: tla2tools.jar v1.7.4（GitHub の最新の安定版。v1.8.0 は試験版）、Java 21 の上で
- 確かめた日: 2026-11-12
- 【実行】は小さな仕様を実際に動かして確かめたこと、【資料】は公式の資料で読んだだけのこと

## 入れ方

- 【資料】Java 11 以上が要る。[GitHub のリリース](https://github.com/tlaplus/tlaplus/releases)から `tla2tools.jar` を取る。リリースの説明にある sha1 と照らす（v1.7.4 は `bee4a54f3ee3d4afc347c3240ec2d9e93b075104`）。
- 【資料】v1.8.0 の説明では、TLA+ Toolbox（専用の画面）は保守されておらず、VS Code の拡張か、コマンドで使うことを勧めている。

## 動かし方

| したいこと | コマンド |
|---|---|
| 構文と意味を確かめる | `java -cp tla2tools.jar tla2sany.SANY Spec.tla` |
| 設定ファイルを指定してモデル検査する | `java -cp tla2tools.jar tlc2.TLC -workers auto -config Spec.cfg Spec.tla` |
| デッドロックを検査しない | 設定ファイルに `CHECK_DEADLOCK FALSE`、またはコマンドに `-deadlock` |
| 乱択で深く探る（網羅しない） | `-simulate`（`-depth` で深さ、`-seed` で種） |
| 反例の経路を書き出す | `-dumpTrace json ファイル名` |

- 【実行】`-workers` の既定は1。`auto` で CPU の数に合わせる。
- 【実行】`-config` を省くと、仕様と同じ名前の `.cfg` を読む。
- 【資料】使える旗の一覧は `java -cp tla2tools.jar tlc2.TLC -help` が最も新しい。

設定ファイルの例（【実行】）:

```text
SPECIFICATION Spec
INVARIANT TypeOK
PROPERTY Reaches
CHECK_DEADLOCK FALSE
```

`CONSTANT` で定数に値を入れる。集合を有限にしないと、状態が尽きずに検査が終わらない。

## 結果の読み方

本文の「書いた／構文が通った／検査を実行した／性質が成り立った」の区別は、次で判断する。

| 区別 | 出力（【実行】、v1.7.4） | 終了コード |
|---|---|---|
| 構文の誤り | SANY: `***Parse Error***`。TLC: `Error: Parsing or semantic analysis failed.` | SANY 255、TLC 150 |
| 意味の誤り（未定義の名前など） | SANY: `Semantic errors:` に続けて場所と `Unknown operator` など。TLC: 上と同じ | **SANY 0**、TLC 150 |
| 設定の誤り（無い不変条件の名前など） | `Error: The invariant X specified in the configuration file is not defined in the specification.` | 151 |
| 不変条件の違反 | `Error: Invariant X is violated.` と、`State 1:` から始まる経路 | 12 |
| デッドロック | `Error: Deadlock reached.` と経路 | 11 |
| 時間の性質の違反 | `Error: Temporal properties were violated.` と反例の経路 | 13 |
| 範囲の中で違反なし | `Model checking completed. No error has been found.` | 0 |

- 範囲は `N states generated, M distinct states found, 0 states left on queue.` と `The depth of the complete state graph search is D.` に出る。「違反なし」を報告するときは、この2行と設定（定数の値）を添え、範囲の中の結果だと書く。
- `states left on queue` が0でないまま止まったときは、探索が終わっていない。違反なしとは言わない。

## 落とし穴

- **SANY の意味の誤りは終了コード0**（【実行】、v1.7.4）。SANY だけで構文を確かめるときは、終了コードでなく出力の `Semantic errors` を見る。TLC で動かせば、意味の誤りも 150 になる。
- **公平性を書かないと、「いつか起きる」は必ず破れる**（【実行】）。`Spec == Init /\ [][Next]_x` だけでは、ずっと何もしない（`Stuttering`）振る舞いが許されるので、`<>(x = 3)` のような性質は違反になる。`WF_x(Next)` などの公平性を足すと成り立った。反例の最後が `Stuttering` なら、まず公平性の書き漏れを疑う。ただし、公平性を足すことは「その動きがいつか必ず起きる」という仮定を置くことなので、実装で成り立つ根拠を書く。
- **デッドロックの検査を切るときは理由を書く**。終わりの状態がある仕様では、デッドロックの報告は正しい終わりのことがある。切ると、本当の行き詰まりも見逃す。
- **定数を小さくしすぎると、反例が出ない**。範囲を変えて2回以上流し、結果が範囲で変わらないかを見る。
- 【資料】TLC は状態を指紋（ハッシュ）で区別するので、ごく小さな確率で状態を取りこぼす。完了時に出る見積もり（`calculated (optimistic)`）を、必要なら記録に添える。

## 公式の資料

- [tlaplus/tlaplus（README とリリース）](https://github.com/tlaplus/tlaplus)
- [TLC の始め方（docs.tlapl.us）](https://docs.tlapl.us/using:tlc:start)
- [Learn TLA+ のコマンドの使い方](https://learntla.com/topics/cli.html)
