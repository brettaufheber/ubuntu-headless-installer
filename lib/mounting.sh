#!/bin/bash

# define the system root mounting point
CHROOT="/mnt/ubuntu-$(cat '/proc/sys/kernel/random/uuid')"

function user_login_chroot {

  echo "$SELF_NAME: You are now logged in to the chroot environment for diagnostic purposes. Press Ctrl-D to escape."
  chroot "$CHROOT" /bin/bash
}

function mount_devices {

  local DEV_ROOT
  local DEV_BOOT_EFI
  local DEV_HOME

  DEV_ROOT="$1"
  DEV_BOOT_EFI="$2"
  DEV_HOME="$3"

  # mount system partition
  mkdir -p "$CHROOT"
  mount "$DEV_ROOT" "$CHROOT"

  # mount the other partitions
  mount_extended "$DEV_BOOT_EFI" "$CHROOT/boot/efi"
  mount_extended "$DEV_HOME" "$CHROOT/home"
}

function mount_os_resources {

  # flush the cache
  sync

  # mount OS resources needed for a chroot based installation
  mount -t proc /proc "$CHROOT/proc"
  mount -t sysfs /sys "$CHROOT/sys"
  mount -o bind /dev/ "$CHROOT/dev"
  mount -o bind /dev/pts "$CHROOT/dev/pts"
  mount -o bind /run "$CHROOT/run"
  mount -o bind /tmp "$CHROOT/tmp"
}

function unmount_devices {

  # prepare unmount
  stop_chroot_processes
  sync

  # unmount partitions
  mountpoint -q "$CHROOT/boot/efi" && umount "$CHROOT/boot/efi"
  mountpoint -q "$CHROOT/home" && umount "$CHROOT/home"
  mountpoint -q "$CHROOT" && umount "$CHROOT"

  if [[ -d "$CHROOT" ]]; then
    rmdir "$CHROOT"
  fi
}

function unmount_os_resources {

  # prepare unmount
  stop_chroot_processes
  sync

  # unmount OS resources
  mountpoint -q "$CHROOT/tmp" && umount -l "$CHROOT/tmp"
  mountpoint -q "$CHROOT/run" && umount -l "$CHROOT/run"
  mountpoint -q "$CHROOT/dev/pts" && umount -l "$CHROOT/dev/pts"
  mountpoint -q "$CHROOT/dev" && umount -l "$CHROOT/dev"
  mountpoint -q "$CHROOT/sys" && umount -l "$CHROOT/sys"
  mountpoint -q "$CHROOT/proc" && umount -l "$CHROOT/proc"
}

function mount_extended {

  local DEV_FILE
  local MOUNT_POINT
  local MOUNT_PATH

  DEV_FILE="$1"
  MOUNT_POINT="$2"

  if [[ -b "$DEV_FILE" ]]; then
    mkdir -p "$MOUNT_POINT"
    if findmnt "$DEV_FILE" &>/dev/null; then
      MOUNT_PATH="$(df "$DEV_FILE" | awk 'NR==2 {print $6}')"
      mount -o bind "$MOUNT_PATH" "$MOUNT_POINT"
    else
      mount "$DEV_FILE" "$MOUNT_POINT"
    fi
  fi
}

function stop_chroot_processes {

  local ENTRY

  for ENTRY in /proc/*/root; do
    if [[ "$(readlink "$ENTRY")" =~ ^$CHROOT ]]; then
      kill -s TERM "$(basename "$(dirname "$ENTRY")")"
    fi
  done
}

function error_trap {

  # cleanup
  if [[ -n "${CHROOT:-}" ]]; then
    unmount_os_resources
    unmount_devices
  fi

  echo "$SELF_NAME: script stopped caused by unexpected return code $1 at line $2" >&2
  exit 3
}

function interrupt_trap {

  # cleanup
  if [[ -n "${CHROOT:-}" ]]; then
    unmount_os_resources
    unmount_devices
  fi

  echo "$SELF_NAME: script interrupted by signal" >&2
  exit 2
}
