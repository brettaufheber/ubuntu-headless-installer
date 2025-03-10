#!/bin/bash

function install_packages_os {

  # disable interactive interfaces
  export DEBIAN_FRONTEND=noninteractive

  # update installed software
  apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
  apt-get -y autoremove --purge

  # install GRUB bootloader
  if [[ -n "${DEV_MBR_LEGACY:-}" ]]; then
    apt-get -y install grub-pc
    grub-install "$DEV_MBR_LEGACY"
  else
    apt-get -y install grub-efi
    grub-install --target=x86_64-efi --efi-directory=/boot/efi
    echo 'The boot order must be adjusted manually using the efibootmgr tool.'
  fi

  # install Linux kernel
  apt-get -y install linux-generic

  # set GRUB_CMDLINE_LINUX_DEFAULT
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet noplymouth"/' /etc/default/grub

  # apply grub configuration changes
  update-grub
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"

    process_dotenv
    process_arguments "h" "help,dev-mbr-legacy:" "$@"

    # verify preconditions
    verify_root_privileges

    install_packages_os
  }

  set -euo pipefail
  main "$@"
  exit 0
fi
