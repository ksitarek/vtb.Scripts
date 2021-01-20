#!/bin/bash

COMPOSE_FILE_PATH='./docker/docker-compose.infrastructure.yml';

. ./helpers/echo-helpers.sh

if [ ! -f $COMPOSE_FILE_PATH ]; then
    echo_warning "$COMPOSE_FILE_PATH could not be found."
fi

echo_separator
echo_info "Attempt to stop infrastructure"
echo_separator
echo_emptyline

docker-compose -f $COMPOSE_FILE_PATH down