#!/bin/bash

# スクリプトを実行しシンボリックリンクを一気に作成する
# ./deploy.sh

# カレントディレクトリのファイル/ディレクトリをループ（堅牢性のため変数名をfileに変更）
for file in $(ls -A | grep -vE '\.git$|\.gitignore$|deploy.sh$|zsh$|README.md$|.DS_Store$|sync_dotfiles.sh$'); do
  # リンク元とリンク先のパスを明確に変数に格納
  src_path="$PWD/$file"
  dest_path="$HOME/$file"

  # ★修正点1: 存在チェックを -f (ファイル) から -e (ファイルまたはディレクトリ) または -L (リンク) に変更
  # これにより、ファイルだけでなくディレクトリや既存のリンクも検出できる
  if [ -e "$dest_path" ] || [ -L "$dest_path" ]; then
    echo "File/Link '$dest_path' already exists. Do you want to overwrite it? (y/n)"
    read -r answer # -r オプションで安全な読み込み

    # マッチングをより確実なものに変更
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      echo "Backing up '$dest_path' to '$dest_path.bak'..."
      # 既存のファイルをバックアップ
      mv "$dest_path" "$dest_path.bak"

      # ★修正点2: lnコマンドに -n オプションを追加
      # -s: シンボリックリンクを作成
      # -n: リンク先がディレクトリの場合、その中にリンクを作らず、リンク自体を置き換える (非常に重要)
      # -f: リンク先が既に存在する場合に強制上書きする
      echo "Creating link: $dest_path -> $src_path"
      ln -snf "$src_path" "$dest_path"
    else
      echo "Skipping '$file'."
    fi
  else
    # リンク先が存在しない場合も同じオプションでリンクを作成
    echo "Creating link: $dest_path -> $src_path"
    ln -snf "$src_path" "$dest_path"
  fi
done # "fidone" は "fi" と "done" の誤記と思われます

echo "Deployment finished."
