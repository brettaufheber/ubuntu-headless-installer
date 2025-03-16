#!/bin/bash

function main {

  SELF_PATH="$(readlink -f "${0}")"
  SELF_PROJECT_PATH="$(dirname "$SELF_PATH")"
  SELF_NAME="$(basename "$SELF_PATH")"

  source "$SELF_PROJECT_PATH/lib/common.sh"
  source "$SELF_PROJECT_PATH/lib/verification.sh"

  verify_root_privileges
  install_ubuntu_installer
}

set -euo pipefail
main "$@"
exit 0
