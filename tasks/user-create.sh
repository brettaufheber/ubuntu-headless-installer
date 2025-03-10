#!/bin/bash

function user_create {

  # create user and home-directory if not exist
  if [[ -n "${PASSWORD:-}" ]]; then
    adduser --add_extra_groups --disabled-password --gecos "${USER_GECOS:-}" "$USERNAME_NEW"
    usermod --password "$(openssl passwd -6 "$PASSWORD")" "$USERNAME_NEW"
  else
    adduser --add_extra_groups --gecos "${USER_GECOS:-}" "$USERNAME_NEW"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"

    process_dotenv
    process_arguments "hu" "help,username-new:,user-gecos:,password:" "$@"

    # verify preconditions
    verify_root_privileges
    verify_username
    verify_username_does_not_exist

    user_create
  }

  set -euo pipefail
  main "$@"
  exit 0
fi
