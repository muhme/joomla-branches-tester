#!/bin/bash
#
# clean.sh - delete all jbt_* Docker containers and the network joomla-branches-tester_default.
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

log 'Stop and remove Joomla Branches Tester Docker containers and network'
docker compose down
