#!/bin/bash

set -euo pipefail

# update via APT package manager
apt-get update
apt-get -y dist-upgrade
apt-get -y autoremove --purge

# update via Snappy package manager
if command -v snap &>/dev/null; then
  echo "Updating the system via Snap..."
  snap refresh
fi

# update via Flatpak package manager
if command -v flatpak &>/dev/null; then
  echo "Updating the system via Flatpak..."
  flatpak -y update
fi

echo "System update completed"

exit 0
