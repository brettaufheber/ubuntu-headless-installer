#!/bin/bash

function install_system {

  # format $DEV_ROOT
  format_ext4 "$DEV_ROOT"

  # mount devices/partitions
  mount_devices "${DEV_ROOT:-}" "${DEV_BOOT_EFI:-}" "" "${DEV_HOME:-}"

  # create a minimal system without kernel or bootloader
  debootstrap "--arch=$ARCH" "$CODENAME" "$CHROOT" "$MIRROR"

  # make sure that symlinks to stub-resolv.conf will not break
  ensure_resolv_conf_on_host

  # mount OS resources into chroot environment
  mount_os_resources

  # perform some fundamental configuration
  configure_hosts
  configure_fstab "${DEV_ROOT:-}" "${DEV_BOOT_EFI:-}" "" "${DEV_HOME:-}" "${TMP_SIZE:-}"
  configure_users

  # this allows to copy network settings from the host system; can help to perform a installation behind a proxy
  if "$COPY_NETWORK_SETTINGS"; then
    copy_network_settings
  fi

  # make the installer usable inside chroot environment
  install_ubuntu_installer "${CHROOT}${DEFAULT_INSTALL_DIR}" "${CHROOT}/usr/local/sbin"

  # install minimal packages required to perform the next installation steps
  chroot "$CHROOT" ubuntu-installer install-packages-minimal

  # install the Linux kernel and GRUB bootloader
  chroot "$CHROOT" ubuntu-installer install-packages-os --dev-mbr-legacy "${DEV_MBR_LEGACY:-}"

  # configure packages
  chroot "$CHROOT" ubuntu-installer configure-locales --locales "${LOCALES:-}"
  chroot "$CHROOT" ubuntu-installer configure-tzdata --time-zone "${TIME_ZONE:-}"
  chroot "$CHROOT" ubuntu-installer configure-keyboard \
    --keyboard-model "${KEYBOARD_MODEL:-}" \
    --keyboard-layout "${KEYBOARD_LAYOUT:-}" \
    --keyboard-variant "${KEYBOARD_VARIANT:-}" \
    --keyboard-options "${KEYBOARD_OPTIONS:-}"
  chroot "$CHROOT" ubuntu-installer configure-tools

  # manage package sources
  chroot "$CHROOT" ubuntu-installer manage-package-sources --mirror "$MIRROR"

  # install software
  chroot "$CHROOT" ubuntu-installer install-packages-base --bundles "${BUNDLES:-}"

  # do some modifications for desktop environments, but only if specific desktop related packages are installed
  configure_desktop "${DCONF_FILE:-}"

  # remove retrieved package files
  chroot "$CHROOT" apt-get clean

  # create user
  chroot "$CHROOT" ubuntu-installer user-create \
    --add-extra-groups \
    --username-new "$USERNAME_NEW" \
    --user-gecos "${USER_GECOS:-}" \
    --password "${PASSWORD:-}"

  # run post install command
  if [[ -n "${POST_INSTALL_CMD:-}" ]]; then
    chroot "$CHROOT" /bin/bash -euo pipefail -c "$POST_INSTALL_CMD"
  fi

  # login to shell for diagnostic purposes
  if "$SHELL_LOGIN"; then
    user_login_chroot
  fi

  # unmount everything
  unmount_os_resources
  unmount_devices

  echo "$SELF_NAME: done."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    HOME="/tmp"

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"
    source "$SELF_PROJECT_PATH/lib/mounting.sh"
    source "$SELF_PROJECT_PATH/lib/any-installation.sh"
    source "$SELF_PROJECT_PATH/lib/direct-installation.sh"

    process_dotenv
    LONG_OPTIONS='help,shell-login,copy-network-settings'
    LONG_OPTIONS="$LONG_OPTIONS"',codename:,hostname-new:,username-new:,arch:,mirror:'
    LONG_OPTIONS="$LONG_OPTIONS"',dev-root:,dev-boot-efi:,dev-home:,dev-mbr-legacy:'
    LONG_OPTIONS="$LONG_OPTIONS"',tmp-size:,bundles:,bundles-file:,debconf-file:,dconf-file:,post-install-cmd:'
    LONG_OPTIONS="$LONG_OPTIONS"',locales:,time-zone:,user-gecos:,password:'
    LONG_OPTIONS="$LONG_OPTIONS"',keyboard-model:,keyboard-layout:,keyboard-variant:,keyboard-options:'
    process_arguments "hlkcnu" "$LONG_OPTIONS" "$@"

    # verify preconditions
    verify_root_privileges
    verify_codename
    verify_hostname
    verify_username
    verify_architecture
    verify_mirror
    verify_mounting_root
    verify_mounting_boot_efi
    verify_mounting_home
    verify_mounting_mbr_legacy
    verify_bundles_file
    verify_debconf_file
    verify_dconf_file

    install_system
  }

  set -euEo pipefail
  trap 'RC=$?; error_trap "$RC" "$LINENO"' ERR
  trap 'interrupt_trap' INT
  main "$@"
  exit 0
fi
