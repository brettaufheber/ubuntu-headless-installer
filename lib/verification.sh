#!/bin/bash

function verify_root_privileges {

  if [[ "$EUID" -ne 0 ]]; then
    echo "$SELF_NAME: require root privileges" >&2
    exit 1
  fi
}

function verify_username {

  NAME_REGEX="$(get_username_regex)"

  if [[ -n "${USERNAME_NEW:-}" ]]; then
    if ! echo "$USERNAME_NEW" | grep -qE "$NAME_REGEX"; then
      echo "$SELF_NAME: require username that matches regular expression $NAME_REGEX" >&2
      exit 1
    fi
  else
    # by default, use the name of the user who runs the script
    USERNAME_NEW="$(get_username)"
  fi

  # make sure the username is different to root
  if [[ "${USERNAME_NEW:-}" == "root" ]]; then
    echo "$SELF_NAME: require username different to root" >&2
    exit 1
  fi
}

function verify_username_does_exist {

  if ! getent passwd "${USERNAME_NEW:-}" >/dev/null; then
    echo "$SELF_NAME: the username does not exist" >&2
    exit 1
  fi
}

function verify_username_does_not_exist {

  if getent passwd "${USERNAME_NEW:-}" >/dev/null; then
    echo "$SELF_NAME: the username has already been taken" >&2
    exit 1
  fi
}

function verify_hostname {

  # by default, use the hostname of the running system
  if [[ -z "${HOSTNAME_NEW:-}" ]]; then
    HOSTNAME_NEW="$HOSTNAME"
  fi
}

function verify_codename {

  if [[ -z "${CODENAME:-}" ]] || ! echo "$CODENAME" | grep -qE '^[a-z]+$'; then
    echo "$SELF_NAME: require valid Ubuntu codename" >&2
    exit 1
  fi
}

function verify_mounting_root {

  # the block device file for the system partition must be unmounted
  if [[ -z "${DEV_ROOT:-}" ]] || [[ ! -b "$DEV_ROOT" ]] || findmnt "$DEV_ROOT" &>/dev/null; then
    echo "$SELF_NAME: require unmounted device file for /" >&2
    exit 1
  fi
}

function verify_mounting_boot_efi {

  # the block device file for the EFI partition
  if [[ -n "${DEV_BOOT_EFI:-}" ]] && [[ ! -b "$DEV_BOOT_EFI" ]]; then
    echo "$SELF_NAME: require device file for /boot/efi" >&2
    exit 1
  fi
}

function verify_mounting_boot_firmware {

  # the block device file for the firmware partition
  if [[ -n "${DEV_BOOT_FIRMWARE:-}" ]] && [[ ! -b "$DEV_BOOT_FIRMWARE" ]]; then
    echo "$SELF_NAME: require device file for /boot/firmware" >&2
    exit 1
  fi
}

function verify_mounting_home {

  # the block device file for the home partition
  if [[ -n "${DEV_HOME:-}" ]] && [[ ! -b "$DEV_HOME" ]]; then
    echo "$SELF_NAME: require device file for /home" >&2
    exit 1
  fi
}

function verify_mounting_mbr_legacy {

  # the block device file, chosen for the master boot record (MBR)
  if [[ -n "${DEV_MBR_LEGACY:-}" ]] && [[ ! -b "$DEV_MBR_LEGACY" ]]; then
    echo "$SELF_NAME: require device file for the master boot record (MBR)" >&2
    exit 1
  fi
}

function verify_bundles_file {

  if [[ -z "${BUNDLES_FILE:-}" ]]; then
    BUNDLES_FILE="$SELF_PROJECT_PATH/etc/bundles.txt"
  fi

  if [[ ! -f "$BUNDLES_FILE" ]]; then
    echo "$SELF_NAME: require existing file for bundles configuration" >&2
    exit 1
  fi
}

function verify_debconf_file {

  if [[ -z "${DEBCONF_FILE:-}" ]]; then
    DEBCONF_FILE="$SELF_PROJECT_PATH/etc/debconf.txt"
  fi

  if [[ ! -f "$DEBCONF_FILE" ]]; then
    echo "$SELF_NAME: require existing file for initial debconf settings" >&2
    exit 1
  fi
}

function verify_dconf_file {

  if [[ -z "${DCONF_FILE:-}" ]]; then
    DCONF_FILE="$SELF_PROJECT_PATH/etc/dconf.ini"
  fi

  if [[ ! -f "$DCONF_FILE" ]]; then
    echo "$SELF_NAME: require existing file for initial dconf settings" >&2
    exit 1
  fi
}
