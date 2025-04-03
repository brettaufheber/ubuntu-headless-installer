#!/bin/bash

function user_create {

  local -a ADD_USER_ARGS

  ADD_USER_ARGS=()

  if "$ADD_EXTRA_GROUPS"; then
    ADD_USER_ARGS+=( "--add_extra_groups" )
  fi

  if [[ -n "${UID_NEW:-}" ]]; then
    ADD_USER_ARGS+=( "--uid" "$UID_NEW" )
  fi

  if [[ -n "${GID_NEW:-}" ]]; then
    ADD_USER_ARGS+=( "--gid" "$GID_NEW" )
  fi

  if [[ -n "${PASSWORD:-}" ]]; then
    ADD_USER_ARGS+=( "--disabled-password" )
  fi

  # create user and home-directory if not exist
  adduser "${ADD_USER_ARGS[@]}" --gecos "${USER_GECOS:-}" "$USERNAME_NEW"

  # set password by environment variable if defined
  if [[ -n "${PASSWORD:-}" ]]; then
    usermod --password "$(openssl passwd -6 "$PASSWORD")" "$USERNAME_NEW"
  fi

  # at least the user is added to the group "users"
  if ! "$ADD_EXTRA_GROUPS"; then
    usermod -aG "users" "$USERNAME_NEW"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"

    process_dotenv
    LONG_OPTIONS='help,add-extra-groups'
    LONG_OPTIONS="$LONG_OPTIONS"',username-new:,uid-new:,gid-new:,user-gecos:'
    LONG_OPTIONS="$LONG_OPTIONS"',password:'
    process_arguments "heu" "$LONG_OPTIONS" "$@"

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
