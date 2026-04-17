#!/bin/bash

# dotfilesディレクトリに移動
cd "$HOME/dotfiles" || exit

# 1. リモートに未知の変更があればPullして結合する
git pull origin main --rebase

# 2. ローカルに変更があるか確認する
if [ -n "$(git status --porcelain)" ]; then
  git add .
  git commit -m "Auto-sync dotfiles: $(date '+%Y-%m-%d %H:%M:%S')"
  git push origin main
fi
