#!/bin/bash

C_INFO="\033[0;32m"
C_WARNING="\033[0;31m"
C_TEXT="\033[0m"
C_SEPARATOR="########################################################################################################################"

function echo_emptyline {
    echo ""
}

function echo_separator {
     echo $C_SEPARATOR 
}

function echo_text {
    echo -e $1
}

function echo_info { 
    echo -e "${C_INFO}${1}${C_TEXT}" 
}

function echo_warning { 
    echo -e "${C_WARNING}${1}${C_TEXT}" 
}
