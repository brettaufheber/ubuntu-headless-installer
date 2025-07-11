#!/bin/bash

function build_lxc_image {

  # declare local variables
  local TEMP_DIR
  local IMAGE_RELEASE
  local IMAGE_NAME
  local IMAGE_LATEST
  local IMAGE_FINGERPRINT

  # create temporary directory
  TEMP_DIR="$(mktemp -d)"

  # replace predefined root directory
  CHROOT="$TEMP_DIR/rootfs"

  # create root directory
  mkdir -p "$CHROOT"

  echo "$SELF_NAME: install the system temporarily in $CHROOT"

  # create a minimal system without kernel or bootloader
  debootstrap "--arch=$ARCH" "$CODENAME" "$CHROOT" "$MIRROR"

  # make the installer usable inside chroot environment
  install_ubuntu_installer "${CHROOT}${DEFAULT_INSTALL_DIR}" "${CHROOT}/usr/local/sbin"

  # configuration for adduser command
  configure_users

  # mount OS resources into chroot environment
  mount_os_resources

  # install minimal packages required to perform the next installation steps
  chroot "$CHROOT" ubuntu-installer install-packages-minimal

  # allow network access out of the box
  chroot "$CHROOT" apt-get -y install cloud-init

  # configure packages
  chroot "$CHROOT" ubuntu-installer configure-locales --locales "${LOCALES:-C.UTF-8}"
  chroot "$CHROOT" ubuntu-installer configure-tzdata --time-zone "${TIME_ZONE:-UTC}"
  chroot "$CHROOT" ubuntu-installer configure-tools

  # manage package sources
  chroot "$CHROOT" ubuntu-installer manage-package-sources --mirror "$MIRROR"

  # install software
  chroot "$CHROOT" ubuntu-installer install-packages-base --bundles "${BUNDLES:-}"

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

  # create metadata file
  {
    echo "architecture: x86_64"
    echo "creation_date: $(date +%s)"
    echo "properties:"
    echo "  architecture: x86_64"
    echo "  description: Ubuntu $CODENAME with extended tooling"
    echo "  os: ubuntu"
    echo "  release: $CODENAME $IMAGE_RELEASE"
    echo "profiles:"
    echo "  - default"
    echo "templates:"
    echo "  /etc/hosts:"
    echo "    when:"
    echo "      - create"
    echo "      - copy"
    echo "      - rename"
    echo "    template: hosts.tpl"
    echo "  /etc/hostname:"
    echo "    when:"
    echo "      - create"
    echo "      - copy"
    echo "      - rename"
    echo "    template: hostname.tpl"
  } > "$TEMP_DIR/metadata.yaml"

  # create template directory
  mkdir "$TEMP_DIR/templates"

  # create templates (use container name as hostname)
  configure_hosts_template "{{ container.name }}" "$TEMP_DIR/templates/hostname.tpl" "$TEMP_DIR/templates/hosts.tpl"

  # create tarballs for rootfs and metadata
  tar -czf "$TEMP_DIR/rootfs.tar.gz" -C "$CHROOT" .
  tar -czf "$TEMP_DIR/metadata.tar.gz" -C "$TEMP_DIR" 'metadata.yaml' 'templates'

  # remove 'latest' alias from older image
  if lxc image alias list --format csv | grep -qF "${IMAGE_LATEST},"; then
    echo "$SELF_NAME: alias $IMAGE_LATEST already exists; it will be removed to be available for the new image"
    lxc image alias delete "$IMAGE_LATEST"
  fi

  # install image
  lxc image import "$TEMP_DIR/metadata.tar.gz" "$TEMP_DIR/rootfs.tar.gz" --alias "$IMAGE_NAME"

  # retrieve the fingerprint of the newly imported image
  IMAGE_FINGERPRINT="$(lxc image info "$IMAGE_NAME" | sed -n 's/^Fingerprint: *//p')"

  # add the 'latest' alias pointing to the same image
  lxc image alias create "$IMAGE_LATEST" "$IMAGE_FINGERPRINT"

  # remove temporary directory
  rm -rf "$TEMP_DIR"

  echo "$SELF_NAME: LXC image $IMAGE_NAME imported"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  function main {

    HOME="/tmp"

    source "$SELF_PROJECT_PATH/lib/common.sh"
    source "$SELF_PROJECT_PATH/lib/verification.sh"
    source "$SELF_PROJECT_PATH/lib/mounting.sh"
    source "$SELF_PROJECT_PATH/lib/any-installation.sh"

    process_dotenv
    LONG_OPTIONS='help'
    LONG_OPTIONS="$LONG_OPTIONS"',codename:,arch:,mirror:'
    LONG_OPTIONS="$LONG_OPTIONS"',bundles:,bundles-file:,debconf-file:,post-install-cmd:'
    process_arguments "hc" "$LONG_OPTIONS" "$@"

    # verify preconditions
    verify_root_privileges
    verify_codename
    verify_architecture
    verify_mirror
    verify_bundles_file
    verify_debconf_file

    build_lxc_image
  }

  set -euEo pipefail
  trap 'RC=$?; error_trap "$RC" "$LINENO"' ERR
  trap 'interrupt_trap' INT
  main "$@"
  exit 0
fi
