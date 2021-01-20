#!/bin/bash

SVC_NAME=$1
PORT=$2
SLN_DIR="../vtb.${SVC_NAME}";


. ./helpers/echo-helpers.sh
. ./helpers/filesystem-helpers.sh

ensure_directory_exists $SLN_DIR "Could not found the directory of ${SVC_NAME}. This script is intended to use in such an environment, so that ${SVC_NAME} is in a relative path: ${SLN_DIR}."

echo_info "Found solution directory"

API_APP_DOCKERFILE="${SLN_DIR}/Dockerfile.API"
CONSOLE_APP_DOCKERFILE="${SLN_DIR}/Dockerfile.Service"

ensure_file_exists $API_APP_DOCKERFILE "Dockerfile ${API_APP_DOCKERFILE} could not be found."
ensure_file_exists $CONSOLE_APP_DOCKERFILE "Dockerfile ${CONSOLE_APP_DOCKERFILE} could not be found."
echo_info "Dockerfiles found"

API_APP_CSPROJ="${SLN_DIR}/vtb.${SVC_NAME}.API/vtb.${SVC_NAME}.API.csproj"
CONSOLE_APP_CSPROJ="${SLN_DIR}/vtb.${SVC_NAME}.Service/vtb.${SVC_NAME}.Service.csproj"

ensure_file_exists $API_APP_CSPROJ "Project file ${API_APP_CSPROJ} could not be found."
ensure_file_exists $CONSOLE_APP_CSPROJ "Project file ${CONSOLE_APP_CSPROJ} could not be found."
echo_info "Project files found"

API_IMAGE_NAME="$(echo $SVC_NAME | tr '[:upper:]' '[:lower:]')_api"
CONSOLE_IMAGE_NAME="$(echo $SVC_NAME | tr '[:upper:]' '[:lower:]')_service"
echo_info "Container names: ${API_IMAGE_NAME} and ${CONSOLE_IMAGE_NAME}"

# try to stop if there is already a running container with this name
(docker stop ${API_IMAGE_NAME} || true) 2> /dev/null &
(docker stop ${CONSOLE_IMAGE_NAME} || true) 2> /dev/null
wait 

(docker rm ${API_IMAGE_NAME} || true) 2> /dev/null &
(docker rm ${CONSOLE_IMAGE_NAME} || true) 2> /dev/null
wait

function build_docker_image {
    CSPROJ_FILE=$1
    DOCKERFILE_NAME=$2
    IMAGE_NAME=$3
    OUT_DIR_NAME=$4

    echo_info "Building ${CSPROJ_FILE} and publishing into ${OUT_DIR_NAME} directory."

    dotnet restore 1> /dev/null
    dotnet build $CSPROJ_FILE -c Release --no-restore 1> /dev/null
    dotnet publish $CSPROJ_FILE --no-restore --no-build -o "./${OUT_DIR_NAME}" 1> /dev/null

    echo_info "Building dockerfile ${IMAGE_NAME}"
    (docker build $OUT_DIR_NAME -f $DOCKERFILE_NAME -t $IMAGE_NAME) 1> /dev/null

    rm -rf $OUT_DIR_NAME
}

API_OUT_DIR=".out_${SVC_NAME}_api"
CONSOLE_OUT_DIR=".out_${SVC_NAME}_service"

build_docker_image $API_APP_CSPROJ $API_APP_DOCKERFILE $API_IMAGE_NAME $API_OUT_DIR & 
    build_docker_image $CONSOLE_APP_CSPROJ $CONSOLE_APP_DOCKERFILE $CONSOLE_IMAGE_NAME $CONSOLE_OUT_DIR
wait

function serve_service {
    echo_info "Running Service docker image ${CONSOLE_IMAGE_NAME}"
    docker run --name $CONSOLE_IMAGE_NAME --restart always -d $CONSOLE_IMAGE_NAME
} 
function serve_api {
    echo_info "Running API docker image ${API_IMAGE_NAME} with ${PORT} exposed"
    docker run --name $API_IMAGE_NAME --restart always -d -p "${PORT}:80" $API_IMAGE_NAME
}

serve_service & serve_api
wait 