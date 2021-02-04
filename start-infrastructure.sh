#!/bin/bash

ABS_PATH="$(cd ~ && pwd -P)/.vtb-infra-volumes"

. ./helpers/filesystem-helpers.sh
. ./helpers/echo-helpers.sh

if ! directory_exists $1; then
    mkdir "$ABS_PATH"
    
    mkdir "$ABS_PATH/mssql"
    sudo chown 10001:0 "$ABS_PATH/mssql"
fi

echo_separator
echo_info "Attempt to start infrastructure"
echo_separator
echo_emptyline

echo_info "Clear previous infrastructure containers and network"
docker stop vtb_infra_mongo vtb_infra_rabbit vtb_infra_mssql
docker rm vtb_infra_mongo vtb_infra_rabbit vtb_infra_mssql
docker network rm vtb_network

echo_info "Create network"
docker network create --driver bridge vtb_network

echo_info "Run infrastructure containers"
docker run \
    -h "vtb_infra_rabbit" \
    --name "vtb_infra_rabbit" \
    --network "vtb_network" \
    --restart always \
    -v "${ABS_PATH}/rabbit:/var/lib/rabbitmq" \
    -p "15672:15672" \
    -p "5672:5672" \
    -d \
    "rabbitmq:3-management" &

docker run \
    -h "vtb_infra_mssql" \
    --name "vtb_infra_mssql" \
    --network "vtb_network" \
    --restart always \
    -v "${ABS_PATH}/mssql:/var/opt/mssql" \
    -e 'ACCEPT_EULA=Y' \
    -e 'SA_PASSWORD=Passw00rd' \
    -p 1455:1433 \
    -d \
    "mcr.microsoft.com/mssql/server" &

docker run \
    -h "vtb_infra_mongo" \
    --name "vtb_infra_mongo" \
    --network "vtb_network" \
    --restart always \
    -v "${ABS_PATH}/mongo:/data/db" \
    -p "27017:27017" \
    -d \
    "mongo:4.4" 

wait