#!/bin/bash

# update via APT package manager
apt-get update
apt-get -y dist-upgrade
apt-get -y autoremove --purge

# update via Snappy package manager
snap refresh

# update via Flatpak package manager
flatpak -y update

# update helper scripts
ubuntu-installer.sh -t install-desktop-helpers

# update GDM theme
ubuntu-installer.sh -t install-gdm-theme

# update installer script AT THE END
ubuntu-installer.sh -t install-script
