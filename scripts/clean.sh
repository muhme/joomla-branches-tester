#!/bin/bash
#
# clean.sh - delete all jst_* docker containers and the network
#            (or user docker compose down)
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-system-tests

NETWORK_NAME="joomla-system-tests_default"

source scripts/helper.sh

log 'Remove following Joomla System Tests Docker containers'
docker ps -a --format '{{.Names}}' | grep '^jst_' | xargs -r docker rm -f

log 'Remove following Docker network'
if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  docker network rm "$NETWORK_NAME"
fi
