#!/bin/bash

function main {

  # declare local variables
  local OPTIONS_PARSED

  # set default values and configuration
  SELF_PATH="$(readlink -f "$0")"
  SELF_NAME="$(basename "$SELF_PATH")"
  SELF_DIR="$(dirname "$SELF_PATH")"
  WITH_HELPER_EXTRAS=false

  # parse arguments
  OPTIONS_PARSED=$(
    getopt \
      --options '' \
      --longoptions 'with-helper-extras' \
      --name "$SELF_NAME" \
      -- "$@"
  )

  # replace arguments
  eval set -- "$OPTIONS_PARSED"

  # apply arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --with-helper-extras)
      WITH_HELPER_EXTRAS=true
      shift 1
      ;;
    --)
      shift 1
      break
      ;;
    *)
      break
      ;;
    esac
  done

  # check if there is no unassigned argument left
  if [[ $# -ne 0 ]]; then
    echo "$SELF_NAME: cannot handle unassigned arguments: $*" >&2
    exit 1
  fi

  task_install_script
}

function verify_root_privileges {

  if [[ $EUID -ne 0 ]]; then
    echo "$SELF_NAME: require root privileges" >&2
    exit 1
  fi
}

function task_install_script {

  # declare local variables
  local SBIN_DIR
  local VAR_DIR
  local ENTRY

  # verify preconditions
  verify_root_privileges

  SBIN_DIR='/usr/local/sbin'
  VAR_DIR='/var/local/ubuntu-headless-installer'

  cp -v "$SELF_DIR/ubuntu-installer.sh" "$SBIN_DIR"
  chmod a+x "$SBIN_DIR/ubuntu-installer.sh"

  if "$WITH_HELPER_EXTRAS"; then
    for ENTRY in "$SELF_DIR/helper-extras"/*; do
      cp -v "$ENTRY" "$SBIN_DIR"
      chmod a+x "$SBIN_DIR/$(basename "$ENTRY")"
    done
  fi

  mkdir -p "$VAR_DIR"
  cp -v "$SELF_DIR/bundles.txt" "$VAR_DIR"
  cp -v "$SELF_DIR/debconf.txt" "$VAR_DIR"
  cp -v "$SELF_DIR/dconf.ini" "$VAR_DIR"
}

set -euo pipefail
main "$@"
exit 0
