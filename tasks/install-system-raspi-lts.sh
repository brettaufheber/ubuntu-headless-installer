#!/bin/bash

function install_system_raspi_lts {

  # define the root mount point for the image partitions
  IMAGE_ROOT="/mnt/ubuntu-raspi-image-$(cat '/proc/sys/kernel/random/uuid')"

  # create temporary directory
  TEMP_DIR="$(mktemp -d)"

  # download raspi image by the Ubuntu codename
  download_image

  # format $DEV_ROOT
  format_ext4 "$DEV_ROOT"

  # mount the image devices/partitions
  mount_image

  # mount target system devices/partitions
  mount_devices "${DEV_ROOT:-}" "" "$DEV_BOOT_FIRMWARE" "${DEV_HOME:-}"

  # copy OS files from the image to the target system
  copy_files_from_image

  # mount OS resources into chroot environment
  mount_os_resources

  # perform some fundamental configuration
  configure_boot
  configure_hosts
  configure_fstab "${DEV_ROOT:-}" "" "$DEV_BOOT_FIRMWARE" "${DEV_HOME:-}" "${TMP_SIZE:-}"
  configure_users

  # this allows to copy network settings from the host system; can help to perform a installation behind a proxy
  if "$COPY_NETWORK_SETTINGS"; then
    copy_network_settings
  fi

  # make the installer usable inside chroot environment
  install_ubuntu_installer "${CHROOT}${DEFAULT_INSTALL_DIR}" "${CHROOT}/usr/local/sbin"

  # install minimal packages required to perform the next installation steps
  chroot "$CHROOT" ubuntu-installer install-packages-minimal

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
  chroot "$CHROOT" ubuntu-installer user-modify \
    --add-extra-groups \
    --username-new "$USERNAME_NEW" \
    --username-old "pi" \
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
  mount_image

  # remove temporary directory
  rm -rf "$TEMP_DIR"

  echo "$SELF_NAME: done."
}

function mount_image {

  # set up a loop device for the image with partition scanning (-P option creates partition devices: p1, p2, ...)
  DEV_IMAGE=$(losetup -f --show -P "$TEMP_DIR/ubuntu-raspi.img")

  # mount the image partitions: p2 is assumed to be the root partition and p1 the boot partition
  mkdir -p "$IMAGE_ROOT"
  mount "${DEV_IMAGE}p2" "$IMAGE_ROOT"
  mkdir -p "$IMAGE_ROOT/boot/firmware"
  mount "${DEV_IMAGE}p1" "$IMAGE_ROOT/boot/firmware"
}

function unmount_image {

  mountpoint -q "$IMAGE_ROOT/boot/firmware" && umount "$IMAGE_ROOT/boot/firmware"
  mountpoint -q "$IMAGE_ROOT" && umount "$IMAGE_ROOT"

  # detach the loop device used for the image
  if [[ -n "${DEV_IMAGE:-}" ]]; then
    losetup -d "$DEV_IMAGE"
  fi
}

function copy_files_from_image {

  local SRC
  local DST
  local BACKUP
  local FILE
  local -a FILES

  # copy the root filesystem from the image to the target system partition
  rsync -aAXH --numeric-ids --devices --specials \
    --exclude='/boot/firmware/*' \
    --exclude='/proc/*' \
    --exclude='/sys/*' \
    --exclude='/dev/*' \
    --exclude='/run/*' \
    --exclude='/tmp/*' \
    --exclude='/mnt/*' \
    --exclude='/media/*' \
    --exclude='/lost+found' \
    "$IMAGE_ROOT"/ "$CHROOT"/

  # copy the boot partition files to /boot except the configuration files
  rsync -aAXH --numeric-ids --devices --specials \
    --delete \
    --exclude='config.txt' \
    --exclude='cmdline.txt' \
    "$IMAGE_ROOT/boot/firmware/" "$CHROOT/boot/firmware/"

  # copy the boot partition related .txt files only if they do not exist
  FILES=("config.txt" "cmdline.txt")
  for FILE in "${FILES[@]}"; do
    SRC="$IMAGE_ROOT/boot/firmware/$FILE"
    DST="$CHROOT/boot/firmware/$FILE"
    BACKUP="$CHROOT/boot/firmware/${FILE}.orig"
    if [ ! -f "$DST" ]; then
      cp -p "$SRC" "$DST"
    fi
    cp -p "$SRC" "$BACKUP"
  done
}

function configure_boot {

  # get information about partitions
  FS_TYPE_ROOT=$(blkid -o value -s TYPE "$DEV_ROOT")
  UUID_ROOT="$(blkid -s UUID -o value "$DEV_ROOT")"

  # set path for the configuration file
  FILE="$CHROOT/boot/firmware/cmdline.txt"

  # create the file if it does not exist
  if [ ! -f "$FILE" ]; then
    touch "$FILE"
  fi

  CMD=$(cat "$FILE")

  if echo "$CMD" | grep -qE '(^| )root='; then
    CMD=$(echo "$CMD" | sed -E "s#(^| )root=[^ ]*#root=UUID=$UUID_ROOT#")
  else
    CMD="$CMD root=UUID=$UUID_ROOT"
  fi

  if echo "$CMD" | grep -qE '(^| )rootfstype='; then
    CMD=$(echo "$CMD" | sed -E "s#(^| )rootfstype=[^ ]*#rootfstype=$FS_TYPE_ROOT#")
  else
    CMD="$CMD rootfstype=$FS_TYPE_ROOT"
  fi

  # write the updated content back to the file
  echo "$CMD" > "$FILE"
}

function download_image {

  local IMAGE_VERSION
  local IMAGE_URL

  curl --fail --silent --show-error --location "http://changelogs.ubuntu.com/meta-release-lts" -o "$TEMP_DIR/meta-release-lts"

  if ! cat "$TEMP_DIR/meta-release-lts" | grep -q "^Dist: $CODENAME\$"; then
    echo "$SELF_NAME: codename '$CODENAME' not found in meta-release-lts" >&2
    exit 1
  fi

  # retrieve the meta-release file and extract the version for the given codename
  IMAGE_VERSION="$(cat "$TEMP_DIR/meta-release-lts" | sed -n '/^Dist: '"$CODENAME"'/{n;n;s/^Version: //; s/ LTS$//; p;}')"

  # build the image URL using the retrieved version
  IMAGE_URL="https://cdimage.ubuntu.com/releases/$IMAGE_VERSION/release/ubuntu-$IMAGE_VERSION-preinstalled-server-$ARCH+raspi.img.xz"

 # download and decompress the image
  echo "The image is downloading. This may take a few minutes."
  curl --fail --silent --show-error --location "$IMAGE_URL" | unxz > "$TEMP_DIR/ubuntu-raspi.img"
}

function error_trap_plus {

  if [[ -n "${IMAGE_ROOT:-}" ]]; then
    unmount_image
  fi

   error_trap "$@"
}

function interrupt_trap_plus {

  if [[ -n "${IMAGE_ROOT:-}" ]]; then
    unmount_image
  fi

  interrupt_trap
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
    LONG_OPTIONS="$LONG_OPTIONS"',dev-root:,dev-boot-firmware:,dev-home:'
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
    verify_mounting_boot_firmware
    verify_mounting_home
    verify_bundles_file
    verify_debconf_file
    verify_dconf_file

    install_system_raspi_lts
  }

  set -euEo pipefail
  trap 'RC=$?; error_trap_plus "$RC" "$LINENO"' ERR
  trap 'interrupt_trap_plus' INT
  main "$@"
  exit 0
fi
