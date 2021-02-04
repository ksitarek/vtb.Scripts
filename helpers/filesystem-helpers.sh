#!/bin/bash

function ensure_directory_exists {
    if ! directory_exists $1; then
        echo_warning "$2"
        exit;
    fi
}

function ensure_file_exists {
    if ! file_exists $1; then
        echo_warning "$2"
        exit;
    fi
}

function file_exists {
    [ -f "$1" ]
}

function directory_exists {
    [ -d "$1" ]
}