#!/bin/bash

function configure_tools {

  # declare local variables
  local FILE_VIMRC
  local FILE_BASHRC
  local COMPLETION_SCRIPT

  # set paths for output files
  FILE_VIMRC="/etc/vim/vimrc"
  FILE_BASHRC="/etc/bash.bashrc"

  # add vim settings
  cat >>"$FILE_VIMRC" <<'EOF'

filetype plugin indent on
syntax on
set nocp
set background=light
set tabstop=4
set shiftwidth=4
set expandtab

EOF

  # enable bash history search completion
  cat >>"$FILE_BASHRC" <<'EOF'

# enable bash history search completion
if [[ $- == *i* ]]; then
  bind '"\e[A": history-search-backward'
  bind '"\e[B": history-search-forward'
fi

EOF

  # get code for bash completion
  COMPLETION_SCRIPT="$(cat "$FILE_BASHRC" |
    sed -n '/# enable bash completion in interactive shells/,/^$/p' |
    sed '1,1d; $d' |
    cut -c 2-)"

  # enable bash completion
  echo "" >> "$FILE_BASHRC"
  echo "$COMPLETION_SCRIPT" >> "$FILE_BASHRC"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"

    # verify preconditions
    verify_root_privileges

    configure_tools
  }

  set -euo pipefail
  main "$@"
  exit 0
fi
