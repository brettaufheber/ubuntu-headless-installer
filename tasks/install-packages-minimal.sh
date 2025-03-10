#!/bin/bash

function install_packages_minimal {

  # disable interactive interfaces
  export DEBIAN_FRONTEND=noninteractive

  # update installed software
  apt-get update
  apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
  apt-get -y autoremove --purge

  # install main packages
  apt-get -y install ubuntu-minimal
  apt-get -y install debootstrap
  apt-get -y install software-properties-common
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"

    # verify preconditions
    verify_root_privileges

    install_packages_minimal
  }

  set -euo pipefail
  main "$@"
  exit 0
fi
