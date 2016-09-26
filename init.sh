#!/bin/bash

bootstrap_images="etcd-amd64_v2.2.5.tar"
images=""
base_images_dir=$(dirname "${BASH_SOURCE}")/images
source $(dirname "${BASH_SOURCE}")/docker-bootstrap.sh

kube::images::load_bootstrap_image(){
  kube::log::status "Load image $1 ."
  docker ${BOOTSTRAP_DOCKER_PARAM} load -i $1
}

kube::images::load_image(){
  kube::log::status "Load image $1 ."
  docker load -i $1
}

kube::bootstrap::check_running

for image in $bootstrap_images;do
   kube::images::load_bootstrap_image ${base_images_dir}/${image} 
done
for image in $images;do
   kube::images::load_image ${base_images_dir}/$image
done

#kube::bootstrap::turndown
