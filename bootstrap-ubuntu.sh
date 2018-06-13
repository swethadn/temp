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

#       Azure File Storage - Docker Volume Driver - Creating docker volume share
storage_key = $(az storage account keys list --resource-group $1 -n $2 -o tsv --query '[].{value:value}'[0])
if [[ $storage_key == "" ]]; then
    echo "Couldn't retrieve the storage key."
fi

echo "AZURE_STORAGE_ACCOUNT=$2" >> storageaccount
echo "AZURE_STORAGE_ACCOUNT_KEY=$storage_key" >> storageaccount

wget -qO /usr/bin/azurefile-dockervolumedriver https://github.com/Azure/azurefile-dockervolumedriver/releases/download/0.2.1/azurefile-dockervolumedriver
chmod +x /usr/bin/azurefile-dockervolumedriver
wget -qO /etc/systemd/system/azurefile-dockervolumedriver.service https://raw.githubusercontent.com/Azure/azurefile-dockervolumedriver/master/contrib/init/systemd/azurefile-dockervolumedriver.service
cp storageaccount /etc/default/
systemctl daemon-reload
systemctl enable azurefile-dockervolumedriver
systemctl start azurefile-dockervolumedriver
systemctl status azurefile-dockervolumedriver

docker volume create -d azurefile --name unifivol -o share-unifivol

#       Login to registry
docker login unifiregistry.azurecr.io -u unifiregistry -p u=++C=X+=pKw/+++14/bDFaaGL/TQ/FN

#       Run docker containers
docker-compose up -d
