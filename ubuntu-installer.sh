#!/bin/bash

function main {

  local TASK

  SELF_PATH="$(readlink -f "${0}")"
  SELF_PROJECT_PATH="$(dirname "$SELF_PATH")"
  SELF_NAME="$(basename "$SELF_PATH")"

  export SELF_PATH
  export SELF_PROJECT_PATH
  export SELF_NAME

  if [[ $# -eq 0 ]]; then
    list_tasks
  else

    # assign the task
    TASK="$1"
    shift 1

    # check whether the task is valid
    if [[ ! -f "$SELF_PROJECT_PATH/tasks/${TASK}.sh" ]]; then
      echo "$SELF_NAME: incorrect task: $TASK" >&2
      exit 1
    fi

    # run task
    bash "$SELF_PROJECT_PATH/tasks/${TASK}.sh" "$@"
  fi
}

function list_tasks {

  local TASK_DIR
  local TASK_FILE
  local TASK_NAME

  TASK_DIR="$SELF_PROJECT_PATH/tasks"

  echo "Available tasks:"

  for TASK_FILE in "$TASK_DIR"/*.sh; do
    TASK_NAME=$(basename "$TASK_FILE" .sh)
    echo " * ${TASK_NAME}"
  done
}

set -euo pipefail
main "$@"
exit 0
