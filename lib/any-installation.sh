#!/bin/bash

function run_debootstrap {

  local TARGET_PATH
  local CODENAME
  local ARCH
  local URL

  TARGET_PATH="$1"
  CODENAME="$2"
  ARCH="${3:-"amd64"}"

  if [[ "$ARCH" == "amd64" ]]; then
    URL='http://archive.ubuntu.com/ubuntu'
  elif [[ "$ARCH" == "arm64" ]]; then
    URL='http://ports.ubuntu.com/ubuntu-ports'
  else
    echo "$SELF_NAME: unsupported architecture: $ARCH" >&2
    exit 4
  fi

  # install minimal system without kernel or bootloader
  debootstrap "--arch=$ARCH" "$CODENAME" "$TARGET_PATH" "$URL"
}

function configure_hosts {

  # configure hosts with default arguments
  configure_hosts_template "$HOSTNAME_NEW" "$CHROOT/etc/hostname" "$CHROOT/etc/hosts"
}

function configure_hosts_template {

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

function configure_users {

  local FILE

  # set path for output file
  FILE="$CHROOT/etc/adduser.conf"

  EXTRA_GROUPS="$(get_extra_groups)"
  NAME_REGEX="$(get_username_regex)"

  # edit /etc/adduser.conf
  sed -i 's/^#EXTRA_GROUPS=.*/EXTRA_GROUPS="'"$EXTRA_GROUPS"'"/' "$FILE"
  sed -i 's/^#NAME_REGEX=.*/NAME_REGEX="'"$NAME_REGEX"'"/' "$FILE"
}

function configure_desktop {

  local DCONF_FILE

  DCONF_FILE="$1"

  # only apply if flatpak is installed
  if chroot "$CHROOT" sh -c 'command -v flatpak' &> /dev/null; then
    # add flatpak remote: flathub
    chroot "$CHROOT" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi

  # only apply if the gnome-shell is installed
  if chroot "$CHROOT" sh -c 'command -v gnome-shell' &>/dev/null; then
    # modify default GNOME settings
    install_default_gnome_settings "$DCONF_FILE"
  fi
}

function install_default_gnome_settings {

  local DCONF_FILE

  DCONF_FILE="$1"

  # create configuration directory
  mkdir -p "$CHROOT/etc/dconf/db/site.d/"

  # write default settings
  cp -v "$DCONF_FILE" "$CHROOT/etc/dconf/db/site.d/defaults"

  # change dconf profile
  echo 'user-db:user' >>"$CHROOT/etc/dconf/profile/user"
  echo 'system-db:site' >>"$CHROOT/etc/dconf/profile/user"

  # update dconf inside $CHROOT
  chroot "$CHROOT" dconf update
}
