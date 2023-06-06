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

    for i in $(get_codenames "$TEST_LAST_VERSIONS_COUNT"); do

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

  ./ubuntu-installer.sh "$TASK" \
    --username "$TEST_USERNAME" \
    --hostname "$TEST_HOSTNAME" \
    --codename "$CODENAME" \
    --bundles "$TEST_BUNDLES" \
    --dev-root "${DEV_LOOP_SYSTEM:-}" \
    --dev-home "${DEV_LOOP_HOME:-}" \
    --dev-boot "${DEV_LOOP_IMAGE:-}" \
    --mirror "$TEST_MIRROR" \
    --locales "$TEST_LOCALES" \
    --time-zone "$TEST_TZ" \
    --user-gecos "$TEST_USER_GECOS" \
    --password "$TEST_PASSWORD" \
    --keyboard-model "$TEST_XKBMODEL" \
    --keyboard-layout "$TEST_XKBLAYOUT" \
    --keyboard-variant "$TEST_XKBVARIANT" \
    --keyboard-options "$TEST_XKBOPTIONS"
}

function get_codenames {

  local LAST_VERSIONS_COUNT

  LAST_VERSIONS_COUNT="$1"

  wget -qO - 'http://archive.ubuntu.com/ubuntu/dists/' |
    sed 's/<[^>]*>/ /g' |
    grep -E '^\s*[a-z]+/' |
    sed -n -e 's/^[[:space:]]*\([a-z]\+\)\/[[:space:]]\+\([0-9]\+\).*$/\1 \2/p' |
    grep -vE '^devel\s' |
    sort -nrk 2 |
    cut -d ' ' -f 1 |
    xargs -I% ls -1 /usr/share/debootstrap/scripts/% 2> /dev/null |
    grep -oE '[a-z]+$' |
    head -"$LAST_VERSIONS_COUNT"
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
    sfdisk "$IMAGE" < "$SELF_DIR/sfdisk.txt"

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
