#!/bin/bash

SVC_NAME=$1
PORT=$2
ORG_SLN_DIR="../vtb.${SVC_NAME}";
SLN_DIR=".tmp.vtb.${SVC_NAME}"

. ./helpers/echo-helpers.sh
. ./helpers/filesystem-helpers.sh

ensure_directory_exists $ORG_SLN_DIR "Could not found the directory of ${SVC_NAME}. This script is intended to use in such an environment, so that ${SVC_NAME} is in a relative path: ${ORG_SLN_DIR}."

echo_info "Found solution directory"

echo_info "Copying solution to temporary location: $(pwd)/.tmp.vtb.${SVC_NAME}"
echo_info "\t - source: \t ${ORG_SLN_DIR}"
echo_info "\t - dest: \t ${SLN_DIR}"

rm -rf $SLN_DIR
mkdir $SLN_DIR
rsync -aq --progress "${ORG_SLN_DIR}/" $SLN_DIR --exclude "**/bin/*" --exclude "**/obj/*" --exclude ".git" --exclude ".vs"

API_APP_DOCKERFILE="${SLN_DIR}/Dockerfile.API"
CONSOLE_APP_DOCKERFILE="${SLN_DIR}/Dockerfile.Service"

ensure_file_exists $API_APP_DOCKERFILE "Dockerfile ${API_APP_DOCKERFILE} could not be found."
ensure_file_exists $CONSOLE_APP_DOCKERFILE "Dockerfile ${CONSOLE_APP_DOCKERFILE} could not be found."
echo_info "Dockerfiles found"

API_APP_CSPROJ="${SLN_DIR}/vtb.${SVC_NAME}.Api/vtb.${SVC_NAME}.Api.csproj"
CONSOLE_APP_CSPROJ="${SLN_DIR}/vtb.${SVC_NAME}.Service/vtb.${SVC_NAME}.Service.csproj"

ensure_file_exists $API_APP_CSPROJ "Project file ${API_APP_CSPROJ} could not be found."
ensure_file_exists $CONSOLE_APP_CSPROJ "Project file ${CONSOLE_APP_CSPROJ} could not be found."
echo_info "Project files found"

API_IMAGE_NAME="$(echo $SVC_NAME | tr '[:upper:]' '[:lower:]')_api"
CONSOLE_IMAGE_NAME="$(echo $SVC_NAME | tr '[:upper:]' '[:lower:]')_service"
echo_info "Container names: ${API_IMAGE_NAME} and ${CONSOLE_IMAGE_NAME}"

function build_docker_image {
    CSPROJ_FILE=$1
    DOCKERFILE_NAME=$2
    IMAGE_NAME=$3
    OUT_DIR_NAME=$4

    # make sure we will have clean output
    rm -rf $OUT_DIR_NAME
    mkdir $OUT_DIR_NAME

    echo_info "Publishing ${CSPROJ_FILE} into ${OUT_DIR_NAME} directory."
    dotnet publish $CSPROJ_FILE --no-restore --no-build -c Release -o "${OUT_DIR_NAME}" --no-cache

    cd $OUT_DIR_NAME
    echo_info "Building dockerfile ${IMAGE_NAME}"
    (docker build . -f "../$DOCKERFILE_NAME" -t $IMAGE_NAME) #> /dev/null 2>&1
    cd ..

    rm -rf $OUT_DIR_NAME
}

API_OUT_DIR="$(pwd)/.out_${SVC_NAME}_api"
CONSOLE_OUT_DIR="$(pwd)/.out_${SVC_NAME}_service"

dotnet restore $SLN_DIR
dotnet build $SLN_DIR -c Release --no-restore

build_docker_image $API_APP_CSPROJ $API_APP_DOCKERFILE $API_IMAGE_NAME $API_OUT_DIR &
    build_docker_image $CONSOLE_APP_CSPROJ $CONSOLE_APP_DOCKERFILE $CONSOLE_IMAGE_NAME $CONSOLE_OUT_DIR
wait

function serve_service {
    echo_info "Running Service docker image ${CONSOLE_IMAGE_NAME}"
    docker run \
        --network "vtb_network" \
        --name $CONSOLE_IMAGE_NAME \
        --restart always \
        -e ASPNETCORE_ENVIRONMENT=Development \
        -d \
        $CONSOLE_IMAGE_NAME
} 

function serve_api {
    echo_info "Running API docker image ${API_IMAGE_NAME} with ${PORT} exposed"
    CERTS_ABS_PATH="$(pwd)/_certs"

    docker run \
        --network "vtb_network" \
        --name $API_IMAGE_NAME \
        --restart always \
        -p "${PORT}:443" \
        -e ASPNETCORE_ENVIRONMENT=dev-docker \
        -e ASPNETCORE_URLS="https://+;http://+" \
        -e ASPNETCORE_HTTPS_PORT=443 \
        -e ASPNETCORE_Kestrel__Certificates__Default__Path=/https/aspnetapp.pfx \
        -e ASPNETCORE_Kestrel__Certificates__Default__Password="pwd" \
        -v "${CERTS_ABS_PATH}:/https/" \
        -d \
        $API_IMAGE_NAME
}

rm -rf $SLN_DIR

(docker stop ${API_IMAGE_NAME} || true) > /dev/null 2>&1 &
(docker stop ${CONSOLE_IMAGE_NAME} || true) > /dev/null 2>&1
wait 

(docker rm ${API_IMAGE_NAME} || true) > /dev/null 2>&1 &
(docker rm ${CONSOLE_IMAGE_NAME} || true) > /dev/null 2>&1
wait

serve_service & serve_api
wait 