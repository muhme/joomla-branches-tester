#!/bin/bash
#
# clean.sh - delete all jst_* docker containers
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-system-tests

source scripts/helper.sh

log 'Removing all joomla system test docker containers jst_*'
docker ps -a --format '{{.Names}}' | grep '^jst_' | xargs docker rm -f
