#!/bin/bash

function main {

  local TASK
  local CODENAME

  source "./.github/workflows/test.env"

  SELF_PATH="$(readlink -f "$0")"
  SELF_NAME="$(basename "$SELF_PATH")"

  if [[ $# -ne 2 ]]; then

    echo "$SELF_NAME: require arguments <task> <codename|ALL>" >&2
    exit 1

  fi

  TASK="$1"
  CODENAME="$2"
  IMAGE="./tmp/test.img"

  mkdir -p "./tmp"
  dd "if=/dev/zero" "of=$IMAGE" bs=1G count=10
  sfdisk "$IMAGE" < "./.github/workflows/test.sfdisk.txt"

  DEV_LOOP_IMAGE="$(losetup --show --find --partscan "$IMAGE")"
  DEV_LOOP_SYSTEM="$DEV_LOOP_IMAGE""p1"
  DEV_LOOP_HOME="$DEV_LOOP_IMAGE""p2"

  if [[ "$CODENAME" == "ALL" ]]; then

    for i in $(get_codenames); do

      install "$TASK" "$i"

    done

  else

    install "$TASK" "$CODENAME"

  fi
}

function install {

  local TASK
  local CODENAME

  TASK="$1"
  CODENAME="$2"

  echo "$SELF_NAME: installation with codename $CODENAME"

  mkfs.ext4 "$DEV_LOOP_HOME"

  ./ubuntu-installer.sh "$TASK" \
    --username "$TEST_USERNAME" \
    --hostname "$TEST_HOSTNAME" \
    --codename "$CODENAME" \
    --bundles "$TEST_BUNDLES" \
    --dev-root "$DEV_LOOP_SYSTEM" \
    --dev-home "$DEV_LOOP_HOME" \
    --dev-boot "$DEV_LOOP_IMAGE" \
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

  wget -qO - 'http://archive.ubuntu.com/ubuntu/dists/' |
    sed 's/<[^>]*>/ /g' |
    grep -E '^\s*[a-z]+/' |
    sed -n -e 's/^[[:space:]]*\([a-z]\+\)\/[[:space:]]\+\([0-9]\+\).*$/\1 \2/p' |
    grep -vE '^devel\s' |
    sort -nrk 2 |
    head -5 |
    cut -d ' ' -f 1
}

function cleanup {

  [[ -n "${DEV_LOOP_IMAGE:-}" ]] && losetup -d "$DEV_LOOP_IMAGE"
  [[ -f "$IMAGE" ]] && rm "$IMAGE"
}

function error_trap {

  cleanup

  echo "$SELF_NAME: script stopped caused by unexpected return code $1 at line $2" >&2
  exit 3
}

function interrupt_trap {

  cleanup

  echo "$SELF_NAME: script interrupted by signal" >&2
  exit 2
}

set -euEo pipefail
trap 'RC=$?; error_trap "$RC" "$LINENO"' ERR
trap 'interrupt_trap' INT
main "$@"
exit 0
