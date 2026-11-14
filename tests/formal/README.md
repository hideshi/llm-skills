# プロファイルの形式モデル

開発作業の群のプロファイル（`skills/dev-profile-*`）ごとに、工程の順序、条件、戻る流れ、人の決定を TLA+ で表し、TLC で検査する。単位の中身は表さない。

| プロファイル | モデル |
|---|---|
| `dev-profile-dependency-upkeep` | [profile-dependency-upkeep](profile-dependency-upkeep/) |
| `dev-profile-existing-system` | [profile-existing-system](profile-existing-system/) |
| `dev-profile-exposure-sweep` | [profile-exposure-sweep](profile-exposure-sweep/) |
| `dev-profile-inherited-system` | [profile-inherited-system](profile-inherited-system/) |
| `dev-profile-interrupt-resume` | [profile-interrupt-resume](profile-interrupt-resume/) |
| `dev-profile-new-feature` | [profile-new-feature](profile-new-feature/) |
| `dev-profile-review-cycle` | [profile-review-cycle](profile-review-cycle/) |
| `dev-profile-version-control` | [profile-version-control](profile-version-control/) |

## 写しのずれを防ぐ

工程と遷移の正本は、各プロファイルの SKILL.md の工程の表と「### 遷移」の表。流れ図（`docs/dev-skills-flows.md`）とこのモデルは写しで、次の検査で突き合わせる。

```sh
python3 -I scripts/check_dev_flows.py --tla-jar /path/to/tla2tools.jar
```

- 遷移の表、流れ図の矢印、TLC が実際にたどった工程の移り変わりの三つを、工程から工程への矢印にたたんで比べる（判定のひし形、人の決定、入口、終わりは、たたむ）。
- モデルがたどった移り変わりは、各モデルの末尾の `EdgeProbe`（工程の組を初めて見たときだけ `<<"EDGE", 元, 先>>` を書き出す）で集める。検査は設定に `ACTION_CONSTRAINT EdgeProbe` を足した写しで TLC を流す。`EdgeProbe` は常に真なので、たどる状態は変わらない。状態の図をまるごと書き出す方法（`-dump dot`）は、依頼の違いが増えると数百 MB になるので使わない。新しいモデルにも、同じ定義を末尾に置く。
- jar を渡さなければ、遷移の表と流れ図だけを比べ、モデルとの突き合わせを飛ばしたことを表示する。
- モデルの `pc` の値と `Steps` は、プロファイルの工程の識別子で書く。工程でない値（`start`、`Done` など）は識別子に使わない。モデルで表さない工程は、`.tla` の「表さない工程:」の行に識別子をバッククォートで囲んで並べる。
- プロファイルの工程や遷移を変えたら、流れ図とモデルを直してから、この検査と各モデルの検査を流す。
- 2026-11-14 に工程の番号を識別子に置き換えた。各モデルの README の検査の記録のうち、それより前の行の番号は、[規約の付録の対応表](../../docs/dev-skills-conventions.md#付録-工程の識別子の対応表)で読み替える。

## 流すときの注意

TLC は、既定では CPU を全部使い、メモリも大きく取る。手元の機械（とくに仮想の Linux 環境）を使い切らないよう、上限を付けて流す。

```sh
java -Xmx1g -XX:+UseParallelGC -cp tla2tools.jar tlc2.TLC -workers 2 -config X.cfg X.tla
```

突き合わせの検査は、既定で `-Xmx1g`、2並び、10分の上限で TLC を流す（`TLC_HEAP`、`TLC_WORKERS`、`TLC_TIMEOUT` で変えられる）。依頼ごとの違いを足すと状態の数は掛け算で増えるので、意味の無い組み合わせを作らないよう、関係する違いは一つの値にまとめる。

動かし方と結果の読み方は `skills/dev-formal-model-check/references/tools/tla-plus.md` を見る。
