#!/bin/bash

function configure_keyboard {

  # declare local variables
  local FILE

  # set path for output file
  FILE="/etc/default/keyboard"

  if [[ -n "${KEYBOARD_MODEL:-}" ]]; then
    sed -i 's/^XKBMODEL=.*/XKBMODEL="'"$KEYBOARD_MODEL"'"/' "$FILE"
  fi

  if [[ -n "${KEYBOARD_LAYOUT:-}" ]]; then
    sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="'"$KEYBOARD_LAYOUT"'"/' "$FILE"
  fi

  if [[ -n "${KEYBOARD_VARIANT:-}" ]]; then
    sed -i 's/^XKBVARIANT=.*/XKBVARIANT="'"$KEYBOARD_VARIANT"'"/' "$FILE"
  fi

  if [[ -n "${KEYBOARD_OPTIONS:-}" ]]; then
    sed -i 's/^XKBOPTIONS=.*/XKBOPTIONS="'"$KEYBOARD_OPTIONS"'"/' "$FILE"
  fi

  if [[ -n "${KEYBOARD_MODEL:-}" ]] ||
    [[ -n "${KEYBOARD_LAYOUT:-}" ]] ||
    [[ -n "${KEYBOARD_VARIANT:-}" ]] ||
    [[ -n "${KEYBOARD_OPTIONS:-}" ]]; then

    # set preconfigured keyboard layout
    dpkg-reconfigure --frontend noninteractive keyboard-configuration

  else
    # interactive configuration by user
    dpkg-reconfigure keyboard-configuration
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"

    process_dotenv
    process_arguments "h" "help,keyboard-model:,keyboard-layout:,keyboard-variant:,keyboard-options:" "$@"

    # verify preconditions
    verify_root_privileges

    configure_keyboard
  }

  set -euo pipefail
  main "$@"
  exit 0
fi
