#!/bin/bash

for file in $(ls -A | grep -vE '\.git$|\.gitignore$|deploy.sh$|zsh$|README.md$|.DS_Store$|sync_dotfiles.sh$'); do
  src_path="$PWD/$file"
  dest_path="$HOME/$file"

  if [ -e "$dest_path" ] || [ -L "$dest_path" ]; then
    echo "File/Link '$dest_path' already exists. Do you want to overwrite it? (y/n)"
    read -r answer

    if [[ "$answer" =~ ^[Yy]$ ]]; then
      echo "Backing up '$dest_path' to '$dest_path.bak'..."
      mv "$dest_path" "$dest_path.bak"

      echo "Creating link: $dest_path -> $src_path"
      ln -snf "$src_path" "$dest_path"
    else
      echo "Skipping '$file'."
    fi
  else
    echo "Creating link: $dest_path -> $src_path"
    ln -snf "$src_path" "$dest_path"
  fi
done

echo "Deployment finished."
