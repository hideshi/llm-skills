# Git

本文の手順（記録より先に控えを取る、再開の時に取り直して照らす、未確定の変更を勝手にコミットしない）を、Git で行うときの資料。

- 確かめた版: Git 2.47.3、Linux
- 確かめた日: 2026-11-13
- 【実行】は小さなリポジトリを作って実際に動かして確かめたこと、【資料】は公式の資料で読んだだけのこと

## 控えに残す三つ

| 項目 | コマンド（【実行】） | 読み方 |
|---|---|---|
| 版 | `git rev-parse HEAD` | コミットの識別子 |
| 未確定の変更 | `git status --porcelain --untracked-files=all` | 1行に1つ。`M` は変更、`??` は追跡していない新しいファイル。空なら変更なし |
| 監視するパスの内容 | `git hash-object -- <パス>` | 内容のハッシュ。追跡していないファイルにも使える |

```sh
# 監視するパスを1行1つで書いたファイル watch-paths.txt を用意する
git rev-parse HEAD
git status --porcelain --untracked-files=all
while IFS= read -r p; do
  if [ -e "$p" ]; then printf '%s %s\n' "$(git hash-object -- "$p")" "$p"
  else printf 'missing %s\n' "$p"; fi
done < watch-paths.txt
```

- 監視するパスには、未確定の変更があるパスと、記録が指す成果物の文書を必ず入れる。ディレクトリを監視するなら、その下のファイルを列挙してからハッシュを取る。
- 結果は、引継ぎの記録と同じ置き場に残す。再開の時に同じ手順で取り直し、三つを比べる。

## 落とし穴

- **消えたパスに `git hash-object` を使うと、`fatal: could not open … for reading` で誤りになる**（【実行】）。上の例のように、先に有るかを確かめて「missing」と書く。消えたことも変化として扱う。
- `--untracked-files=all` を付けないと、新しいディレクトリの中のファイルが、ディレクトリ1行（`?? d/`）にまとめられる（【実行】）。控えでは全部を並べる。
- 控えを取るために、コミットやスタッシュをしない。共有のスタッシュは、ほかの作業の変更と混ざりうる。未確定の変更をどうするかは、案件の決まりと人の指示に従う。

## 公式の資料

- [git status](https://git-scm.com/docs/git-status)
- [git rev-parse](https://git-scm.com/docs/git-rev-parse)
- [git hash-object](https://git-scm.com/docs/git-hash-object)
