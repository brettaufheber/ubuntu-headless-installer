#!/bin/bash

function main {

  # declare local variables
  local TASK
  local LONG_OPTIONS
  local OPTIONS_PARSED

  # set default values and configuration
  HOME="/tmp"
  SELF_PATH="$(readlink -f "$0")"
  SELF_NAME="$(basename "$SELF_PATH")"
  NAME_REGEX='^[a-z][-a-z0-9]*$'
  EXTRA_GROUPS='adm audio cdrom dialout dip docker floppy libvirt lpadmin plugdev scanner sudo users video wireshark'
  SHOW_HELP=false
  SHELL_LOGIN=false
  USE_EFI=false
  USE_SEPARATE_HOME=false
  COPY_NETWORK_SETTINGS=false

  # get settings from a dot-env file if available
  [[ -f ".env" ]] && source ".env"

  #define long options
  LONG_OPTIONS='help,login,efi,separate-home,copy-network-settings'
  LONG_OPTIONS="$LONG_OPTIONS"',username:,hostname:,codename:,dev-root:,dev-home:,dev-boot:'
  LONG_OPTIONS="$LONG_OPTIONS"',bundles:,bundles-file:,debconf-file:,dconf-file:'
  LONG_OPTIONS="$LONG_OPTIONS"',mirror:,locales:,time-zone:,user-gecos:,password:'
  LONG_OPTIONS="$LONG_OPTIONS"',keyboard-model:,keyboard-layout:,keyboard-variant:,keyboard-options:'

  # parse arguments
  OPTIONS_PARSED=$(
    getopt \
      --options 'hlesku:n:c:x:y:z:b:' \
      --longoptions "$LONG_OPTIONS" \
      --name "$SELF_NAME" \
      -- "$@"
  )

  # replace arguments
  eval set -- "$OPTIONS_PARSED"

  # apply arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      SHOW_HELP=true
      shift 1
      ;;
    -l | --login)
      SHELL_LOGIN=true
      shift 1
      ;;
    -e | --efi)
      USE_EFI=true
      shift 1
      ;;
    -s | --separate-home)
      USE_SEPARATE_HOME=true
      shift 1
      ;;
    -k | --copy-network-settings)
      COPY_NETWORK_SETTINGS=true
      shift 1
      ;;
    -u | --username)
      USERNAME_NEW="$2"
      shift 2
      ;;
    -n | --hostname)
      HOSTNAME_NEW="$2"
      shift 2
      ;;
    -c | --codename)
      CODENAME="$2"
      shift 2
      ;;
    -x | --dev-root)
      DEV_ROOT="$2"
      shift 2
      ;;
    -y | --dev-home)
      DEV_HOME="$2"
      shift 2
      ;;
    -z | --dev-boot)
      DEV_BOOT="$2"
      shift 2
      ;;
    -b | --bundles)
      BUNDLES="$2"
      shift 2
      ;;
    --bundles-file)
      BUNDLES_FILE="$2"
      shift 2
      ;;
    --debconf-file)
      DEBCONF_FILE="$2"
      shift 2
      ;;
    --dconf-file)
      DCONF_FILE="$2"
      shift 2
      ;;
    --mirror)
      MIRROR="$2"
      shift 2
      ;;
    --locales)
      LOCALES="$2"
      shift 2
      ;;
    --time-zone)
      TZ="$2"
      shift 2
      ;;
    --user-gecos)
      USER_GECOS="$2"
      shift 2
      ;;
    --password)
      PASSWORD="$2"
      shift 2
      ;;
    --keyboard-model)
      XKBMODEL="$2"
      shift 2
      ;;
    --keyboard-layout)
      XKBLAYOUT="$2"
      shift 2
      ;;
    --keyboard-variant)
      XKBVARIANT="$2"
      shift 2
      ;;
    --keyboard-options)
      XKBOPTIONS="$2"
      shift 2
      ;;
    --)
      shift 1
      break
      ;;
    *)
      break
      ;;
    esac
  done

  # either print the help text or process task
  if "$SHOW_HELP"; then
    # show help text
    show_help
  else

    # check if there is a unassigned argument to interpret it as task
    if [[ $# -eq 0 ]]; then
      echo "$SELF_NAME: require a task to continue" >&2
      exit 1
    fi

    # assign the task
    TASK="$1"
    shift 1

    # check if there is no unassigned argument left
    if [[ $# -ne 0 ]]; then
      echo "$SELF_NAME: cannot handle unassigned arguments: $*" >&2
      exit 1
    fi

    # select task
    case "$TASK" in
    create-user)
      task_create_user
      ;;
    modify-user)
      task_modify_user
      ;;
    manage-package-sources)
      task_manage_package_sources
      ;;
    install-packages-base)
      task_install_packages_base
      ;;
    install-packages-system-minimal)
      task_install_packages_system_minimal
      ;;
    install-packages-container-image-minimal)
      task_install_packages_container_image_minimal
      ;;
    install-system)
      task_install_system
      ;;
    install-lxc-image)
      task_install_lxc_image
      ;;
    install-docker-image)
      task_install_docker_image
      ;;
    configure-locales)
      task_configure_locales
      ;;
    configure-tzdata)
      task_configure_tzdata
      ;;
    configure-keyboard)
      task_configure_keyboard
      ;;
    configure-tools)
      task_configure_tools
      ;;
    *)
      echo "$SELF_NAME: require a valid task" >&2
      exit 1
      ;;
    esac
  fi
}

function verify_root_privileges {

  if [[ $EUID -ne 0 ]]; then
    echo "$SELF_NAME: require root privileges" >&2
    exit 1
  fi
}

function verify_username {

  if [[ -n "${USERNAME_NEW:-}" ]]; then
    if ! echo "$USERNAME_NEW" | grep -qE "$NAME_REGEX"; then
      echo "$SELF_NAME: require username that matches regular expression $NAME_REGEX" >&2
      exit 1
    fi
  else
    # by default, use the name of the user who runs the script
    USERNAME_NEW="$(get_username)"
  fi

  # make sure the username is different to root
  if [[ "${USERNAME_NEW:-}" == "root" ]]; then
    echo "$SELF_NAME: require username different to root" >&2
    exit 1
  fi
}

function verify_username_exists {

  if getent passwd "${USERNAME_NEW:-}" >/dev/null; then
    if ! "$1"; then
      echo "$SELF_NAME: the username has already been taken" >&2
      exit 1
    fi
  else
    if "$1"; then
      echo "$SELF_NAME: the username does not exist" >&2
      exit 1
    fi
  fi
}

function verify_hostname {

  # by default, use the hostname of the running system
  if [[ -z "${HOSTNAME_NEW:-}" ]]; then
    HOSTNAME_NEW="$HOSTNAME"
  fi
}

function verify_codename {

  if [[ -z "${CODENAME:-}" ]] || ! echo "${CODENAME:-}" | grep -qE '^[a-z]+$'; then
    echo "$SELF_NAME: require valid Ubuntu codename" >&2
    exit 1
  fi
}

function verify_mounting_root {

  # the block device file for "/" must exist and be unmounted
  if [[ -z "${DEV_ROOT:-}" ]] || [[ ! -b "${DEV_ROOT:-}" ]] || mount | grep -q "${DEV_ROOT:-}"; then
    echo "$SELF_NAME: require unmounted device file for /" >&2
    exit 1
  fi
}

function verify_mounting_home {

  # only perform checks if a separate home partition is used
  if "$USE_SEPARATE_HOME"; then
    # the block device file for "/home" must exist
    if [[ -z "${DEV_HOME:-}" ]] || [[ ! -b "${DEV_HOME:-}" ]]; then
      echo "$SELF_NAME: require device file for /home" >&2
      exit 1
    fi
  fi
}

function verify_mounting_boot {

  if "$USE_EFI"; then

    # use mounted UEFI partition by default
    if [[ -z "${DEV_BOOT:-}" ]]; then
      DEV_BOOT="$(cat /proc/mounts | grep -E /boot/efi | cut -d ' ' -f 1)"
    fi

    # the block device file for /boot/efi must exist
    if [[ -z "${DEV_BOOT:-}" ]] || [[ ! -b "${DEV_BOOT:-}" ]]; then
      echo "$SELF_NAME: require device file for /boot/efi" >&2
      exit 1
    fi

  else

    # the block device file for GRUB installation must exist
    if [[ -z "${DEV_BOOT:-}" ]] || [[ ! -b "${DEV_BOOT:-}" ]]; then
      echo "$SELF_NAME: require device file for GRUB installation" >&2
      exit 1
    fi
  fi
}

function task_create_user {

  # verify preconditions
  verify_root_privileges
  verify_username
  verify_username_exists false

  # create user and home-directory if not exist
  if [[ -n "${PASSWORD:-}" ]]; then
    adduser --add_extra_groups --disabled-password --gecos "${USER_GECOS:-}" "$USERNAME_NEW"
    usermod --password "$PASSWORD" "$USERNAME_NEW"
  else
    adduser --add_extra_groups --gecos "${USER_GECOS:-}" "$USERNAME_NEW"
  fi
}

function task_modify_user {

  # verify preconditions
  verify_root_privileges
  verify_username
  verify_username_exists true

  # create home-directory if not exist
  mkhomedir_helper "$USERNAME_NEW"

  # add user to extra groups
  for i in $EXTRA_GROUPS; do
    if grep -qE "^$i:" /etc/group; then
      usermod -aG "$i" "$USERNAME_NEW"
    fi
  done
}

function task_manage_package_sources {

  # declare local variables
  local TRUSTED_GPG
  local SOURCES_LIST
  local PREFERENCES
  local COMPONENTS

  # verify preconditions
  verify_root_privileges

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
  echo 'Package: *' >"$PREFERENCES/mozilla-firefox"
  echo 'Pin: release o=LP-PPA-mozillateam' >>"$PREFERENCES/mozilla-firefox"
  echo 'Pin-Priority: 601' >>"$PREFERENCES/mozilla-firefox"

  # update package lists
  apt-get update
}

function task_install_packages_base {

  # verify preconditions
  verify_root_privileges

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

  # install version control system
  apt-get -y install git

  # install text editors and query tools
  apt-get -y install vim
  apt-get -y install emacs-nox
  apt-get -y install nano
  apt-get -y install jq

  # install archiving and compression tools
  apt-get -y install tar gzip bzip2 zip unzip p7zip

  # install SSH support
  apt-get -y install openssh-server openssh-client

  # install SSL support
  apt-get -y install openssl

  # install GnuPG
  apt-get -y install gnupg

  # install support of snap packages
  apt-get -y install snapd

  # install OpenJDK JRE (headless)
  apt-get -y install openjdk-11-jre-headless

  # install everything else needed by a simple general purpose system
  aptitude -y install ~pstandard ~pimportant ~prequired

  # pre-seed the debconf database
  configure_debconf

  # install additional software
  install_bundles
}

function configure_debconf {

  local FILE

  FILE="${DEBCONF_FILE:-"/var/local/ubuntu-headless-installer/debconf.txt"}"

  # set default values for packages
  debconf-set-selections "$FILE"
}

function install_bundles {

  local FILE
  local LINE
  local CATEGORY_PATTERN
  local CATEGORY_MAIN
  local CATEGORY_SUB
  local SYSLANG
  local INDEX
  local BARRAY
  local INSTALL_GRANTED

  FILE="${BUNDLES_FILE:-"/var/local/ubuntu-headless-installer/bundles.txt"}"
  CATEGORY_PATTERN="^\[([a-z0-9_]+)(:([a-z0-9_]+))?\]$"
  INSTALL_GRANTED=false

  source /etc/default/locale
  SYSLANG="$(echo "$LANG" | grep -oE '^([a-zA-Z]+)' | sed -r 's/^(C|POSIX)$/en/')"
  SYSLANG="${SYSLANG:-'en'}"

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
  done <"$FILE"
}

function task_install_packages_system_minimal {

  # verify preconditions
  verify_root_privileges
  verify_mounting_boot

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

  # install GRUB bootloader
  if "$USE_EFI"; then
    apt-get -y install grub-efi
    grub-install --target=x86_64-efi --efi-directory=/boot/efi
    echo 'The boot order must be adjusted manually using the efibootmgr tool.'
  else
    apt-get -y install grub-pc
    grub-install "$DEV_BOOT"
  fi

  # install Linux kernel
  apt-get -y install linux-generic

  # set GRUB_CMDLINE_LINUX_DEFAULT
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet noplymouth"/' /etc/default/grub

  # apply grub configuration changes
  update-grub
}

function task_install_packages_container_image_minimal {

  # verify preconditions
  verify_root_privileges

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

  # install init scripts for cloud instances
  apt-get -y install cloud-init
}

function task_install_system {

  # verify preconditions
  verify_root_privileges
  verify_username
  verify_hostname
  verify_codename
  verify_mounting_root
  verify_mounting_home
  verify_mounting_boot

  # format $DEV_ROOT
  mkfs.ext4 "$DEV_ROOT"

  # mount "/", "/home" and "/boot/efi"
  mounting_step_1

  # execute debootstrap
  install_minimal_system

  # configuration before starting chroot
  configure_hosts
  configure_fstab
  configure_users
  configure_network

  # mount OS resources into chroot environment
  mounting_step_2

  # install basic tools, kernel and bootloader
  if "$USE_EFI"; then
    chroot "$CHROOT" "$SELF_NAME" install-packages-system-minimal --efi
  else
    chroot "$CHROOT" "$SELF_NAME" install-packages-system-minimal --dev-boot "$DEV_BOOT"
  fi

  # configure packages
  chroot "$CHROOT" "$SELF_NAME" configure-locales --locales "${LOCALES:-}"
  chroot "$CHROOT" "$SELF_NAME" configure-tzdata --time-zone "${TZ:-}"
  chroot "$CHROOT" "$SELF_NAME" configure-keyboard \
    --keyboard-model "${XKBMODEL:-}" \
    --keyboard-layout "${XKBLAYOUT:-}" \
    --keyboard-variant "${XKBVARIANT:-}" \
    --keyboard-options "${XKBOPTIONS:-}"
  chroot "$CHROOT" "$SELF_NAME" configure-tools

  # manage package sources
  chroot "$CHROOT" "$SELF_NAME" manage-package-sources --mirror "${MIRROR:-}"

  # install software
  chroot "$CHROOT" "$SELF_NAME" install-packages-base \
    --bundles "${BUNDLES:-}" \
    --bundles-file "${BUNDLES_FILE:-}" \
    --debconf-file "${DEBCONF_FILE:-}"

  # do some modifications for desktop environments
  configure_desktop

  # remove retrieved package files
  chroot "$CHROOT" apt-get clean

  # create user
  chroot "$CHROOT" "$SELF_NAME" create-user \
    --username "$USERNAME_NEW" \
    --password "${PASSWORD:-}" \
    --user-gecos "${USER_GECOS:-}"

  # login to shell for diagnostic purposes
  if "$SHELL_LOGIN"; then
    echo "$SELF_NAME: You are now logged in to the chroot environment for diagnostic purposes. Press Ctrl-D to escape."
    chroot "$CHROOT" /bin/bash
  fi

  # unmount everything
  unmounting_step_2
  unmounting_step_1

  # show that we are done here
  echo "$SELF_NAME: done."
}

function task_install_lxc_image {

  # declare local variables
  local TEMP_DIR
  local IMAGE_RELEASE
  local IMAGE_NAME

  # verify preconditions
  verify_root_privileges
  verify_codename

  # create temporary directory
  TEMP_DIR="$(mktemp -d)"

  # set root directory
  CHROOT="$TEMP_DIR/rootfs"

  # create root directory
  mkdir -p "$CHROOT"

  # execute debootstrap
  install_minimal_system

  # configuration before starting chroot
  configure_users

  # mount OS resources into chroot environment
  mounting_step_2

  # install basic tools
  chroot "$CHROOT" "$SELF_NAME" install-packages-container-image-minimal

  # configure packages
  chroot "$CHROOT" "$SELF_NAME" configure-locales --locales "${LOCALES:-C.UTF-8}"
  chroot "$CHROOT" "$SELF_NAME" configure-tzdata --time-zone "${TZ:-UTC}"
  chroot "$CHROOT" "$SELF_NAME" configure-tools

  # manage package sources
  chroot "$CHROOT" "$SELF_NAME" manage-package-sources --mirror "${MIRROR:-}"

  # install software
  chroot "$CHROOT" "$SELF_NAME" install-packages-base \
    --bundles "${BUNDLES:-}" \
    --bundles-file "${BUNDLES_FILE:-}" \
    --debconf-file "${DEBCONF_FILE:-}"

  # do some modifications for desktop environments
  configure_desktop

  # remove retrieved package files
  chroot "$CHROOT" apt-get clean

  # unmount everything
  unmounting_step_2

  # define image name
  IMAGE_RELEASE="$(cat '/proc/sys/kernel/random/uuid' | tr -dc '[:alnum:]')"
  IMAGE_NAME="custom-ubuntu/$CODENAME-$IMAGE_RELEASE"

  # create metadata file
  {
    echo "architecture: x86_64"
    echo "creation_date: $(date +%s)"
    echo "properties:"
    echo "  architecture: x86_64"
    echo "  description: Ubuntu $CODENAME with extended tooling"
    echo "  os: ubuntu"
    echo "  release: $CODENAME $IMAGE_RELEASE"
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
  } >"$TEMP_DIR/metadata.yaml"

  # create template directory
  mkdir "$TEMP_DIR/templates"

  # create templates (use container name as hostname)
  configure_hosts_template "{{ container.name }}" "$TEMP_DIR/templates/hostname.tpl" "$TEMP_DIR/templates/hosts.tpl"

  # create tarballs for rootfs and metadata
  tar -czf "$TEMP_DIR/rootfs.tar.gz" -C "$CHROOT" .
  tar -czf "$TEMP_DIR/metadata.tar.gz" -C "$TEMP_DIR" 'metadata.yaml' 'templates'

  # install image
  lxc image import "$TEMP_DIR/metadata.tar.gz" "$TEMP_DIR/rootfs.tar.gz" --alias "$IMAGE_NAME"

  # remove temporary directory
  rm -rf "$TEMP_DIR"

  # show that we are done here
  echo "$SELF_NAME: LXC image $IMAGE_NAME imported"
}

function task_install_docker_image {

  # declare local variables
  local TEMP_DIR
  local IMAGE_RELEASE
  local IMAGE_NAME
  local CONTAINER_CMD

  # verify preconditions
  verify_root_privileges
  verify_codename

  # create temporary directory
  TEMP_DIR="$(mktemp -d)"

  # set root directory
  CHROOT="$TEMP_DIR/rootfs"

  # create root directory
  mkdir -p "$CHROOT"

  # execute debootstrap
  install_minimal_system

  # configuration before starting chroot
  configure_users

  # mount OS resources into chroot environment
  mounting_step_2

  # install basic tools
  chroot "$CHROOT" "$SELF_NAME" install-packages-container-image-minimal

  # configure packages
  chroot "$CHROOT" "$SELF_NAME" configure-locales --locales "${LOCALES:-C.UTF-8}"
  chroot "$CHROOT" "$SELF_NAME" configure-tzdata --time-zone "${TZ:-UTC}"
  chroot "$CHROOT" "$SELF_NAME" configure-tools

  # manage package sources
  chroot "$CHROOT" "$SELF_NAME" manage-package-sources --mirror "${MIRROR:-}"

  # install software
  chroot "$CHROOT" "$SELF_NAME" install-packages-base \
    --bundles "${BUNDLES:-}" \
    --bundles-file "${BUNDLES_FILE:-}" \
    --debconf-file "${DEBCONF_FILE:-}"

  # do some modifications for desktop environments
  configure_desktop

  # remove retrieved package files
  chroot "$CHROOT" apt-get clean

  # unmount everything
  unmounting_step_2

  # define image name
  IMAGE_RELEASE="$(cat '/proc/sys/kernel/random/uuid' | tr -dc '[:alnum:]')"
  IMAGE_NAME="custom/ubuntu:$CODENAME-$IMAGE_RELEASE"

  if command -v docker &>/dev/null; then
    CONTAINER_CMD="docker"
  elif command -v podman &>/dev/null; then
    CONTAINER_CMD="podman"
  else
    echo "$SELF_NAME: missing container tooling" >&2
    exit 1
  fi

  # install image
  tar -cC "$CHROOT" . | "$CONTAINER_CMD" import - "$IMAGE_NAME"

  # remove temporary directory
  rm -rf "$TEMP_DIR"

  # show that we are done here
  echo "$SELF_NAME: Docker image $IMAGE_NAME imported"
}

function task_configure_locales {

  # declare local variables
  local LOCALES_LIST
  local PRIMARY_LOCAL

  # verify preconditions
  verify_root_privileges

  if [[ -n "${LOCALES:-}" ]]; then

    LOCALES_LIST="$(echo "$LOCALES" | tr ',' ' ')"
    PRIMARY_LOCAL="$(echo "$LOCALES_LIST" | cut -d ' ' -f 1)"

    for i in $LOCALES_LIST; do
      if [[ "$i" != "POSIX" ]] && [[ "$i" != "C" ]] && [[ "$i" != "C."* ]]; then
        # generate a locale for each entry in list
        locale-gen "$i"
      fi
    done

    export LANG="$PRIMARY_LOCAL"
    export LANGUAGE=""
    export LC_CTYPE="$PRIMARY_LOCAL"
    export LC_NUMERIC="$PRIMARY_LOCAL"
    export LC_TIME="$PRIMARY_LOCAL"
    export LC_COLLATE="$PRIMARY_LOCAL"
    export LC_MONETARY="$PRIMARY_LOCAL"
    export LC_MESSAGES="POSIX"
    export LC_PAPER="$PRIMARY_LOCAL"
    export LC_NAME="$PRIMARY_LOCAL"
    export LC_ADDRESS="$PRIMARY_LOCAL"
    export LC_TELEPHONE="$PRIMARY_LOCAL"
    export LC_MEASUREMENT="$PRIMARY_LOCAL"
    export LC_IDENTIFICATION="$PRIMARY_LOCAL"
    export LC_ALL=""

    # the first locale defined in the list will be installed
    dpkg-reconfigure --frontend noninteractive locales

  else
    # interactive configuration by user
    dpkg-reconfigure locales
  fi
}

function task_configure_tzdata {

  # verify preconditions
  verify_root_privileges

  if [[ -n "${TZ:-}" ]]; then
    # set preconfigured time zone
    ln -fs "/usr/share/zoneinfo/$TZ" /etc/localtime && dpkg-reconfigure --frontend noninteractive tzdata
  else
    # interactive configuration by user
    dpkg-reconfigure tzdata
  fi
}

function task_configure_keyboard {

  # declare local variables
  local FILE

  # verify preconditions
  verify_root_privileges

  # set path for output file
  FILE="/etc/default/keyboard"

  if [[ -n "${XKBMODEL:-}" ]]; then
    sed -i 's/^XKBMODEL=.*/XKBMODEL="'"$XKBMODEL"'"/' "$FILE"
  fi

  if [[ -n "${XKBLAYOUT:-}" ]]; then
    sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="'"$XKBLAYOUT"'"/' "$FILE"
  fi

  if [[ -n "${XKBVARIANT:-}" ]]; then
    sed -i 's/^XKBVARIANT=.*/XKBVARIANT="'"$XKBVARIANT"'"/' "$FILE"
  fi

  if [[ -n "${XKBOPTIONS:-}" ]]; then
    sed -i 's/^XKBOPTIONS=.*/XKBOPTIONS="'"$XKBOPTIONS"'"/' "$FILE"
  fi

  if [[ -n "${XKBMODEL:-}" ]] ||
    [[ -n "${XKBLAYOUT:-}" ]] ||
    [[ -n "${XKBVARIANT:-}" ]] ||
    [[ -n "${XKBOPTIONS:-}" ]]; then

    # set preconfigured keyboard layout
    dpkg-reconfigure --frontend noninteractive keyboard-configuration

  else
    # interactive configuration by user
    dpkg-reconfigure keyboard-configuration
  fi
}

function task_configure_tools {

  # declare local variables
  local FILE_VIMRC
  local FILE_BASHRC
  local COMPLETION_SCRIPT

  # verify preconditions
  verify_root_privileges

  # set paths for output files
  FILE_VIMRC="/etc/vim/vimrc"
  FILE_BASHRC="/etc/bash.bashrc"

  # add vim settings
  cat >>"$FILE_VIMRC" <<'EOF'

filetype plugin indent on
syntax on
set nocp
set background=light
set tabstop=4
set shiftwidth=4
set expandtab

EOF

  # enable bash history search completion
  cat >>"$FILE_BASHRC" <<'EOF'

# enable bash history search completion
if [[ $- == *i* ]]; then
  bind '"\e[A": history-search-backward'
  bind '"\e[B": history-search-forward'
fi

EOF

  # get code for bash completion
  COMPLETION_SCRIPT="$(cat "$FILE_BASHRC" |
    sed -n '/# enable bash completion in interactive shells/,/^$/p' |
    sed '1,1d; $d' |
    cut -c 2-)"

  # enable bash completion
  echo "" >>"$FILE_BASHRC"
  echo "$COMPLETION_SCRIPT" >>"$FILE_BASHRC"
}

function configure_hosts {

  # configure hosts with default arguments
  configure_hosts_template "$HOSTNAME_NEW" "$CHROOT/etc/hostname" "$CHROOT/etc/hosts"
}

function configure_hosts_template {

  # declare local variables
  local HOSTNAME
  local FILE_HOSTNAME
  local FILE_HOSTS

  # set variables from arguments
  HOSTNAME="$1"
  FILE_HOSTNAME="$2"
  FILE_HOSTS="$3"

  # edit /etc/hostname
  echo "$HOSTNAME" >"$FILE_HOSTNAME"

  # edit /etc/hosts
  {
    echo "127.0.0.1   localhost"
    echo "127.0.1.1   $HOSTNAME"
    echo ""
    echo "# The following lines are desirable for IPv6 capable hosts"
    echo "::1         ip6-localhost ip6-loopback"
    echo "fe00::0     ip6-localnet"
    echo "ff00::0     ip6-mcastprefix"
    echo "ff02::1     ip6-allnodes"
    echo "ff02::2     ip6-allrouters"
    echo "ff02::3     ip6-allhosts"
  } >"$FILE_HOSTS"
}

function configure_fstab {

  # declare local variables
  local FILE
  local FILE_UEFI
  local UUID_ROOT
  local UUID_HOME
  local UUID_UEFI

  # set path for output file
  FILE="$CHROOT/etc/fstab"

  # get UUID of system partition
  UUID_ROOT="$(blkid -s UUID -o value "$DEV_ROOT")"

  if "$USE_EFI"; then
    # get UUID of UEFI partition
    UUID_UEFI="$(blkid -s UUID -o value "$DEV_BOOT")"
    # allows to write UEFI specific entry to fstab file
    FILE_UEFI="$FILE"
  else
    # an UUID is not needed in this case
    UUID_UEFI=""
    # discard UEFI specific entry
    FILE_UEFI="/dev/null"
  fi

  if "$USE_SEPARATE_HOME"; then
    # get UUID of home partition
    UUID_HOME="$(blkid -s UUID -o value "$DEV_HOME")"
    # allows to write home specific entry to fstab file
    FILE_HOME="$FILE"
  else
    # an UUID is not needed in this case
    UUID_HOME=""
    # discard home specific entry
    FILE_HOME="/dev/null"
  fi

  # edit /etc/fstab
  echo '# /etc/fstab' >"$FILE"
  echo '# <file system>     <mount point>     <type>     <options>                        <dump> <pass>' >>"$FILE"
  echo "UUID=$UUID_ROOT     /                 ext4       defaults,errors=remount-ro       0      1" >>"$FILE"
  echo "UUID=$UUID_UEFI     /boot/efi         vfat       defaults                         0      2" >>"$FILE_UEFI"
  echo "UUID=$UUID_HOME     /home             ext4       defaults                         0      2" >>"$FILE_HOME"
  echo "proc                /proc             proc       defaults                         0      0" >>"$FILE"
  echo "sys                 /sys              sysfs      defaults                         0      0" >>"$FILE"
  echo "tmpfs               /tmp              tmpfs      defaults,size=40%                0      0" >>"$FILE"
}

function configure_users {

  # declare local variables
  local FILE

  # set path for output file
  FILE="$CHROOT/etc/adduser.conf"

  # edit /etc/adduser.conf
  sed -i 's/^#EXTRA_GROUPS=.*/EXTRA_GROUPS="'"$EXTRA_GROUPS"'"/' "$FILE"
  sed -i 's/^#NAME_REGEX=.*/NAME_REGEX="'"$NAME_REGEX"'"/' "$FILE"
}

function configure_network {

  if "$COPY_NETWORK_SETTINGS"; then

    # set HTTP proxy
    if [[ -n "${http_proxy:-}" ]]; then
      echo "http_proxy=$http_proxy" >>"$CHROOT/etc/environment"
      echo "HTTP_PROXY=$http_proxy" >>"$CHROOT/etc/environment"
    fi

    # set HTTPS proxy
    if [[ -n "${https_proxy:-}" ]]; then
      echo "https_proxy=$https_proxy" >>"$CHROOT/etc/environment"
      echo "HTTPS_PROXY=$https_proxy" >>"$CHROOT/etc/environment"
    fi

    # set FTP proxy
    if [[ -n "${ftp_proxy:-}" ]]; then
      echo "ftp_proxy=$ftp_proxy" >>"$CHROOT/etc/environment"
      echo "FTP_PROXY=$ftp_proxy" >>"$CHROOT/etc/environment"
    fi

    # set all socks proxy
    if [[ -n "${all_proxy:-}" ]]; then
      echo "all_proxy=$all_proxy" >>"$CHROOT/etc/environment"
      echo "ALL_PROXY=$all_proxy" >>"$CHROOT/etc/environment"
    fi

    # set ignore-hosts
    if [[ -n "${no_proxy:-}" ]]; then
      echo "no_proxy=$no_proxy" >>"$CHROOT/etc/environment"
      echo "NO_PROXY=$no_proxy" >>"$CHROOT/etc/environment"
    fi

    # copy DNS settings
    if [[ -f '/etc/systemd/resolved.conf' ]]; then
      cp -f '/etc/systemd/resolved.conf' "$CHROOT/etc/systemd/resolved.conf"
    fi

    # copy connection settings (system without network-manager)
    if [[ -d '/etc/netplan' ]]; then
      mkdir -p "$CHROOT/etc/netplan"
      cp -rf '/etc/netplan/.' "$CHROOT/etc/netplan"
    fi

    # copy connection settings (system with network-manager)
    if [[ -d '/etc/NetworkManager/system-connections' ]]; then
      mkdir -p "$CHROOT/etc/NetworkManager/system-connections"
      cp -rf '/etc/NetworkManager/system-connections/.' "$CHROOT/etc/NetworkManager/system-connections"
    fi

    # https://bugs.launchpad.net/ubuntu/+source/network-manager/+bug/1638842
    if command -v nmcli &>/dev/null; then
      mkdir -p "$CHROOT/etc/NetworkManager/conf.d"
      touch "$CHROOT/etc/NetworkManager/conf.d/10-globally-managed-devices.conf"
    fi
  fi
}

function configure_desktop {

  # only apply if flatpak is installed
  if command -v flatpak &>/dev/null; then
    # add flatpak remote: flathub
    chroot "$CHROOT" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi

  # only apply if the gnome-shell is installed
  if command -v gnome-shell &>/dev/null; then
    # modify default GNOME settings
    install_default_gnome_settings
  fi
}

function install_minimal_system {

  # install minimal system without kernel or bootloader
  debootstrap --arch=amd64 "$CODENAME" "$CHROOT" 'http://archive.ubuntu.com/ubuntu'

  SBIN_DIR="$CHROOT/usr/local/sbin"
  VAR_DIR="$CHROOT/var/local/ubuntu-headless-installer"

  # make this script available
  cp -f "$SELF_PATH" "$SBIN_DIR"
  chmod a+x "$SBIN_DIR/$SELF_NAME"

  mkdir -p "$VAR_DIR"
  cp -v "${BUNDLES_FILE:-"/var/local/ubuntu-headless-installer/bundles.txt"}" "$VAR_DIR"
  cp -v "${DEBCONF_FILE:-"/var/local/ubuntu-headless-installer/debconf.txt"}" "$VAR_DIR"
  cp -v "${DCONF_FILE:-"/var/local/ubuntu-headless-installer/dconf.ini"}" "$VAR_DIR"
}

function install_default_gnome_settings {

  local FILE

  FILE="${DCONF_FILE:-"/var/local/ubuntu-headless-installer/dconf.ini"}"

  # create configuration directory
  mkdir -p "$CHROOT/etc/dconf/db/site.d/"

  # write default settings
  cp -v "$FILE" "$CHROOT/etc/dconf/db/site.d/defaults"

  # change dconf profile
  echo 'user-db:user' >>"$CHROOT/etc/dconf/profile/user"
  echo 'system-db:site' >>"$CHROOT/etc/dconf/profile/user"

  # update dconf inside chroot
  chroot "$CHROOT" dconf update
}

function show_help {

  # declare local variables
  local URL

  # set project website URL
  URL='https://github.com/brettaufheber/ubuntu-headless-installer#usage'

  # open default browser with project website
  echo "$SELF_NAME: for help, see the project website $URL"
  xdg-open "$URL" &>/dev/null
}

function get_username {

  # declare local variables
  local ORIGIN_USER
  local CURRENT_PID
  local CURRENT_USER
  local RESULT

  ORIGIN_USER="$USER"
  CURRENT_PID=$$
  CURRENT_USER=$ORIGIN_USER

  while [[ "$CURRENT_USER" == "root" && $CURRENT_PID -gt 0 ]]; do
    RESULT="$(ps -hp $CURRENT_PID -o user,ppid | sed 's/\s\s*/ /')"
    CURRENT_USER="$(echo "$RESULT" | cut -d ' ' -f 1)"
    CURRENT_PID="$(echo "$RESULT" | cut -d ' ' -f 2)"
  done

  getent passwd "$CURRENT_USER" | cut -d ':' -f 1
}

function stop_chroot_processes {

  for x in /proc/*/root; do
    if [[ "$(readlink $x)" =~ ^$CHROOT ]]; then
      kill -s TERM "$(basename "$(dirname "$x")")"
    fi
  done
}

function mounting_step_1 {

  # declare local variables
  local HOME_PATH

  # modify CLEANUP_MASK
  CLEANUP_MASK=$(($CLEANUP_MASK | 1))

  # set path to mounting point
  CHROOT="/mnt/ubuntu-$(cat '/proc/sys/kernel/random/uuid')"

  # mount $DEV_ROOT
  mkdir -p "$CHROOT"
  mount "$DEV_ROOT" "$CHROOT"

  if "$USE_EFI"; then

    # mount $DEV_BOOT
    if mount | grep -q "$DEV_BOOT"; then
      BOOT_PATH="$(df "$DEV_BOOT" | grep -oE '(/[[:alnum:]]+)+$' | head -1)"
      mkdir -p "$CHROOT/boot/efi"
      mount -o bind "$BOOT_PATH" "$CHROOT/boot/efi"
    else
      mkdir -p "$CHROOT/boot/efi"
      mount "$DEV_BOOT" "$CHROOT/boot/efi"
    fi
  fi

  if "$USE_SEPARATE_HOME"; then

    # mount $DEV_HOME
    if mount | grep -q "$DEV_HOME"; then
      HOME_PATH="$(df "$DEV_HOME" | grep -oE '(/[[:alnum:]]+)+$' | head -1)"
      mkdir -p "$CHROOT/home"
      mount -o bind "$HOME_PATH" "$CHROOT/home"
    else
      mkdir -p "$CHROOT/home"
      mount "$DEV_HOME" "$CHROOT/home"
    fi
  fi
}

function unmounting_step_1 {

  # check whether the step is required or not
  if [[ $(($CLEANUP_MASK & 1)) -ne 0 ]]; then

    # prepare unmount
    stop_chroot_processes
    sync

    if "$USE_EFI"; then
      umount -l "$CHROOT/boot/efi"
    fi

    if "$USE_SEPARATE_HOME"; then
      umount "$CHROOT/home"
    fi

    # unmount directory root
    umount "$CHROOT"
    rmdir "$CHROOT"

  fi
}

function mounting_step_2 {

  # declare local variables
  local BOOT_PATH

  # modify CLEANUP_MASK
  CLEANUP_MASK=$(($CLEANUP_MASK | 2))

  # flush the cache
  sync

  # mount resources needed for chroot
  mount -t proc /proc "$CHROOT/proc"
  mount -t sysfs /sys "$CHROOT/sys"
  mount -o bind /dev/ "$CHROOT/dev"
  mount -o bind /dev/pts "$CHROOT/dev/pts"
  mount -o bind /run "$CHROOT/run"
  mount -o bind /tmp "$CHROOT/tmp"
}

function unmounting_step_2 {

  # check whether the step is required or not
  if [[ $(($CLEANUP_MASK & 2)) -ne 0 ]]; then

    # prepare unmount
    stop_chroot_processes
    sync

    # unmount resources
    umount -l "$CHROOT/tmp"
    umount -l "$CHROOT/run"
    umount -l "$CHROOT/dev/pts"
    umount -l "$CHROOT/dev"
    umount -l "$CHROOT/sys"
    umount -l "$CHROOT/proc"
  fi
}

function error_trap {

  # cleanup
  unmounting_step_2
  unmounting_step_1

  echo "$SELF_NAME: script stopped caused by unexpected return code $1 at line $2" >&2
  exit 3
}

function interrupt_trap {

  # cleanup
  unmounting_step_2
  unmounting_step_1

  echo "$SELF_NAME: script interrupted by signal" >&2
  exit 2
}

set -euEo pipefail
CLEANUP_MASK=0
trap 'RC=$?; error_trap "$RC" "$LINENO"' ERR
trap 'interrupt_trap' INT
main "$@"
exit 0
