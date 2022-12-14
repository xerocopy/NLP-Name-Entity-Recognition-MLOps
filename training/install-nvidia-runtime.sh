#!/bin/bash

# This script needs executed on the host.
# The ndivia runtime will then be available to the containers.

distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
#curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo yum add -
#curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/yum/sources.list.d/nvidia-docker.list

#sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo yum update && sudo yum install -y nvidia-container-toolkit
sudo systemctl restart docker
