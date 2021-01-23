#!/bin/bash

. ./helpers/echo-helpers.sh

mkdir "_certs"
dotnet dev-certs https -ep "_certs/aspnetapp.pfx" -p "pwd"
dotnet dev-certs https --trust