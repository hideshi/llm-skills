# FreeCAD

[SKILL.md](../../SKILL.md) の決まりを、FreeCAD の Python スクリプトで守るための資料。雛形は [freecad_build.py](../../templates/freecad_build.py)。

- 確かめた版: FreeCAD 1.0.0（Linux の配布のパッケージ、`freecadcmd` と `freecad`）。
- 確かめた日: 2026-11-14。
- 公式の資料: https://wiki.freecad.org/ （この資料の項目と照合はしていない。下の【実行】は手元で流して確かめたこと）。
- 印: 【実行】は手元の 1.0.0 で流して確かめた。印の無い項は、作り方の勧め。

## 流し方

- `freecadcmd <スクリプト>` で、画面を出さずに流す。
- `freecadcmd` で流すと、`__name__` が `"__main__"` にならない【実行】（雛形の末尾は、引数に自分のパスがあるかで見分けて `main()` を呼ぶ）。
- **例外で止まっても、`freecadcmd` の終わりの値は 0 になる**【実行】。検査の失敗を例外で投げるだけでは、命令の終わりの値で落ちたと分からない。雛形のように例外を拾って `sys.exit(1)` で終える。
- `sys.exit` の前に出力を流しておかないと、`print` の表示が失われる【実行】。`print(..., flush=True)` か `sys.stdout.flush()` を使う。
- 画面の中（マクロ）で流すときは `App.GuiUp` が真になる。`freecadcmd` では偽【実行】。

## パラメータの持ち方

- スクリプトの頭の辞書（`PARAMS`）を正本にする。
- GUI で値を見られるように、`Spreadsheet::Sheet` に写す。行に別名（`setAlias`）を付けると、ほかの物の式（`setExpression("Length", "Params.w")`）から参照でき、表の値を変えて再計算すると形が追随する【実行】。
- 正本は一つにする。辞書から形を作るなら、表は見るための写しとし、表を直してもスクリプトには戻らないと README に書く。表を正本にして形を式で動かすなら、辞書は表を作るためだけに使い、値を二か所で持たない。

## 作った後の検査

- 形状（`Part.Shape`）: `isNull()`、`isValid()`、`len(Solids) == 1`、`Solids[0].isClosed()`【実行】。
- 二つの形を一つにまとめた複合（`makeCompound`）は、ソリッドが2個と数えられる【実行】。離れた形が残っていないかは、ソリッドの個数で分かる。
- メッシュ: `MeshPart.meshFromShape(Shape=..., LinearDeflection=..., AngularDeflection=..., Relative=False)` で作り、`isSolid()`、`hasNonManifolds()`、`hasSelfIntersections()` を見る【実行】。自己交差も、求めるなら判定に入れる（値を出すだけで落とさない書き方にしない）。
- 外形: `shape.BoundBox` の `XLength`・`YLength`・`ZLength`・`ZMin`。

## 書き出し

- `.FCStd`: `doc.saveAs(path)`。STEP: `Part.export([obj], path)`。STL: メッシュの `write(path)`【実行】。
- 同じ名前に保存し直すと、`.FCBak` の控えが同じ場所にできる【実行】（下の GUI の状態を書き足すときも、2回目の保存で作られる）。生成物の置き場所を版管理から外すか、控えを外す設定にする。
- 断面: `shape.slice(App.Vector(法線), 位置)` が断面の輪郭（ワイヤ）を返す【実行】。`wire.discretize(Deflection=...)` で点にして、SVG などに書ける（雛形は追加の部品を使わずに SVG を書く）。
- 画像の部品（matplotlib など）を使うプレビューは、FreeCAD の Python にその部品が入っているかを先に確かめる。

## 開いたときの見え方（GUI の状態）

- **`freecadcmd` だけで保存した `.FCStd` には `GuiDocument.xml` が入らない**【実行】。そのファイルを GUI で開くと、部品の表示が切れている（`Visibility` が偽）【実行】。視点も保存されていない（`GuiDocument.xml` が視点を持つため）。
- 直し方: 保存の後に、`freecad` をオフスクリーンで起こしてファイルを開き、表示と視点を決めて保存し直す【実行】。
  - 環境の変数 `QT_QPA_PLATFORM=offscreen` を付け、`freecad -c "<Python の文>"` で流す。文の中で `Gui.showMainWindow()` を呼んでから `App.openDocument(...)` で開く。
  - 部品は `obj.ViewObject.Visibility = True`、表は `False` にする。
  - 視点は `Gui.ActiveDocument.ActiveView.setCamera(<Coin3D のカメラの文字列>)` で入れる。保存したファイルにその位置と向きが残る【実行】。
  - オフスクリーンでは、`viewIsometric()` と `fitAll()` を呼んでも、保存された視点は真上からのままだった【実行】。視点は、外形の箱から計算したカメラの文字列で入れる（雛形の `isometric_camera`）。
  - `freecad` が無い環境では、この手順を飛ばし、飛ばしたことを結果に書く。開く人には「表示を入れる」手順を README で案内する。
- 書き足したかは、`.FCStd`（zip）の中に `GuiDocument.xml` があるかで確かめられる【実行】。

## 落とし穴

- 丸め（フィレット）や面取りの対象の辺は、番号（`Edges[3]` など）で指さず、位置（高さや半径）で探して選ぶ。番号は形を変えると変わりうる。
- `.FCStd` の XML を直接直さない。スクリプトを直して組み立て直す。
