#!/bin/bash

function install_packages_base {

  # disable interactive interfaces
  export DEBIAN_FRONTEND=noninteractive

  # update installed software
  apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
  apt-get -y autoremove --purge

  # install main packages
  apt-get -y install ubuntu-server ubuntu-standard
  apt-get -y install lxc debootstrap bridge-utils
  apt-get -y install software-properties-common
  apt-get -y install debconf-utils
  apt-get -y install aptitude

  # install additional file system support
  apt-get -y install zfsutils-linux
  apt-get -y install btrfs-progs

  # install version control system
  apt-get -y install git

  # install text editors and query tools
  apt-get -y install vim
  apt-get -y install emacs-nox
  apt-get -y install nano
  apt-get -y install jq

  # install archiving and compression tools
  apt-get -y install tar gzip bzip2 xz-utils zip unzip p7zip-full p7zip-rar unrar lzop zstd lz4

  # install SSH support
  apt-get -y install openssh-server openssh-client sshfs

  # install SSL support
  apt-get -y install openssl

  # install GnuPG
  apt-get -y install gnupg

  # install support of snap packages
  apt-get -y install snapd

  # install OpenJDK JRE (headless)
  apt-get -y install "openjdk-$(find_openjdk_lts_versions | sort -rn | head -n 1)-jre-headless"

  # install everything else needed by a simple general purpose system
  aptitude -y install ~pstandard ~pimportant ~prequired
}

function configure_debconf {

  # set default values for packages
  debconf-set-selections "$DEBCONF_FILE"
}

function install_bundles {

  local LINE
  local CATEGORY_PATTERN
  local CATEGORY_MAIN
  local CATEGORY_SUB
  local SYSLANG
  local OPENJDK_VERSION
  local INDEX
  local BARRAY
  local INSTALL_GRANTED

  CATEGORY_PATTERN="^\[([a-z0-9_]+)(:([a-z0-9_]+))?\]$"
  INSTALL_GRANTED=false

  source /etc/default/locale
  SYSLANG="$(echo "$LANG" | grep -oE '^([a-zA-Z]+)' | sed -r 's/^(C|POSIX)$/en/')"
  SYSLANG="${SYSLANG:-'en'}"

  OPENJDK_VERSION="$(find_openjdk_lts_versions | sort -rn | head -n 1)"

  if [[ -z "${BUNDLES:-}" ]]; then
    # by default, use an empty array for bundle entries
    declare -a BARRAY
  else
    # create an array with bundle entries
    readarray -td ',' BARRAY <<<"$BUNDLES"
    for INDEX in "${!BARRAY[@]}"; do BARRAY[$INDEX]="$(echo "${BARRAY[$INDEX]}" | tr -d '[:space:]')"; done
  fi

  while IFS= read -r LINE; do

    # remove comments
    LINE="$(echo "$LINE" | cut -d '#' -f 1)"

    # remove leading and trailing whitespaces
    LINE="$(echo "$LINE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    # substitute LANG placeholder
    LINE="${LINE//\%LANG\%/$SYSLANG}"

    # substitute OPENJDK_VERSION placeholder
    LINE="${LINE//\%OPENJDK_VERSION\%/$OPENJDK_VERSION}"

    # skip empty lines
    if [[ -z "$LINE" ]]; then
      continue
    fi

    if [[ "$LINE" =~ $CATEGORY_PATTERN ]]; then

      CATEGORY_MAIN="${BASH_REMATCH[1]}"
      CATEGORY_SUB="${BASH_REMATCH[3]}"

      if echo "${BARRAY[@]}" | grep -qw "$CATEGORY_MAIN" &&
        { [[ -z "$CATEGORY_SUB" ]] || echo "${BARRAY[@]}" | grep -qw "$CATEGORY_SUB"; }; then
        INSTALL_GRANTED=true
      else
        INSTALL_GRANTED=false
      fi

    else

      if "$INSTALL_GRANTED"; then
        # install APT packages
        echo "$LINE" | xargs apt-get -y install
      fi
    fi
  done < "$BUNDLES_FILE"
}

function find_openjdk_lts_versions {

  local LTS_VERSIONS
  local AVAILABLE_VERSIONS
  local LTS_ARRAY
  local AVAILABLE_ARRAY

  LTS_VERSIONS=$(curl -s "https://api.adoptium.net/v3/info/available_releases" | jq -r '.available_lts_releases[]')
  AVAILABLE_VERSIONS=$(apt-cache search openjdk | grep -oP '^openjdk-\K\d+(?=-jdk\s+)')

  readarray -t LTS_ARRAY <<< "$LTS_VERSIONS"
  readarray -t AVAILABLE_ARRAY <<< "$AVAILABLE_VERSIONS"

  for LTS in "${LTS_ARRAY[@]}"; do
    for AVAILABLE in "${AVAILABLE_ARRAY[@]}"; do
      if [[ "$LTS" == "$AVAILABLE" ]]; then
        echo "$LTS"
      fi
    done
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"

    process_dotenv
    process_arguments "h" "help,bundles:,bundles-file:,debconf-file:" "$@"

    # verify preconditions
    verify_root_privileges
    verify_bundles_file
    verify_debconf_file

    install_packages_base
    configure_debconf  # pre-seed the debconf database
    install_bundles  # install additional software
  }

  set -euo pipefail
  main "$@"
  exit 0
fi
