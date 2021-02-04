#!/bin/bash

SVC_NAME=$1
PORT=$2
ORG_SLN_DIR="../vtb.${SVC_NAME}";
SLN_DIR=".tmp.vtb.${SVC_NAME}"

HAS_API=false
HAS_API_DOCKER_CONF=false
HAS_SERVICE=false
HAS_SERVICE_DOCKER_CONF=false

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

API_APP_CSPROJ="${SLN_DIR}/vtb.${SVC_NAME}.Api/vtb.${SVC_NAME}.Api.csproj"
CONSOLE_APP_CSPROJ="${SLN_DIR}/vtb.${SVC_NAME}.Service/vtb.${SVC_NAME}.Service.csproj"

API_DEV_DOCKER_CONFIG="$(pwd)/../vtb.${SVC_NAME}/vtb.${SVC_NAME}.Api/appsettings.Dev-Docker.json"
CONSOLE_DEV_DOCKER_CONFIG="$(pwd)/../vtb.${SVC_NAME}/vtb.${SVC_NAME}.Service/appsettings.Dev-Docker.json"

echo $API_DEV_DOCKER_CONFIG

API_APP_DOCKERFILE="${SLN_DIR}/Dockerfile.API"
CONSOLE_APP_DOCKERFILE="${SLN_DIR}/Dockerfile.Service"

API_OUT_DIR=""
CONSOLE_OUT_DIR=""
API_IMAGE_NAME=""
CONSOLE_IMAGE_NAME=""

if file_exists $API_APP_CSPROJ; then
    echo_info "$API_APP_CSPROJ file found. Will attempt to start it in docker container."
    API_OUT_DIR="$(pwd)/.out_${SVC_NAME}_api"
    HAS_API=true
fi

if file_exists $API_DEV_DOCKER_CONFIG; then
    echo_info "$API_DEV_DOCKER_CONFIG file found. Will attach it as an volume to container."
    HAS_API_DOCKER_CONF=true
fi

if file_exists $CONSOLE_APP_CSPROJ; then
    echo_info "$CONSOLE_APP_CSPROJ file found. Will attempt to start it in docker container."
    CONSOLE_OUT_DIR="$(pwd)/.out_${SVC_NAME}_service"
    HAS_SERVICE=true
fi

if file_exists $CONSOLE_DEV_DOCKER_CONFIG; then
    echo_info "$CONSOLE_DEV_DOCKER_CONFIG file found. Will attach it as an volume to container."
    HAS_SERVICE_DOCKER_CONF=true
fi

if "$HAS_API"; then
    ensure_file_exists $API_APP_DOCKERFILE "Dockerfile ${API_APP_DOCKERFILE} could not be found."
    echo_info "$API_APP_DOCKERFILE found. Container/image name is going to be $API_IMAGE_NAME"
    API_IMAGE_NAME="$(echo $SVC_NAME | tr '[:upper:]' '[:lower:]')_api"
fi

if "$HAS_SERVICE"; then
    ensure_file_exists $CONSOLE_APP_DOCKERFILE "Dockerfile ${CONSOLE_APP_DOCKERFILE} could not be found."
    echo_info "$CONSOLE_APP_DOCKERFILE found. Container/image name is going to be $CONSOLE_IMAGE_NAME"
    CONSOLE_IMAGE_NAME="$(echo $SVC_NAME | tr '[:upper:]' '[:lower:]')_service"
fi

echo_emptyline
echo_separator
echo_bool $HAS_API "API"
echo_bool $HAS_API_DOCKER_CONF "API Docker config"
echo_bool $HAS_SERVICE "Service"
echo_bool $HAS_SERVICE_DOCKER_CONF "Service Docker config"
echo_separator
echo_emptyline

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
    (docker build . -f "../$DOCKERFILE_NAME" -t $IMAGE_NAME)
    cd ..

    rm -rf $OUT_DIR_NAME
}

function try_build_api_image {
    if "$HAS_API"; then
        echo_info "Building docker image for API with following settings:"
        echo_text "\t- API_APP_CSPROJ: $API_APP_CSPROJ"
        echo_text "\t- API_APP_DOCKERFILE: $API_APP_DOCKERFILE"
        echo_text "\t- API_IMAGE_NAME: $API_IMAGE_NAME"
        echo_text "\t- API_OUT_DIR: $API_OUT_DIR"

        build_docker_image $API_APP_CSPROJ $API_APP_DOCKERFILE $API_IMAGE_NAME $API_OUT_DIR
    fi
}

function try_build_service_image {
    if "$HAS_SERVICE"; then
        echo_info "Building docker image for Service with following settings:"
        echo_text "\t- CONSOLE_APP_CSPROJ: $CONSOLE_APP_CSPROJ"
        echo_text "\t- CONSOLE_APP_DOCKERFILE: $CONSOLE_APP_DOCKERFILE"
        echo_text "\t- CONSOLE_IMAGE_NAME: $CONSOLE_IMAGE_NAME"
        echo_text "\t- CONSOLE_OUT_DIR: $CONSOLE_OUT_DIR"

        build_docker_image $CONSOLE_APP_CSPROJ $CONSOLE_APP_DOCKERFILE $CONSOLE_IMAGE_NAME $CONSOLE_OUT_DIR
    fi
}

function try_serve_api {
    if "$HAS_API"; then
        echo_info "Running API docker image ${API_IMAGE_NAME} with ${PORT} exposed"
        CERTS_ABS_PATH="$(pwd)/_certs"

        (docker stop ${API_IMAGE_NAME} || true) > /dev/null 2>&1
        (docker rm ${API_IMAGE_NAME} || true) > /dev/null 2>&1

        run_cmd=(docker run \
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
            -d)

        if $HAS_API_DOCKER_CONF; then
            run_cmd+=(-v "${API_DEV_DOCKER_CONFIG}:/appsettings.Dev-Docker.json")
        fi

        run_cmd+=($API_IMAGE_NAME)
        
        "${run_cmd[@]}"
    fi
}

function try_serve_service {
    if "$HAS_SERVICE"; then
        echo_info "Running Service docker image ${CONSOLE_IMAGE_NAME}"

        (docker stop ${CONSOLE_IMAGE_NAME} || true) > /dev/null 2>&1
        (docker rm ${CONSOLE_IMAGE_NAME} || true) > /dev/null 2>&1

        run_cmd=(docker run \
            --network "vtb_network" \
            --name $CONSOLE_IMAGE_NAME \
            --restart always \
            -e ASPNETCORE_ENVIRONMENT=dev-docker \
            -d)
            
        if $HAS_SERVICE_DOCKER_CONF; then
            run_cmd+=(-v "${CONSOLE_DEV_DOCKER_CONFIG}:/appsettings.Dev-Docker.json")
        fi

        run_cmd+=($CONSOLE_IMAGE_NAME)
        
        "${run_cmd[@]}"
    fi
} 

dotnet restore $SLN_DIR
dotnet build $SLN_DIR -c Release --no-restore

try_build_api_image & try_build_service_image
wait

rm -rf $SLN_DIR

try_serve_service & try_serve_api
wait 