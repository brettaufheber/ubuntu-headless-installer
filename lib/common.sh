#!/bin/bash

DEFAULT_INSTALL_DIR="/opt/ubuntu-headless-installer"

function process_dotenv {

  # load environment variables from .env if available
  if [[ -f ".env" ]]; then
    source ".env"
  fi
}

function process_arguments {

  local SHORT_OPTS
  local LONG_OPTS
  local OPTS_PARSED
  local LONG_OPT
  local SHORT_OPT
  local OPT_INDEX
  local VAR_NAME
  local SHORT_OPTS_FOR_GETOPT
  local -a LONG_OPTS_ARR
  local -A LONG_OPT_TO_VAR
  local -A SHORT_TO_LONG_OPT

  # the first two arguments to this function are SHORT_OPTS and LONG_OPTS respectively
  SHORT_OPTS="$1"
  LONG_OPTS="$2"
  shift 2

  # split LONG_OPTIONS by commas into an array
  IFS=',' read -ra LONG_OPTS_ARR <<< "$LONG_OPTS"

  # initialize the associative arrays and the short-options string
  LONG_OPT_TO_VAR=()
  SHORT_TO_LONG_OPT=()
  SHORT_OPTS_FOR_GETOPT=""  # needed to build up the string of short options used by getopt

  # loop through each long option in LONG_OPTS_ARR
  for OPT_INDEX in "${!LONG_OPTS_ARR[@]}"; do
    LONG_OPT="${LONG_OPTS_ARR[$OPT_INDEX]}"
    VAR_NAME="${LONG_OPT%:}"  # remove trailing colon if it exists
    VAR_NAME="${VAR_NAME//-/_}"  # replace hyphens by underscores
    VAR_NAME="${VAR_NAME^^}"  # uppercase
    LONG_OPT_TO_VAR["$LONG_OPT"]="$VAR_NAME"  # map the long option string to the variable name
    if [[ $OPT_INDEX -lt ${#SHORT_OPTS} ]]; then  # only process if there is a short option related the the long option
      SHORT_OPT="${SHORT_OPTS:$OPT_INDEX:1}"
      SHORT_TO_LONG_OPT["${SHORT_OPT}"]="$LONG_OPT"  # map that short option to the current long option
      if [[ "$LONG_OPT" != *: ]]; then
        SHORT_OPTS_FOR_GETOPT+="${SHORT_OPT}"  # without colon it is a boolean flag
      else
        SHORT_OPTS_FOR_GETOPT+="${SHORT_OPT}:"  # with colon at the end a trailing argument is expected
      fi
    fi
    if [[ "$LONG_OPT" != *: ]]; then
      declare -g "$VAR_NAME=false"  # initialize all global variable which have the purpose to be used as a boolean flag
    fi
  done

  # use getopt to parse the actual command-line arguments
  OPTS_PARSED=$(
    getopt \
      --options "$SHORT_OPTS_FOR_GETOPT" \
      --longoptions "$LONG_OPTS" \
      --name "$SELF_NAME" \
      -- "$@"
  )

  # replace positional parameters with the parsed options
  eval set -- "$OPTS_PARSED"

  # process each option in the parsed list
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --)  # a double dash "--" by itself signals the end of options
        shift 1
        break
        ;;
      --*)  # any argument starting with "--" followed by characters is treated as a long option
        LONG_OPT="${1:2}"
        if [[ -v LONG_OPT_TO_VAR["$LONG_OPT"] ]]; then  # Is a defined long option with purpose of a boolean flag?
          declare -g "${LONG_OPT_TO_VAR["$LONG_OPT"]}=true"  # toggle boolean flag
          shift 1
        elif [[ -v LONG_OPT_TO_VAR["$LONG_OPT:"] ]]; then  # Is a defined long option with purpose of a key value pair?
          declare -g "${LONG_OPT_TO_VAR["$LONG_OPT:"]}=$2"  # declare variable: key=value
          shift 2
        else
          echo "$SELF_NAME: unrecognized long option $1" >&2
          exit 1
        fi
        ;;
      -*)  # any argument starting with a single "-" followed by something else is treated as a short option
        SHORT_OPT="${1:1}"
        if [[ -v SHORT_TO_LONG_OPT["$SHORT_OPT"] ]]; then  # check whether the short option is mapped to a long option
          LONG_OPT="${SHORT_TO_LONG_OPT["$SHORT_OPT"]}"
          VAR_NAME="${LONG_OPT_TO_VAR["$LONG_OPT"]}"
          if [[ "$LONG_OPT" != *: ]]; then  # Is a defined short option with purpose of a boolean flag?
            declare -g "$VAR_NAME=true"  # toggle boolean flag
            shift 1
          else  # Is a defined short option with purpose of a key value pair?
            declare -g "$VAR_NAME=$2"  # declare variable: key=value
            shift 2
          fi
        else
          echo "$SELF_NAME: unrecognized short option $1" >&2
          exit 1
        fi
        ;;
      *)  # anything else means it runs into a non-option argument. Break out.
        break
        ;;
    esac
  done

  # check whether there are any remaining (unhandled) positional arguments
  if [[ $# -ne 0 ]]; then
    echo "$SELF_NAME: cannot handle unassigned arguments: $*" >&2
    exit 1
  fi

  # either print the help text or process task
  if "$HELP"; then
    show_help "$(basename "$(readlink -f "${0}")" .sh)"
    exit 0
  fi
}

function show_help {

  # declare local variables
  local TASK
  local URL

  TASK="$1"
  URL="https://github.com/brettaufheber/ubuntu-headless-installer#$TASK"

  # open default browser with project website
  echo "$SELF_NAME: for help, see the project website $URL"

  if [[ -n "$DISPLAY" ]] && command -v xdg-open &>/dev/null; then
    xdg-open "$URL" &>/dev/null
  fi
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

function is_inside_chroot {

  local HOST_ROOT_INFO
  local INIT_ROOT_INFO

  HOST_ROOT_INFO="$(stat -c '%d:%i' "/")"
  INIT_ROOT_INFO="$(stat -c '%d:%i' "/proc/1/root")"

  if [[ "$HOST_ROOT_INFO" != "$INIT_ROOT_INFO" ]]; then
    return 0
  else
    return 1
  fi
}

function get_username_regex {

  if is_inside_chroot && [[ -f "/etc/adduser.conf" ]]; then
    source "/etc/adduser.conf"
  elif [[ -n "${CHROOT:-}" ]] && [[ -f "$CHROOT/etc/adduser.conf" ]]; then
    source "$CHROOT/etc/adduser.conf"
  fi

  # fallback
  if [[ -z "${NAME_REGEX:-}" ]]; then
    NAME_REGEX="^[a-z][-a-z0-9]*$"
  fi

  echo -n "$NAME_REGEX"
}

function get_extra_groups {

  if is_inside_chroot && [[ -f "/etc/adduser.conf" ]]; then
    source "/etc/adduser.conf"
  elif [[ -n "${CHROOT:-}" ]] && [[ -f "$CHROOT/etc/adduser.conf" ]]; then
    source "$CHROOT/etc/adduser.conf"
  fi

  # fallback
  if [[ -z "${EXTRA_GROUPS:-}" ]]; then
    EXTRA_GROUPS='adm audio docker libvirt lpadmin lxd scanner sudo users video wireshark'
  fi

  echo -n "$EXTRA_GROUPS"
}

function install_ubuntu_installer {

  local INSTALL_DIR
  local SBIN_DIR
  local REL_LINK_PATH

  INSTALL_DIR="${1:-"$DEFAULT_INSTALL_DIR"}"
  SBIN_DIR="${2:-"/usr/local/sbin"}"

  mkdir -p "$INSTALL_DIR"

  cp -v "$SELF_PROJECT_PATH/ubuntu-installer.sh" "$INSTALL_DIR"
  cp -rv "$SELF_PROJECT_PATH/tasks" "$INSTALL_DIR"
  cp -rv "$SELF_PROJECT_PATH/lib" "$INSTALL_DIR"
  cp -rv "$SELF_PROJECT_PATH/etc" "$INSTALL_DIR"

  chmod a+x "$INSTALL_DIR/ubuntu-installer.sh"
  REL_LINK_PATH="$(realpath --relative-to="$SBIN_DIR" "$INSTALL_DIR")"
  ln -sfn "$REL_LINK_PATH/ubuntu-installer.sh" "$SBIN_DIR/ubuntu-installer"
}
