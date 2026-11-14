# ffmpeg

本文の手順（提出する形に組み立てる、最初から最後まで見る、切り替わりの前後を細かく見る、焼き込んだ文字列を確かめる、所在とハッシュで確定する）を、ffmpeg と ffprobe で行うときの資料。

- 確かめた版: ffmpeg 7.1.5（Debian 13 の包み。libx264、libass、libfreetype つき）
- 確かめた日: 2026-11-13
- 【実行】は小さな動画を実際に作って確かめたこと、【資料】は公式の資料で読んだだけのこと

ここに書く検出の道具は、見る所を探す補助で、自分で全編を見ることの代わりにしない。

## 中身を調べる

```sh
ffprobe -v error \
  -show_entries stream=codec_name,width,height,pix_fmt,r_frame_rate:format=duration \
  -of compact in.webm
```

- 【実行】大きさや形式は、流れの先頭の値しか出ない。途中で大きさが変わった動画でも、先頭の値のまま（下の「つなぐ」を見る）。

## 提出する形に組み立てる

| 作業 | コマンド（【実行】） |
|---|---|
| webm を mp4 に | `ffmpeg -i in.webm -c:v libx264 -pix_fmt yuv420p -movflags +faststart out.mp4` |
| 縦横を偶数にそろえる | `-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2"` |
| 区間を切り出す | `ffmpeg -ss 3 -i in.mp4 -t 2 -c:v libx264 -pix_fmt yuv420p cut.mp4`（再符号化する） |

- **縦横が奇数だと、libx264 は `width not divisible by 2` で止まる**（【実行】終了コードは0以外）。
- **画像（PNG）から作ると、`-pix_fmt` を付けないかぎり yuv444p（High 4:4:4 Predictive）になる**（【実行】）。提出先の再生器で再生できるかを確かめるか、`-pix_fmt yuv420p` を付ける。
- **`-c copy` で切ると、前のキーフレームからの絵まで入る**（【実行】）。2秒を切ったのに、再符号化では50枚、`-c copy` では127枚だった。入れ物の編集の情報で隠しているだけなので、再生器や後の結合で前の場面が出うる。証拠の切り出しは再符号化し、切った後の最初と最後の絵を見る。

### つなぐ

- 【資料】連結の一覧（concat demuxer）でつなぐファイルは、流れの組と形式（コーデック、時間の単位など）が同じでなければならない。
- **大きさの違う動画を、連結の一覧と `-c copy` でつなぐと、警告なしで成功する**（【実行】）。後半の絵は元の大きさのまま変わり、ffprobe は先頭の大きさを出し続けた。つなぐ前に、全部を同じ大きさ・形式・フレームの速さに変換する。

## 字幕や見出しを焼き込む

- **`drawtext` は、`fontfile` を指定しないと、日本語のフォントが入った機械でも日本語が豆腐（□）になり、成功で終わる**（【実行】）。日本語のフォントを指定する。場所は `fc-match -f '%{file}' 'Noto Sans CJK JP'` などで探す。

```sh
ffmpeg -i in.mp4 -vf "drawtext=fontfile=/path/to/NotoSansCJK-Regular.ttc:text='注文を確定する':fontsize=36:x=20:y=h-60:enable='between(t,2,6)'" \
  -c:v libx264 -pix_fmt yuv420p out.mp4
```

- 焼き込んだ後、字幕の出ている時刻の絵を取り出して、焼き込まれた文字列を読む。予定していた文字列と取り違えない（【実行】`ffmpeg -ss 3 -i out.mp4 -frames:v 1 at-3s.png`）。

## 自分で見るための補助

| 探すもの | コマンド（【実行】） | 出る行 |
|---|---|---|
| 全体の見取り図 | `ffmpeg -i in.mp4 -vf "fps=1,drawtext=fontfile=…:text='%{pts\:hms}':fontcolor=red,tile=4x3" -frames:v 1 sheet.png` | 1秒ごとの絵に時刻を付けて並べた1枚 |
| 場面の切り替わり | `ffmpeg -i in.mp4 -vf "scdet=t=10" -an -f null -` | `lavfi.scd.time: 2` |
| 止まっている区間 | `ffmpeg -i in.mp4 -vf "freezedetect=n=0.003:d=1" -an -f null -` | `freeze_start`、`freeze_duration`、`freeze_end` |
| 暗い区間 | `ffmpeg -i in.mp4 -vf "blackdetect=d=0.5" -an -f null -` | `black_start:2 black_end:4 black_duration:2` |

- 切り替わりの時刻が分かったら、前後の絵を取り出して細かく見る。
- 止まっている区間は、内容が読める状態で止めた時間の確かめに使える。【実行】録画で止めた区間は、止まっている区間として出た。
- **最後まで止まったままの区間は、`freeze_start` だけが出て、`freeze_end` と `freeze_duration` が出ない**（【実行】）。長さは動画の長さから引いて求める。
- **見取り図の絵の数が枠に満たないと、余った枠は黒で埋まる**（【実行】）。黒い画面が映っていたと取り違えない。
- 中身が空の白い画面は、暗い区間の検出では見つからない。止まっている区間として出るだけなので、中身は目で見る。

## 確定とハッシュ

- **`-c copy` で入れ物を作り直しただけでも、ハッシュは変わる**（【実行】）。ハッシュ（`sha256sum out.mp4` など）は最後に組み立てた後に取り、その後は変換しない。変換したら取り直し、確定を外す。

## 公式の資料

- [ffmpeg のコマンド](https://ffmpeg.org/ffmpeg.html)
- [ffprobe](https://ffmpeg.org/ffprobe.html)
- [フィルター（drawtext、scdet、freezedetect、blackdetect、tile）](https://ffmpeg.org/ffmpeg-filters.html)
- [入れ物の形式と連結の一覧（concat）](https://ffmpeg.org/ffmpeg-formats.html#concat)
