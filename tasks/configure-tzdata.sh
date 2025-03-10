#!/bin/bash

function configure_tzdata {

  if [[ -n "${TIME_ZONE:-}" ]]; then
    TZ="$TIME_ZONE"
  fi

  if [[ -n "${TZ:-}" ]]; then
    # set preconfigured time zone
    ln -fs "/usr/share/zoneinfo/$TZ" /etc/localtime && dpkg-reconfigure --frontend noninteractive tzdata
  else
    # interactive configuration by user
    dpkg-reconfigure tzdata
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"

    process_dotenv
    process_arguments "h" "help,time-zone:" "$@"

    # verify preconditions
    verify_root_privileges

    configure_tzdata
  }

  set -euo pipefail
  main "$@"
  exit 0
fi
