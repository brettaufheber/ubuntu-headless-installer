#!/bin/bash

function manage_package_sources {

  # declare local variables
  local TRUSTED_GPG
  local SOURCES_LIST
  local PREFERENCES
  local COMPONENTS

  # set variables
  TRUSTED_GPG='/etc/apt/trusted.gpg.d'
  SOURCES_LIST='/etc/apt/sources.list.d'
  PREFERENCES='/etc/apt/preferences.d'
  COMPONENTS='main universe multiverse restricted'

  # by default, use the whole Ubuntu mirror list
  if [[ -z "${MIRROR:-}" ]]; then
    MIRROR='mirror://mirrors.ubuntu.com/mirrors.txt'
  fi

  # set OS variables
  source /etc/os-release

  # add package sources
  add-apt-repository -y -s "deb $MIRROR $UBUNTU_CODENAME $COMPONENTS"
  add-apt-repository -y -s "deb $MIRROR $UBUNTU_CODENAME-updates $COMPONENTS"
  add-apt-repository -y -s "deb $MIRROR $UBUNTU_CODENAME-security $COMPONENTS"
  add-apt-repository -y -s "deb $MIRROR $UBUNTU_CODENAME-backports $COMPONENTS"

  # add package sources for sbt
  wget -qO - 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823' |
    gpg --no-default-keyring --keyring "gnupg-ring:$TRUSTED_GPG/scalasbt-release.gpg" --import
  chmod 644 "$TRUSTED_GPG/scalasbt-release.gpg"
  echo 'deb https://repo.scala-sbt.org/scalasbt/debian all main' >"$SOURCES_LIST/sbt.list"

  # add package sources for chrome browser
  wget -qO - 'https://dl-ssl.google.com/linux/linux_signing_key.pub' |
    gpg --no-default-keyring --keyring "gnupg-ring:$TRUSTED_GPG/google-chrome.gpg" --import
  chmod 644 "$TRUSTED_GPG/google-chrome.gpg"
  echo 'deb https://dl.google.com/linux/chrome/deb/ stable main' >"$SOURCES_LIST/google-chrome.list"

  # add package sources for firefox
  add-apt-repository -y ppa:mozillateam/ppa
  echo 'Package: firefox*' > "$PREFERENCES/mozilla-firefox"
  echo 'Pin: release o=LP-PPA-mozillateam' >> "$PREFERENCES/mozilla-firefox"
  echo 'Pin-Priority: 1001' >> "$PREFERENCES/mozilla-firefox"

  # update package lists
  apt-get update
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"

    process_dotenv
    process_arguments "h" "help,mirror:" "$@"

    # verify preconditions
    verify_root_privileges

    manage_package_sources
  }

  set -euo pipefail
  main "$@"
  exit 0
fi
