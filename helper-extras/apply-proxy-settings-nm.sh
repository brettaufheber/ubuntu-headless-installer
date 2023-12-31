#!/bin/bash

function parse_uri {

  echo "$(python3 - << END

import sys
from urllib.parse import urlparse

result = urlparse('$1').$2
sys.stdout.write(str('' if result is None else result))

END
  )"
}

function parse_array {

  echo "$(python3 - << END

import sys

result = '$1'.split(',')
sys.stdout.write(str(result))

END
  )"
}

# disable proxy by default
gsettings set org.gnome.system.proxy mode "none"

# set HTTP proxy
if [ -n "$http_proxy" ]; then

  host="$(parse_uri "$http_proxy" 'hostname')"
  port="$(parse_uri "$http_proxy" 'port')"
  username="$(parse_uri "$http_proxy" 'username')"
  password="$(parse_uri "$http_proxy" 'password')"

  gsettings set org.gnome.system.proxy mode "manual"
  gsettings set org.gnome.system.proxy.http host "$host"
  gsettings set org.gnome.system.proxy.http port "$port"

  if [ -n "$username" ]; then

    gsettings set org.gnome.system.proxy.http use-authentication "true"
    gsettings set org.gnome.system.proxy.http authentication-user "$username"
    gsettings set org.gnome.system.proxy.http authentication-password "$password"

  else

    gsettings set org.gnome.system.proxy.http use-authentication "false"
    gsettings set org.gnome.system.proxy.http authentication-user ""
    gsettings set org.gnome.system.proxy.http authentication-password ""

  fi

fi

# set HTTPS proxy
if [ -n "$https_proxy" ]; then

  host="$(parse_uri "$https_proxy" 'hostname')"
  port="$(parse_uri "$https_proxy" 'port')"

  gsettings set org.gnome.system.proxy mode "manual"
  gsettings set org.gnome.system.proxy.https host "$host"
  gsettings set org.gnome.system.proxy.https port "$port"

fi

# set FTP proxy
if [ -n "$ftp_proxy" ]; then

  host="$(parse_uri "$ftp_proxy" 'hostname')"
  port="$(parse_uri "$ftp_proxy" 'port')"

  gsettings set org.gnome.system.proxy mode "manual"
  gsettings set org.gnome.system.proxy.ftp host "$host"
  gsettings set org.gnome.system.proxy.ftp port "$port"

fi

# set all socks proxy
if [ -n "$all_proxy" ]; then

  host="$(parse_uri "$all_proxy" 'hostname')"
  port="$(parse_uri "$all_proxy" 'port')"

  gsettings set org.gnome.system.proxy mode "manual"
  gsettings set org.gnome.system.proxy.socks host "$host"
  gsettings set org.gnome.system.proxy.socks port "$port"

fi

# set ignore-hosts
if [ -n "$no_proxy" ]; then

  hosts="$(parse_array "$no_proxy")"

  gsettings set org.gnome.system.proxy ignore-hosts "$hosts"

fi
