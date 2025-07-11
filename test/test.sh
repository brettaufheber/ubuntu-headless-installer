#!/bin/bash

function main {

  local CODENAME

  SELF_PATH="$(readlink -f "$0")"
  SELF_NAME="$(basename "$SELF_PATH")"
  SELF_DIR="$(dirname "$SELF_PATH")"

  # load test variables
  source "$SELF_DIR/test.env"

  if [[ $# -ne 2 ]]; then
    echo "$SELF_NAME: require arguments <task> <codename|ALL>" >&2
    exit 1
  fi

  TASK="$1"
  CODENAME="$2"
  IMAGE="./tmp/test.img"

  run_test_suite "$CODENAME"
}

function run_test_suite {

  local CODENAME

  CODENAME="$1"

  before_all

  if [[ "$CODENAME" == "ALL" ]]; then
    for i in $(get_codenames); do
      before_each
      execute_installer "$i"
      after_each
    done
  else
    before_each
    execute_installer "$CODENAME"
    after_each
  fi

  after_all
}

function execute_installer {

  local CODENAME

  CODENAME="$1"

  echo "$SELF_NAME: installation with codename $CODENAME"

  if [[ "$TASK" == "install-system" ]]; then
    ubuntu-installer install-system \
      --codename "$CODENAME" \
      --hostname-new "$TEST_HOSTNAME" \
      --username-new "$TEST_USERNAME" \
      --mirror "$TEST_MIRROR" \
      --dev-root "${DEV_LOOP_SYSTEM:-}" \
      --dev-home "${DEV_LOOP_HOME:-}" \
      --dev-mbr-legacy "${DEV_LOOP_IMAGE:-}" \
      --bundles "$TEST_BUNDLES" \
      --locales "$TEST_LOCALES" \
      --time-zone "$TEST_TZ" \
      --user-gecos "$TEST_USER_GECOS" \
      --password "$TEST_PASSWORD" \
      --keyboard-model "$TEST_KEYBOARD_MODEL" \
      --keyboard-layout "$TEST_KEYBOARD_LAYOUT" \
      --keyboard-variant "$TEST_KEYBOARD_VARIANT" \
      --keyboard-options "$TEST_KEYBOARD_OPTIONS"
  elif [[ "$TASK" == "build-lxc-image" ]]; then
    ubuntu-installer build-lxc-image \
      --codename "$CODENAME" \
      --mirror "$TEST_MIRROR" \
      --bundles "$TEST_BUNDLES"
  elif [[ "$TASK" == "build-docker-image" ]]; then
    ubuntu-installer build-docker-image \
      --codename "$CODENAME" \
      --mirror "$TEST_MIRROR" \
      --bundles "$TEST_BUNDLES"
  else
    echo "$SELF_NAME: task $TASK is not covered by testing" >&2
    exit 1
  fi
}

function get_codenames {

  local REPO_BASE_URL
  local THRESHOLD
  local NOW
  local VERSIONS_AVAILABLE
  local CURRENT_CODENAME
  local METADATA
  local META_CODENAME
  local META_VERSION
  local META_MONTH
  local META_YEAR
  local META_TIMESTAMP

  REPO_BASE_URL='http://archive.ubuntu.com/ubuntu/dists'
  THRESHOLD=$(date -d '5 years ago' +%s)
  NOW=$(date +%s)

  VERSIONS_AVAILABLE="$(
    wget -qO - "$REPO_BASE_URL/" |
      sed 's/<[^>]*>/ /g' |
      grep -E '^\s*[a-z]+/' |
      sed -n -e 's/^[[:space:]]*\([a-z]\+\)\/[[:space:]]\+.*$/\1/p'
  )"

  while read -r CURRENT_CODENAME; do

    METADATA="$(wget -qO - "$REPO_BASE_URL/$CURRENT_CODENAME/Release")"
    META_CODENAME="$(echo "$METADATA" | grep -oP 'Codename:\s+\K[^\n]+')"
    META_VERSION=$(echo "$METADATA" | grep -oP '^Version:\s+\K[0-9]+\.[0-9]+')

    META_MONTH=${META_VERSION#*.}
    META_MONTH="$(printf "%02d" "$META_MONTH")"
    META_YEAR=${META_VERSION%%.*}
    META_YEAR="$(( $(date +%Y) / (10 ** ${#META_YEAR}) * (10 ** ${#META_YEAR}) + 10#${META_YEAR} ))"
    META_TIMESTAMP="$(date -d "${META_YEAR}-${META_MONTH}-01" +%s)"

    if [[ "$META_CODENAME" == "$CURRENT_CODENAME" ]] &&
        (( META_TIMESTAMP >= THRESHOLD && META_TIMESTAMP <= NOW )); then
      echo "$CURRENT_CODENAME"
    fi

  done <<< "$VERSIONS_AVAILABLE"
}

function before_each {

  if [[ "$TASK" == "install-system" ]]; then
    mkfs.ext4 "$DEV_LOOP_HOME"
  fi

  echo "$SELF_NAME: begin installation (task: $TASK)"
}

function after_each {

  echo "$SELF_NAME: end installation (task: $TASK)"
}

function before_all {

  if [[ "$TASK" == "install-system" ]]; then

    mkdir -p "$(dirname "$IMAGE")"
    dd "if=/dev/zero" "of=$IMAGE" bs=1G count=10
    sfdisk "$IMAGE" <"$SELF_DIR/sfdisk.txt"

    DEV_LOOP_IMAGE="$(losetup --show --find --partscan "$IMAGE")"
    DEV_LOOP_SYSTEM="$DEV_LOOP_IMAGE""p1"
    DEV_LOOP_HOME="$DEV_LOOP_IMAGE""p2"
  fi
}

function after_all {

  if [[ "$TASK" == "install-system" ]]; then
    [[ -n "${DEV_LOOP_IMAGE:-}" ]] && losetup -d "$DEV_LOOP_IMAGE"
    [[ -f "$IMAGE" ]] && rm "$IMAGE"
  fi
}

function error_trap {

  after_all

  echo "$SELF_NAME: script stopped caused by unexpected return code $1 at line $2" >&2
  exit 3
}

function interrupt_trap {

  after_all

  echo "$SELF_NAME: script interrupted by signal" >&2
  exit 2
}

set -euEo pipefail
trap 'RC=$?; error_trap "$RC" "$LINENO"' ERR
trap 'interrupt_trap' INT
main "$@"
exit 0
