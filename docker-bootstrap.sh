#!/bin/bash

source $(dirname "${BASH_SOURCE}")/common.sh
# Start a docker bootstrap for running etcd and flannel
kube::bootstrap::bootstrap_daemon() {

  kube::log::status "Launching docker bootstrap..."

  docker daemon \
    -H ${BOOTSTRAP_DOCKER_SOCK} \
    -p /var/run/docker-bootstrap.pid \
    --iptables=false \
    --ip-masq=false \
    --bridge=none \
    --graph=/var/lib/docker-bootstrap \
    --exec-root=/var/run/docker-bootstrap \
      2> /var/log/docker-bootstrap.log \
      1> /dev/null &

  # Wait for docker bootstrap to start by "docker ps"-ing every second
  local SECONDS=0
  while [[ $(docker -H ${BOOTSTRAP_DOCKER_SOCK} ps 2>&1 1>/dev/null; echo $?) != 0 ]]; do
    ((SECONDS++))
    if [[ ${SECONDS} == ${TIMEOUT_FOR_SERVICES} ]]; then
      kube::log::fatal "docker bootstrap failed to start. Exiting..."
    fi
    sleep 1
  done
}

kube::bootstrap::turndown(){

  # Check if docker bootstrap is running
  if [[ ! -z $(ps aux | grep "${BOOTSTRAP_DOCKER_SOCK}" | grep -v "grep") ]]; then

    kube::log::status "Killing docker bootstrap..."

    # Kill all docker bootstrap's containers
    if [[ $(docker -H ${BOOTSTRAP_DOCKER_SOCK} ps -q | wc -l) != 0 ]]; then
      docker -H ${BOOTSTRAP_DOCKER_SOCK} rm -f $(docker -H ${BOOTSTRAP_DOCKER_SOCK} ps -q)
    fi

    # Kill bootstrap docker itself
    kill $(ps aux | grep ${BOOTSTRAP_DOCKER_SOCK} | grep -v grep | awk '{print $2}')
  else
    kube::log::status " docker bootstrap is not running ..."
  fi
}

kube::bootstrap::check_running(){

  # Check if docker bootstrap is running
  if [[ ! -z $(ps aux | grep "${BOOTSTRAP_DOCKER_SOCK}" | grep -v "grep") ]]; then
    kube::log::status " docker bootstrap is running..."
  else
    #kube::log::fatal " docker bootstrap is not running..."
    kube::bootstrap::bootstrap_daemon
  fi
}

