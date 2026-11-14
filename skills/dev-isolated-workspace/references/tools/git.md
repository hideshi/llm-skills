# Git

作業場所の分離（`git worktree`）、除外されたファイルの洗い出し、統合前後の点検と片付けを Git で行うときの資料。

- 確かめた版: Git 2.47.3、Linux
- 確かめた日: 2026-11-13
- 【実行】は小さなリポジトリを作って実際に動かして確かめたこと、【資料】は公式の資料で読んだだけのこと

## 作成・一覧・片付け

```sh
# 現在の作業場所と枝を一覧する（【実行】）
git worktree list --porcelain

# 新しい枝を切って作業場所を作る（【実行】）
git worktree add -b "<作業用の枝>" "<作業場所のパス>" "<元の枝>"

# 版管理から除外されていて新しい作業場所に写らないファイルを洗い出す（【実行】）
git status --ignored --porcelain
git ls-files --others --ignored --exclude-standard

# 未確定の変更・未追跡・除外された成果物が残っていないかを、片付ける作業場所の中を指して確かめる
# （元の場所で実行すると、作業場所の中の除外された成果物は出ない。【実行】）
git -C "<作業場所のパス>" status --porcelain --ignored --untracked-files=all

# 未反映・未統合のコミットが残っていないかを確かめる（通常のマージ・早送りで統合した場合。出力が空なら統合済み。【実行】）
git log --oneline "<元の枝>..<作業用の枝>"
git branch --no-merged "<元の枝>"
```

squash や rebase（摘み取り）で統合した場合は、作業用の枝のコミットが元の枝に載らないため、上の確かめは空にならず、`git branch -d` も `not fully merged` で拒否される（【実行】）。原典の統合方法に合わせて、内容が取り込まれたことを次のように確かめ、検証の記録に残す。

`git cherry` と `git patch-id --stable` は空白の違いを無視するため、字下げが崩れた取り込みでも「同じ」と出る（【実行】、[git patch-id](https://git-scm.com/docs/git-patch-id)）。これらは対応するコミットの見当を付けるだけに使い、統合済みとする判断は、空白も含めてバイト単位で比べた結果で行う。

```bash
# 比較にプロセス置換を使うため bash で動かす
mb=$(git merge-base "<元の枝>" "<作業用の枝>")

# 見当付け: rebase・摘み取りなら全コミットに - が付くか、squash なら patch-id が合うか（空白は無視される）
git cherry "<元の枝>" "<作業用の枝>"
git diff "$mb" "<作業用の枝>" | git patch-id --stable
git show "<squash したコミット>" | git patch-id --stable

# 判断: 取り込んだコミットが元の枝から到達でき、変更がバイト単位で一致する（空白・モード・バイナリも比べる。【実行】）
git merge-base --is-ancestor "<squash したコミット>" "<元の枝>"
cmp <(git diff --binary "$mb" "<作業用の枝>") <(git diff --binary "<squash したコミット>^" "<squash したコミット>")
# rebase・摘み取りで複数のコミットに分かれたときは、変更したパスの最終の内容が元の枝と一致するかで見る
git diff --quiet "<作業用の枝>" "<元の枝>" -- $(git diff --name-only "$mb" "<作業用の枝>")
```

上の判断が一致しなかったとき（統合後に元の枝で同じパスが変わった場合も含む）は、統合済みとせず、差分を人に見せて破棄の承認を得るか、作業用の枝を残す。統合先での検査の結果（ビルド・テスト）も検証の記録に添える。

```sh
# 上を確認し退避を済ませたうえで、作業場所と統合済みの枝を外す（【実行】）
git worktree remove "<作業場所のパス>"
# -d は、上流が設定された枝ならその上流、無ければ実行した場所の HEAD に統合済みかを見る（【実行】、【資料】）。
# 上流に載っていれば元の枝へ未統合でも消せてしまうため、元の枝への統合は上の確かめで別に確かめておく
git branch -d "<作業用の枝>"
# -D は、破棄の承認があるとき、または squash・rebase での内容の統合を上のバイト単位の照合で確かめて記録したときだけ使う
```

## 落とし穴

- **同じ枝を2つの作業場所で同時に開くと失敗する**（【実行】）。`fatal: '<枝>' is already used by worktree at ...` で止まるため、作業場所ごとに専用の枝を切る。
- **`git worktree remove` は未確定の変更・未追跡がある作業場所を既定で拒否するが、除外（ignored）ファイルや未統合コミットがあっても成功する**（【実行】）。必ず事前に、作業場所の中を指した `--ignored` 付きの `git status` と、統合方法に合った未統合の確かめ（`git log "<元の枝>..<作業用の枝>"`、または squash・rebase ならバイト単位の差分の照合）を行い、退避または破棄の承認を得てから外す。`--force` を安易に使わない。
- **worktree が分けるのは作業ツリー・索引・`HEAD` だけで、テスト用 DB・ストレージ・共有の常駐処理や、共有リンク先の依存までは分かれない**。`git status --ignored` で漏れた環境設定や素材を洗い出し、接続先を確かめてから実行する。
- **退避のために `git stash` を使わない**。共有のスタッシュは別の作業場所の変更と混ざりうるため、作業場所専用の枝への一時コミットで扱う。
- **worktree の手動削除の後は管理情報が残る**（【資料】）。ディレクトリを手で消した場合は `git worktree prune` で整理する。

## 公式の資料

- [git worktree](https://git-scm.com/docs/git-worktree)
- [git status](https://git-scm.com/docs/git-status)
- [git ls-files](https://git-scm.com/docs/git-ls-files)
- [git stash](https://git-scm.com/docs/git-stash)
