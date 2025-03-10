#!/bin/bash

function user_modify {

  local EXTRA_GROUPS

  # get the extra groups
  EXTRA_GROUPS="$(grep '^EXTRA_GROUPS=' /etc/adduser.conf | cut -d '=' -f2 | tr -d '"')"

  # change username if required
  if [[ -n "${USERNAME_OLD:-}" && "$USERNAME_OLD" != "$USERNAME_NEW" ]]; then
    usermod -l "$USERNAME_NEW" -d "/home/$USERNAME_NEW" -m "$USERNAME_OLD"
  fi

  # add user to extra groups
  for CURRENT_GROUP in $EXTRA_GROUPS; do
    if grep -qE "^$CURRENT_GROUP:" /etc/group; then
      usermod -aG "$CURRENT_GROUP" "$USERNAME_NEW"
    fi
  done

  # set GECOS for the user
  if [[ -n "${USER_GECOS:-}" ]]; then
    usermod -c "$USER_GECOS" "$USERNAME_NEW"
  fi

  # set user password
  if [[ -n "${PASSWORD:-}" ]]; then
    usermod --password "$(openssl passwd -6 "$PASSWORD")" "$USERNAME_NEW"
  else
    passwd "$USERNAME_NEW"
  fi

  # create home-directory if not exist
  mkhomedir_helper "$USERNAME_NEW"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"

    process_dotenv
    process_arguments "hu" "help,username-new:,username-old:,user-gecos:,password:" "$@"

    # verify preconditions
    verify_root_privileges
    verify_username
    verify_username_does_exist

    user_modify
  }

  set -euo pipefail
  main "$@"
  exit 0
fi
