# Git

着地の判定、控えの枝の確保、操作の印ごとの復旧手順、共有作業ツリーでのステージ分離を Git で行うときの資料。`<元枝>`、`<遠隔>`、`<控え枝>` は対象の環境に合わせて置き換える。

- 確かめた版: Git 2.47.3、Linux
- 確かめた日: 2026-11-13
- 【実行】は小さなリポジトリを作って実際に動かして確かめたこと、【資料】は公式の資料で読んだだけのこと

## 操作の印の目安

印の語は型の一覧の「段に付ける印」にそろえる。

| 印 | 操作の例 | 承認と控え |
|---|---|---|
| なし（読むだけ） | `git fetch`（手元の遠隔追跡の参照だけを更新し、枝・索引・作業ツリーは変えない。`--prune` は付けない）、`git status` | 前後の記録 |
| 変える | `git branch <控え枝>`、外すコミット、`git revert`、別索引での分離コミット | 控えと前後の記録 |
| 外へ送る | 早送りで済む `git push`（外すコミットや打ち消しコミットを送る） | 送る前に Q1・Q2 の判定と前後の記録 |
| 取り返せない | 未送信範囲だけの `git commit --amend` / `git reset --soft HEAD~1` / `git rebase --onto`、共有履歴の書き換え（`git filter-repo` 等）、`git reset --hard` | 控えの枝＋未確定変更の復元可能な退避＋破壊的操作の計画の承認。共有済みの履歴なら、知らせる相手を計画の影響の範囲に書き、承認の後、実行の前に知らせる |
| 取り返せない・外へ送る | `git push --force-with-lease` | 上に加えて、計画に固定した確認済みの遠隔 SHA |

外部道具（`git filter-repo` など）の導入は、印とは別に計画の承認の対象にする。

## 確認と控え（手順 1・2）

```sh
# 1. 遠隔の有無と取得の設定を確認し、遠隔があるときは遠隔ごとに名指しで取得する
#    `git fetch --all` は remote.<名前>.skipFetchAll が真の遠隔を黙って飛ばし、終了値は 0 のままになる（【実行】）。
#    取得の範囲（remote.<名前>.fetch）が一部の枝に絞られていないかも見る。
#    --prune は付けず古い遠隔追跡も手掛かりとして残す。どれか一つでも失敗した、または範囲が絞られていたら共有状態は不明として扱う
git remote -v
git config --get-regexp '^remote\..*\.(skipfetchall|fetch)$'
for r in $(git remote); do git fetch "$r" || echo "取得失敗: $r"; done

# 2. 今の位置と未確定・管理外変更を確認し、控えの枝を作る
git status --porcelain --ignored --untracked-files=all
git branch "<控え枝>" HEAD
```

変更があれば、作業ツリーの外の退避先（`<退避先>`）へバイナリを含めて退避し、場所を `退避の所在` に記録する。`stash -u` と `clean` は使わない。`git diff` は未追跡ファイルを含まないため、未追跡は一覧を作って別に写す。除外（ignored）されたファイルは未追跡の一覧に出ないため、別に一覧を作り、必要なもの（設定・素材・証拠など）を選んで同じように写す。写さないと決めたものは、理由と一緒に `退避の所在` に記録する（【実行】）。各ファイルの内容の控えとして、ハッシュも取る。退避・写し・ハッシュのどれかが失敗したら、後続の操作へ進まない。

```sh
git diff --binary > "<退避先>/wt.patch"
git diff --cached --binary > "<退避先>/idx.patch"
git ls-files --others --exclude-standard -z > "<退避先>/untracked.list"
git ls-files --others --ignored --exclude-standard -z > "<退避先>/ignored-all.list"
# ignored-all.list から写すものを選んで "<退避先>/ignored.list" を作り、未追跡と合わせて写す
cat "<退避先>/untracked.list" "<退避先>/ignored.list" > "<退避先>/files.list"
tar --null -T "<退避先>/files.list" -cf "<退避先>/files.tar"
xargs -0 sha256sum -- < "<退避先>/files.list" > "<退避先>/files.sha256"
```

復元できることは、その場ではなく控えの版から作った検証用の作業場所で、索引 → 作業ツリー → 未追跡・除外ファイルの順に戻して比べて確かめる（【実行】）。退避した変更は今の作業ツリーに既に入っているため、その場で順方向に `git apply --check` すると必ず失敗する。その場で手早く見るだけなら逆向き（`git apply --check -R "<退避先>/wt.patch"`、`git apply --cached --check -R "<退避先>/idx.patch"`）にする（【実行】）。空の退避は `git apply` が `No valid patches in input` で失敗するので、中身が空なら当てずに飛ばす。

```bash
# 比較にプロセス置換を使うため bash で動かす
git worktree add --detach "<検証用の場所>" HEAD
[ -s "<退避先>/idx.patch" ] && git -C "<検証用の場所>" apply --index "<退避先>/idx.patch"
[ -s "<退避先>/wt.patch" ] && git -C "<検証用の場所>" apply "<退避先>/wt.patch"
tar -xf "<退避先>/files.tar" -C "<検証用の場所>"
# 索引と作業ツリーの差分、状態の一覧、写したファイルの内容がすべて元と一致すれば復元できる。どれかが食い違ったら先へ進まない
git -C "<検証用の場所>" diff --cached --binary | cmp - "<退避先>/idx.patch"
git -C "<検証用の場所>" diff --binary | cmp - "<退避先>/wt.patch"
diff <(git status --porcelain --untracked-files=all) <(git -C "<検証用の場所>" status --porcelain --untracked-files=all)
# 状態の一覧はパスしか比べないため、写したファイルは中身をハッシュで照合する（中身を変えると食い違いが出る。【実行】）
(cd "<検証用の場所>" && sha256sum -c --quiet "<退避先>/files.sha256")
# 検証用の場所は自分で作った写しなので、確かめ終えたら強制して外す（元の作業場所には使わない）
git worktree remove --force "<検証用の場所>"
```

```sh
# 3. Q1: 統合先の枝に着地しているかを確かめる（0: 着地済み / 1: 未着地 / 2: 判定不能で進まない）
#    関数にしてあるので、対話シェルに貼っても終了しない。2 が返ったら後続へ進まずに止める
git branch -r --contains "<問題コミット>"
q1() {
  git rev-parse --verify --quiet "refs/remotes/<遠隔>/<統合先の枝>" >/dev/null \
    || { echo "判定不能: refs/remotes/<遠隔>/<統合先の枝> が無い"; return 2; }
  git merge-base --is-ancestor "<問題コミット>" "refs/remotes/<遠隔>/<統合先の枝>"
  case $? in
    0) echo "統合先に着地済み"; return 0 ;;
    1) echo "統合先に未着地"; return 1 ;;
    *) echo "判定不能"; return 2 ;;
  esac
}
q1

# 4. Q2: どの遠隔の枝からも到達できない未送信コミットの一覧（上流設定が無い新規枝でも動作する。【実行】）
#    遠隔を一つに絞ると、別の遠隔（fork など）へ送信済みのコミットまで未送信に入る（【実行】）。絞るときは理由を記録する
git log --oneline HEAD --not --remotes
```

## 代表的な復旧の型（手順 3〜5）

### 秘密・公開不可情報の誤混入（既定: 書き換えずに外す）

通常の索引で `git rm --cached` してから `git commit` すると、索引の全体が確定し、別のパスにある他人の登録まで一緒にコミットされる（【実行】）。`git commit --only -- <パス>` は作業ツリーにファイルが残っていると何もコミットしない（【実行】）。そこで、別索引で外すコミットを作る。

```sh
# 履歴を書き換えず、追跡から外すコミットを足す（ファイル自体は作業ツリーに残る）
# 先に、外すパスに他人の登録が無いことを確かめる（出たら止める）
git diff --cached --name-only -- "<パス>"
tmpdir=$(mktemp -d)
GIT_INDEX_FILE="$tmpdir/idx" git read-tree HEAD
GIT_INDEX_FILE="$tmpdir/idx" git rm -q --cached -- "<パス>"
GIT_INDEX_FILE="$tmpdir/idx" git diff --cached --name-status   # 外すパスだけが出ることを確かめる
GIT_INDEX_FILE="$tmpdir/idx" git commit -m "不要になった秘密・対象外ファイルを削除"
rm -rf "$tmpdir"
# 通常索引の該当パスを新しい HEAD にそろえる（ほかのパスの登録は残る。【実行】）
git reset -q -- "<パス>"
git status --porcelain
```

履歴に載った秘密は漏れたものとして扱い、失効・再発行の案内を優先する。履歴自体の書き換えは人の承認後にだけ行う。

### 大きなファイル・不要ファイルの除去と直前コミットの取り消し（未送信のとき）

- **先頭コミットだけから不要ファイルを外す場合（承認後、印は取り返せない）**: `git rm --cached -- "<パス>"` のうえで `git commit --amend --no-edit` でやり直す（作業ツリーにファイルを残したければ `--cached` を使う）。`--amend` は索引の全体を確定するため、直前に `git diff --cached --name-status` で自分の外す変更しか登録されていないことを確かめる。
- **直前の誤コミット自体を取り消す場合**: 未送信（Q2）で作業ツリーを残すなら計画承認後に `git reset --soft HEAD~1`（印は取り返せない）。既に共有済み（Q1）なら `git revert HEAD` で打ち消しコミットを足す（印は変える）。
- **未送信の途中のコミットで入った場合（Q2 で未送信に閉じている）**: `git rebase --onto "<問題コミットの親>" "<問題コミット>" "<今の枝>"` でそのコミットを外し、必要な変更だけをパス指定で足し直す（【資料】）。
- **複数コミットにまたがる・書き換え道具を使う場合**: `git filter-repo` は環境になければ導入自体に人の確認を取る。実行後は元の控えの枝とファイル一覧・差分を比較し、必要なファイルが巻き添えで消えていないか確かめる（【資料】）。
- `git reset --hard` は未確定の変更を破棄するため、控えの枝と `退避の所在` がそろい計画の承認を得た後だけ実行する。

### 共有作業ツリーでの安全な分離コミット

まず、自分のパスに他人の登録が無いかを確かめる。`git diff --cached --name-only -- "<自分のパス>"` に自分のものでない登録が出たら、どの方法でも止めて持ち主に確かめる（以下の手順はその登録を書き換えうる）。

```sh
# A. パスの持ち主が完全に分かれていて、自分のパスが既に追跡されているとき（【実行】）
#    ほかのパスの登録は保たれ、指定したパスは通常索引も新しい HEAD にそろう。未追跡の新規ファイルは指定できない
git commit --only -m "<コミットメッセージ>" -- "<自分のパス>"

# B. 同じファイルに他人の未登録の変更が混ざっていて、自分の差分だけを確定したいとき（linked worktree でも動作する。【実行】）
#    ファイル丸ごとの `git add` は他人の変更まで登録するので使わない。自分の差分だけのパッチを作り、別索引に当てる
git diff -- "<自分のパス>" > "<自分の差分>"   # 他人の差分の塊をここから取り除く（-U0 で出した場合は apply に --unidiff-zero を付ける）
tmpdir=$(mktemp -d)
GIT_INDEX_FILE="$tmpdir/idx" git read-tree HEAD
GIT_INDEX_FILE="$tmpdir/idx" git apply --cached "<自分の差分>"
GIT_INDEX_FILE="$tmpdir/idx" git diff --cached
GIT_INDEX_FILE="$tmpdir/idx" git commit -m "<コミットメッセージ>"
rm -rf "$tmpdir"

# 別索引で HEAD を進めた直後は、通常索引の該当パスが古い HEAD のままなので、自分の変更を打ち消す差分が登録されて見える。
# 最初の確認で他人の登録が無かったパスに限り、通常索引を HEAD とそろえる（作業ツリーの他人の変更は残る。【実行】）
git reset -q -- "<自分のパス>"
git status --porcelain --untracked-files=all
```

### 早送りできない push と `--force-with-lease`

- まず `git fetch` の後、`refs/remotes/<遠隔>/<元枝>..HEAD` と `HEAD..refs/remotes/<遠隔>/<元枝>` を比べて「なぜ早送りできないか」と未反映のコミット内容を特定する。
- 原則はマージで取り込み、早送りできる形で送信する。人の承認で強制送信が許された場合のみ、人が内容と影響を確認して計画に固定した遠隔 SHA を使い、`git push --force-with-lease="refs/heads/<元枝>:<確認済みSHA>" "<遠隔>" "HEAD:refs/heads/<元枝>"` の形で対象 refspec と期待 SHA を明示する（【実行】）。遠隔が想定外の別コミットへ進んでいれば `stale info` で安全に拒否される（【実行】）。拒否されたときに確認なしで `fetch` し直して再送しない。生の `--force` は使わない。

### 切り離された状態（detached HEAD）の救出

```sh
# まだ切り離された状態にいるとき: 今のコミットを失わないよう新しい枝を切って移る（未追跡ファイルがあっても退避前に clean しない）
git switch -c "<救出用の枝>"

# 既に別の枝へ移った後: 切り離し中のコミットはどの枝からも到達できなくなっているので、参照履歴から版を探して枝を付ける（【実行】）
git reflog -n 20 --format='%h %gs'
git branch "<救出用の枝>" "<見つけた版>"
```

## 落とし穴

- **`git add -A` や `git add -u` を復旧手順に混ぜない**。他人の変更や秘密ファイルまで巻き込んでコミットする原因になる。
- **確認なしの `fetch`（や別 worktree・エディタの自動取得）の直後に期待値なしの `--force-with-lease` を使うと、見ていない他人の更新まで期待値に取り込んで黙って上書きしてしまう**（【資料】）。必ず内容確認後に SHA を計画へ固定し、`--force-with-lease=<対象ref>:<確認済みSHA>` と対象 refspec を明示して使う。
- **linked worktree の `.git` はファイルなので `.git/tmp-...` に一時索引を作れない**（【実行】）。必ず `mktemp -d` 等の別領域を使い、コミット後に通常索引の対象パスを `git reset -q -- <自分のパス>` で整合させる。このパス単位の `reset` は同じパスの他人の登録も外すため、他人の登録が無いことを先に確かめたパスにだけ使う。
- **退避の確かめをその場の順方向 `git apply --check` で行わない**（【実行】）。変更が既に入っている作業ツリーには当たらず失敗するため、確かめを飛ばして破壊的操作へ進む動機になる。
- **`git filter-repo` は共有履歴を書き換えるため、実行後は前後のファイル一覧・ハッシュ・テストを必ず突き合わせる**。

## 公式の資料

- [git push](https://git-scm.com/docs/git-push)
- [git rebase](https://git-scm.com/docs/git-rebase)
- [git revert](https://git-scm.com/docs/git-revert)
- [git clean](https://git-scm.com/docs/git-clean)
- [git reset](https://git-scm.com/docs/git-reset)
- [git filter-repo README](https://raw.githubusercontent.com/newren/git-filter-repo/main/README.md)
