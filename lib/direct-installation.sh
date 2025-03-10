#!/bin/bash

function configure_fstab {

  # declare local variables
  local DEV_ROOT
  local DEV_BOOT_EFI
  local DEV_HOME
  local FILE
  local FILE_BOOT_EFI
  local FILE_HOME
  local UUID_ROOT
  local UUID_BOOT_EFI
  local UUID_HOME

  DEV_ROOT="$1"
  DEV_BOOT_EFI="$2"
  DEV_HOME="$3"
  TMP_SIZE="$4"

  # handle root partition
  FILE="$CHROOT/etc/fstab"
  UUID_ROOT="$(blkid -s UUID -o value "$DEV_ROOT")"

  # handle EFI partition
  if [[ -b "$DEV_BOOT_EFI" ]]; then
    FILE_BOOT_EFI="$FILE"
    UUID_BOOT_EFI="$(blkid -s UUID -o value "$DEV_BOOT_EFI")"
  else
    FILE_BOOT_EFI="/dev/null"  # discard EFI specific entry
    UUID_BOOT_EFI=""
  fi

  # handle home partition
  if [[ -b "$DEV_HOME" ]]; then
    FILE_HOME="$FILE"
    UUID_HOME="$(blkid -s UUID -o value "$DEV_HOME")"
  else
    FILE_HOME="/dev/null"  # discard home specific entry
    UUID_HOME=""
  fi

  if [[ -z "$TMP_SIZE" ]]; then
    TMP_SIZE="40%"
  fi

  # edit /etc/fstab
  echo '# <file system>       <mount point>     <type>    <options>                       <dump> <pass>' > "$FILE"
  echo "UUID=$UUID_ROOT       /                 ext4      defaults,errors=remount-ro      0      1" >> "$FILE"
  echo "UUID=$UUID_BOOT_EFI   /boot/efi         vfat      defaults                        0      2" >> "$FILE_BOOT_EFI"
  echo "UUID=$UUID_HOME       /home             ext4      defaults                        0      2" >> "$FILE_HOME"
  echo "proc                  /proc             proc      defaults                        0      0" >> "$FILE"
  echo "sys                   /sys              sysfs     defaults                        0      0" >> "$FILE"
  echo "tmpfs                 /tmp              tmpfs     defaults,size=$TMP_SIZE         0      0" >> "$FILE"
}

function copy_network_settings {

  # set HTTP proxy
  if [[ -n "${http_proxy:-}" ]]; then
    echo "http_proxy=$http_proxy" >>"$CHROOT/etc/environment"
    echo "HTTP_PROXY=$http_proxy" >>"$CHROOT/etc/environment"
  fi

  # set HTTPS proxy
  if [[ -n "${https_proxy:-}" ]]; then
    echo "https_proxy=$https_proxy" >>"$CHROOT/etc/environment"
    echo "HTTPS_PROXY=$https_proxy" >>"$CHROOT/etc/environment"
  fi

  # set FTP proxy
  if [[ -n "${ftp_proxy:-}" ]]; then
    echo "ftp_proxy=$ftp_proxy" >>"$CHROOT/etc/environment"
    echo "FTP_PROXY=$ftp_proxy" >>"$CHROOT/etc/environment"
  fi

  # set all socks proxy
  if [[ -n "${all_proxy:-}" ]]; then
    echo "all_proxy=$all_proxy" >>"$CHROOT/etc/environment"
    echo "ALL_PROXY=$all_proxy" >>"$CHROOT/etc/environment"
  fi

  # set ignore-hosts
  if [[ -n "${no_proxy:-}" ]]; then
    echo "no_proxy=$no_proxy" >>"$CHROOT/etc/environment"
    echo "NO_PROXY=$no_proxy" >>"$CHROOT/etc/environment"
  fi

  # copy DNS settings
  if [[ -f '/etc/systemd/resolved.conf' ]]; then
    cp -f '/etc/systemd/resolved.conf' "$CHROOT/etc/systemd/resolved.conf"
  fi

  # copy connection settings (system without network-manager)
  if [[ -d '/etc/netplan' ]]; then
    mkdir -p "$CHROOT/etc/netplan"
    cp -rf '/etc/netplan/.' "$CHROOT/etc/netplan"
  fi

  # copy connection settings (system with network-manager)
  if [[ -d '/etc/NetworkManager/system-connections' ]]; then
    mkdir -p "$CHROOT/etc/NetworkManager/system-connections"
    cp -rf '/etc/NetworkManager/system-connections/.' "$CHROOT/etc/NetworkManager/system-connections"
  fi

  # https://bugs.launchpad.net/ubuntu/+source/network-manager/+bug/1638842
  if command -v nmcli &>/dev/null; then
    mkdir -p "$CHROOT/etc/NetworkManager/conf.d"
    touch "$CHROOT/etc/NetworkManager/conf.d/10-globally-managed-devices.conf"
  fi
}
