#!/bin/bash
set -ex

# Docker installation (Amazon Linux 2)
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user

# Deploy DVWA
sudo docker run -d -p 8080:80 vulnerables/web-dvwa
