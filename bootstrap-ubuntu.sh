#!/bin/bash

###	This file should be run in SUDO mode

### The script file needs to be executable, i.e.
#	chmod +x script.sh

#	Install Docker
sh install-docker-ubuntu.sh

#	Install Azure CLI
sh install-azure-cli-ubuntu.sh

#       Login to registry
docker login unifiregistry.azurecr.io -u unifiregistry -p u=++C=X+=pKw/+++14/bDFaaGL/TQ/FN

#       Run docker containers
docker-compose up -d
