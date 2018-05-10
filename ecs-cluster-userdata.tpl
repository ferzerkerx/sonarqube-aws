#!/bin/bash

# Timezone
ln -fs /usr/share/zoneinfo/Europe/Berlin /etc/localtime

yum installaws-cli
yum update -y

# ECS config
echo "ECS_CLUSTER=${ecs_cluster_name}" >> /etc/ecs/ecs.config
