#!/bin/bash

function build_docker_image {

  # declare local variables
  local CONTAINER_CMD
  local TEMP_DIR
  local IMAGE_RELEASE
  local IMAGE_NAME
  local IMAGE_LATEST

  if command -v docker &>/dev/null; then
    CONTAINER_CMD="docker"
  elif command -v podman &>/dev/null; then
    CONTAINER_CMD="podman"
  else
    echo "$SELF_NAME: missing container tooling" >&2
    exit 1
  fi

  # create temporary directory
  TEMP_DIR="$(mktemp -d)"

  # set root directory
  CHROOT="$TEMP_DIR/rootfs"

  # create root directory
  mkdir -p "$CHROOT"

  echo "$SELF_NAME: install the system temporarily in $CHROOT"

  # create a minimal system without kernel or bootloader
  run_debootstrap "$CHROOT" "$CODENAME"

  # make the installer usable inside chroot environment
  install_ubuntu_installer "${CHROOT}${DEFAULT_INSTALL_DIR}" "${CHROOT}/usr/local/sbin"

  # mount OS resources into chroot environment
  mount_os_resources

  # install minimal packages required to perform the next installation steps
  chroot "$CHROOT" ubuntu-installer install-packages-minimal

  # configure packages
  chroot "$CHROOT" ubuntu-installer configure-locales --locales "${LOCALES:-C.UTF-8}"
  chroot "$CHROOT" ubuntu-installer configure-tzdata --time-zone "${TIME_ZONE:-UTC}"
  chroot "$CHROOT" ubuntu-installer configure-tools

  # manage package sources
  chroot "$CHROOT" ubuntu-installer manage-package-sources --mirror "${MIRROR:-"http://archive.ubuntu.com/ubuntu"}"

  # install software
  chroot "$CHROOT" ubuntu-installer install-packages-base \
    --bundles "${BUNDLES:-}" \
    --bundles-file "${BUNDLES_FILE:-}" \
    --debconf-file "${DEBCONF_FILE:-}"

  # remove retrieved package files
  chroot "$CHROOT" apt-get clean

  # run post install command
  if [[ -n "${POST_INSTALL_CMD:-}" ]]; then
    chroot "$CHROOT" /bin/bash -euo pipefail -c "$POST_INSTALL_CMD"
  fi

  # unmount all bound OS resources
  unmount_os_resources

  # define image name
  IMAGE_RELEASE="$(cat '/proc/sys/kernel/random/uuid' | tr -dc '[:alnum:]')"
  IMAGE_NAME="custom/ubuntu:$CODENAME-$IMAGE_RELEASE"
  IMAGE_LATEST="custom/ubuntu:latest"

  # install image
  tar -cC "$CHROOT" . | "$CONTAINER_CMD" import - "$IMAGE_NAME"

  # tag the imported image as latest
  "$CONTAINER_CMD" tag "$IMAGE_NAME" "$IMAGE_LATEST"

  # remove temporary directory
  rm -rf "$TEMP_DIR"

  echo "$SELF_NAME: Docker image $IMAGE_NAME imported"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    HOME="/tmp"

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"
    source "$SELF_PROJECT_PATH/lib/mounting.sh"
    source "$SELF_PROJECT_PATH/lib/any-installation.sh"

    process_dotenv
    process_arguments "hc" "help,codename:,mirror:,bundles:,bundles-file:,debconf-file:,post-install-cmd:" "$@"

    # verify preconditions
    verify_root_privileges
    verify_codename
    verify_bundles_file
    verify_debconf_file

    build_docker_image
  }

  set -euEo pipefail
  trap 'RC=$?; error_trap "$RC" "$LINENO"' ERR
  trap 'interrupt_trap' INT
  main "$@"
  exit 0
fi
