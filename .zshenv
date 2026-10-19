# Keep PATH/path free of duplicates no matter how many times this file (or
# .zprofile/.zshrc/.zshrc.mac/.zshrc.local) prepends the same directory —
# every zsh invocation, including nested subshells, sources .zshenv, so
# without this the same dirs pile up on every re-entry.
typeset -U path PATH

export PATH="/opt/local/libexec/gnubin:/usr/local/bin:/opt/local/bin:/opt/local/sbin:/usr/local/lib:/usr/sbin:$PATH"
export PATH="$HOME/.local/lib/npm/bin:$PATH"

# Begin added by argcomplete
fpath=( /Users/sasaki/research/BioModels/Generate_biomath/env_generate/lib/python3.10/site-packages/argcomplete/bash_completion.d "${fpath[@]}" )
# End added by argcomplete
