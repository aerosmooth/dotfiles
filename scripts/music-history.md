# 音楽の再生履歴

右プロンプトに「曲名 — 歌手名 · 3回目」を表示します。

```zsh
source ~/.zshrc.local
music-rank                          # 全期間の曲別ランキング（上位20件）
music-rank artists                  # 歌手別ランキング
music-rank --artist "椎名 豪"        # 歌手名の一部で絞り込み
music-rank --days 7                  # 最近7日分
music-rank artists --days 30         # 最近30日分の歌手別
music-rank --limit 50                # 上位50件
music-rank --all                     # 全件
music-rank --json                    # JSON形式
music-rank --help
export MUSIC_PROMPT_ENABLED=0        # 表示と記録をOFF
export MUSIC_PROMPT_ENABLED=1        # 表示と記録をON
```

## 数え方

- この設定を読み込んだ ON のターミナルが開いている間だけ記録します。
- 導入前や OFF 中の履歴は取り込めません。最初の通知が曲の途中でも1回と数えます。
- 再生開始を数えます。途中でスキップした曲も含みます。
- 一時停止からの再開、曲情報の更新、ターミナルの追加は回数を増やしません。
- 曲名と歌手名で集計します。同名・同歌手の別バージョンは合算されます。
- 同じ曲のリピートは時刻と再生位置で判定します。5秒以内の位置に10秒以上戻ったときも再生開始と数えるため、手動で曲の先頭へ戻した場合も増えます。
- 監視していなかった間の同じ曲の再生は、正確に数えられません。
- 複数のターミナルは同じ保存先を使います。

## 保存先

`~/.local/share/zsh-music-prompt/history.sqlite3`

曲名、歌手名、記録時刻、直近の再生状態を端末内に保存します。
外部への送信はしません。歌手別の回数は、その歌手の曲の合計です。
`--days N` は現在からさかのぼった N × 24 時間です。
右側の「N回目」は全期間の曲別回数です。

## 確認

```sh
python3 -B scripts/test_music_history.py -v
```

`.zshrc.local` は Git の管理対象外です。
コマンドとプロンプトから `~/dotfiles/scripts/music-history.py` を呼び出します。
