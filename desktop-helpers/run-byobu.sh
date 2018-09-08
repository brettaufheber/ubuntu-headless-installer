#!/bin/bash

if command -v byobu>/dev/null; then

  [[ ! $TERM =~ screen ]] && exec byobu

fi
