#!/bin/bash

function configure_locales {

  # declare local variables
  local LOCALES_LIST
  local PRIMARY_LOCAL

  if [[ -n "${LOCALES:-}" ]]; then

    LOCALES_LIST="$(echo "$LOCALES" | tr ',' ' ')"
    PRIMARY_LOCAL="$(echo "$LOCALES_LIST" | cut -d ' ' -f 1)"

    for i in $LOCALES_LIST; do
      if [[ "$i" != "POSIX" ]] && [[ "$i" != "C" ]] && [[ "$i" != "C."* ]]; then
        # generate a locale for each entry in list
        locale-gen "$i"
      fi
    done

    export LANG="$PRIMARY_LOCAL"
    export LANGUAGE=""
    export LC_CTYPE="$PRIMARY_LOCAL"
    export LC_NUMERIC="$PRIMARY_LOCAL"
    export LC_TIME="$PRIMARY_LOCAL"
    export LC_COLLATE="$PRIMARY_LOCAL"
    export LC_MONETARY="$PRIMARY_LOCAL"
    export LC_MESSAGES="POSIX"
    export LC_PAPER="$PRIMARY_LOCAL"
    export LC_NAME="$PRIMARY_LOCAL"
    export LC_ADDRESS="$PRIMARY_LOCAL"
    export LC_TELEPHONE="$PRIMARY_LOCAL"
    export LC_MEASUREMENT="$PRIMARY_LOCAL"
    export LC_IDENTIFICATION="$PRIMARY_LOCAL"
    export LC_ALL=""

    # the first locale defined in the list will be installed
    dpkg-reconfigure --frontend noninteractive locales

  else
    # interactive configuration by user
    dpkg-reconfigure locales
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"

    process_dotenv
    process_arguments "h" "help,locales:" "$@"

    # verify preconditions
    verify_root_privileges

    configure_locales
  }

  set -euo pipefail
  main "$@"
  exit 0
fi
