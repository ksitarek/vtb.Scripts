#!/bin/bash

COMPOSE_FILE_PATH='./docker/docker-compose.infrastructure.yml';

. ./helpers/echo-helpers.sh

if [ ! -f $COMPOSE_FILE_PATH ]; then
    echo_warning "$COMPOSE_FILE_PATH could not be found."
fi

echo_separator
echo_info "Attempt to start infrastructure"
echo_separator
echo_emptyline

echo_info "Clear previous infrastructure containers and network"
docker stop vtb_infra_mongo vtb_infra_rabbit
docker rm vtb_infra_mongo vtb_infra_rabbit
docker network rm vtb_network

echo_info "Create network"
docker network create --driver bridge vtb_network

echo_info "Run infrastructure containers"
docker run \
    -h "vtb_infra_rabbit" \
    --name "vtb_infra_rabbit" \
    --network "vtb_network" \
    -p "15672:15672" \
    -p "5672:5672" \
    -d \
    "rabbitmq:3-management" &

docker run \
    -h "vtb_infra_mongo" \
    --name "vtb_infra_mongo" \
    --network "vtb_network" \
    -p "27017:27017" \
    -d \
    "mongo:4.4" 

wait