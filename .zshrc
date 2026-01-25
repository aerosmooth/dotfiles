# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
#  fi
alias emacs="/Applications/MacPorts/Emacs.app/Contents/MacOS/emacs -nw"
unalias emacs
# emacsのエイリアス
alias emacs="/usr/bin/emacs -nw"
export JAVA_HOME=/opt/local/Library/Java/JavaVirtualMachines/openjdk11-zulu/Contents/Home
# 履歴検索を有効化
autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
# Ctrl+P / Ctrl+N で履歴検索
bindkey "^P" history-beginning-search-backward-end
bindkey "^N" history-beginning-search-forward-end
#フルパスの補完
bindkey "^[/" expand-cmd-path
#slashとか
export WORDCHARS='*?_-.[]~=&;!#$%^(){}<'
#colors
autoload -U colors compinit
colors
#メール
MAILPATH="/var/spool/mail/$USER?${fg[red]}You have new mail."
MAILCHECK=20
#ログイン
watch=(all)
LOGCHECK=20
#.oファイルなどを補完候補に出さない
fignore=(.o .aux .log .bbl .blg .lof .dvi .fls .fdb_latexmk .synctex.gz .lot .toc .out .a\~)
alias ez="emacs ~/.zshrc"
alias nz="nvim ~/.zshrc"
alias sz="source ~/.zshrc"
#ディレクトリスタックの上限
DIRSTACKSIZE=10
#ログアウトを防ぐ
setopt IGNORE_EOF
#コマンド訂正
setopt CORRECT_ALL
#補完候補を詰めない
setopt noLIST_PACKED
#ファイルタイプの表示
setopt LIST_TYPES
#cdの自動入力
setopt AUTO_CD
#自動的にpushd
setopt AUTO_PUSHD
#名前の変更
# PS1="ssk %~ %#  "
#PS1="%n:%{${fg[red]}${bg[yellow]%} %~%{${fg[green]}${bg[default]%} %# "
#同じコマンドをヒストリにいれない
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
zstyle ':completion:*default' menu select=1
#export LSCOLORS=gxfxcxdxbxegedabagacad
zstyle ':completion:*' list-colors di=36 ln=35 ex=31 '=*.c=33' '=*.py=33'
setopt INTERACTIVE_COMMENTS
setopt RM_STAR_WAIT
setopt EXTENDED_GLOB
alias ls='ls --color=auto -F'
# backup my nvim config
# backup my neovim config. you can restore the config by using restore-nvim.zsh
backup-nvim() {
  local timestamp=$(date "+%Y-%m-%d-%H%M")
  echo "Backup following directories"
  echo "  ~/.config/nvim      => ~/.config/nvim.${timestamp}"
  echo "  ~/.local/share/nvim => ~/.local/share/nvim.${timestamp}"
  echo "  ~/.local/state/nvim => ~/.local/state/nvim.${timestamp}"
  echo "  ~/.cache/nvim       => ~/.cache/nvim.${timestamp}"
 
  # required
  mv ~/.config/nvim ~/.config/nvim.${timestamp}
 
  # optional but recommended
  mv ~/.local/share/nvim ~/.local/share/nvim.${timestamp}
  mv ~/.local/state/nvim ~/.local/state/nvim.${timestamp}
  mv ~/.cache/nvim ~/.cache/nvim.${timestamp}
}
# Restore your backed up nvim config. Use the backup-nvim.zsh script to create the backup.
restore-nvim() {
  local backup_array=(${(f)"$(command ls -1d ~/.config/nvim.* | sort -nr | sed -e 's/.*nvim/nvim/')"})

  if [ $#backup_array = 0 ]; then
    echo "No backup directory found"
    return 1
  fi
  for ((i = 1; i <= $#backup_array; i++)) print -r -- "[$i] $backup_array[i]"

  # select backup directory
  echo ""
  echo -n "Select index: "
  re='^[0-9]+$'
  read index
  if ! [[ $index =~ $re ]] ; then
    echo "Error: Not a number"
    return 1
  fi
  if [ $index -gt $#backup_array ]; then
    echo "index must be less than $#backup_array"
    return 1
  fi
  if [ $index -lt 1 ]; then
    echo "index must be greater than 1"
    return 1
  fi
  local selected=$backup_array[$index]
  echo "Selected: $selected"
  local backup_config="$HOME/.config/$selected"
  local backup_share="$HOME/.local/share/$selected"
  local backup_state="$HOME/.local/state/$selected"
  local backup_cache="$HOME/.cache/$selected"

  if [ ! -d $backup_config -o ! -d $backup_share -o ! -d $backup_state -o ! -d $backup_cache ]; then
    echo "backup directory not found"
    return 1
  fi

  echo ""
  echo "Restore following directories"
  echo ""
  echo "  $backup_config      => ~/.config/nvim"
  echo "  $backup_share => ~/.local/share/nvim"
  echo "  $backup_state => ~/.local/state/nvim"
  echo "  $backup_cache       => ~/.cache/nvim"
  echo ""
  echo "This operation will overwrite the above directories."
  echo -n "Proceed? [y/N] "

  read yesno
  # execute
  if [ $yesno = "y" -o $yesno = "Y" ]; then
    if [ -d ~/.config//nvim ]; then
      rm -rf ~/.config/nvim
    fi
    if [ -d ~/.local/share/nvim ]; then
      rm -rf ~/.local/share/nvim
    fi
    if [ -d ~/.local/state/nvim ]; then
      rm -rf ~/.local/state/nvim
    fi
    if [ -d ~/.cache//nvim ]; then
      rm -rf ~/.cache/nvim
    fi
    mv $backup_config ~/.config/nvim
    mv $backup_share  ~/.local/share/nvim
    mv $backup_state  ~/.local/state/nvim
    mv $backup_cache  ~/.cache/nvim
  fi
}
function chpwd() {
    ls -G
}
# 環境変数 NVIM_AUTO_PICKERをセットしてから nvim を起動
alias nvimed='NVIM_AUTO_PICKER=config nvim'
### direnv for python virtualenv
if whence direnv &>/dev/null; then eval "$(direnv hook zsh)"; fi
source ~/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export LSCOLORS=Bxegedabagacad # ディレクトリを青
export LSCOLORS=Gxfxcxdxbxegedabagacad # ディレクトリを緑
export LSCOLORS=exfxcxdxbxegedabagacad # ディレクトリを青、実行ファイルを赤
export PATH="/Users/sasaki/Library/Python/3.9/bin:$PATH"
export PATH=/usr/local/anaconda3/bin:$PATH

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/usr/local/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/usr/local/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/usr/local/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/usr/local/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<


alias deac='deactivate'
alias gitlog='git log --oneline --graph --decorate'
alias pipupgrade='pip install --upgrade pip'
alias ssd='/Volumes/sasaki_SSD/research'
# alias unmount_ssd='disk_id=$(diskutil list | grep "sasaki_SSD" | awk '{print $NF}')'
# エイリアス: 外付けSSD 'sasaki_SSD' を安全に取り出す
alias unmount_ssd='disk_id=$(diskutil list | grep "sasaki_SSD" | awk "{print \$NF}"); diskutil unmountDisk /dev/$disk_id'
# 履歴を保存するファイルのパスを指定
# (ホームディレクトリの .zsh_history というファイル名が一般的)
HISTFILE=~/.zsh_history

# メモリ内で記憶しておくコマンド数
HISTSIZE=10000

# 履歴ファイルに保存するコマンド数 (HISTSIZEと同じでOK)
SAVEHIST=10000

# 重複するコマンドは保存しない
setopt HIST_IGNORE_ALL_DUPS

# 履歴をセッション間で即時共有する (複数ターミナルで便利)
setopt SHARE_HISTORY

# コマンド実行後、すぐに履歴ファイルに追記する (終了時だけでなく)
setopt INC_APPEND_HISTORY
SR() {
    cd ./git/mye2esr
    conda activate e2esr
}

