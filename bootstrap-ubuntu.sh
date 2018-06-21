#!/bin/bash

# List of positional variables
# $RGNAME = $1
# $STORAGE_ACCOUNTNAME = $2
# $VOLUME_NAME = $3
# $UNIFI_VERSION = 2.6

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
az storage share create --name $3 --quota 2048 --connection-string $current_env_conn_string

#       Login to registry
docker login unifiregistry.azurecr.io -u unifiregistry -p u=++C=X+=pKw/+++14/bDFaaGL/TQ/FN

#       Run docker containers
docker-compose up -d


#       Download the unifi product tarball
wget --retry-connrefused -t 0 -O /tmp/unifing-2.6.tar.gz "https://demostoragey4.blob.core.windows.net/mydisks/unifing-2.6.tar.gz?st=2018-04-01T11%3A46%3A00Z&se=2018-12-31T10%3A46%3A00Z&sp=rl&sv=2017-04-17&sr=b&sig=EUUOetQf4I6C0iwt5gaSDCNObRmyn0k6M3%2Fh4yjeDmk%3D"
if [ $? -ne 0 ]; then
    echo "Could not download Unifi product artifact"
fi

echo "INFO: Copying tar file for version 2.6 of Unifi"
cd /tmp/ && tar xvzf unifing-2.6.tar.gz > /dev/null 2>&1

#       Copy the tarball to unifi container
cp -R unifing-2.6 /var/lib/docker/volumes/0_$3/_data/
