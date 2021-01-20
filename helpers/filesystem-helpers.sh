#!/bin/bash

function ensure_directory_exists {
    if [ ! -d $1 ]; then
        echo_warning "$2"
        exit;
    fi
}

function ensure_file_exists {
    if [ ! -f $1 ]; then
        echo_warning "$2"
        exit;
    fi
}