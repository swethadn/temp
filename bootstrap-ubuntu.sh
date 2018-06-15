#!/bin/bash

# List of positional variables
# $RGNAME = $1
# $STORAGE_ACCOUNTNAME = $2

###	This file should be run in SUDO mode

### The script file needs to be executable, i.e.
#	chmod +x script.sh

#	Install Docker
sh install-docker-ubuntu.sh

#	Install Azure CLI
sh install-azure-cli-ubuntu.sh

#       Login to azure
az login -u swetha@unifisoftware.com -p Un1f1rocks123!

#       Azure File Storage - get connection string
current_env_conn_string=$(az storage account show-connection-string -n $2 -g $1 --query 'connectionString' -o tsv)
if [ -z "$current_env_conn_string" ] ; then
    echo "Couldn't retrieve the connection string."
fi

#       Create a file share
az storage share create --name unifivol --quota 2048 --connection-string $current_env_conn_string 1 > /dev/null

#       Login to registry
docker login unifiregistry.azurecr.io -u unifiregistry -p u=++C=X+=pKw/+++14/bDFaaGL/TQ/FN

#       Run docker containers
docker-compose up -d
