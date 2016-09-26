#!/bin/bash

source $(dirname "${BASH_SOURCE}")/etcd_env
source $(dirname "${BASH_SOURCE}")/docker-bootstrap.sh

kube::etcd::main(){

  ETCD_VERSION=${ETCD_VERSION:-"2.2.5"}

  RESTART_POLICY=${RESTART_POLICY:-"unless-stopped"}

  CURRENT_PLATFORM=$(kube::helpers::host_platform)
  ARCH=${ARCH:-${CURRENT_PLATFORM##*/}}

  DEFAULT_NET_INTERFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -1)
  NET_INTERFACE=${NET_INTERFACE:-${DEFAULT_NET_INTERFACE}}

  DEFAULT_IP_ADDRESS=$(ip -o -4 addr list ${NET_INTERFACE} | awk '{print $4}' | cut -d/ -f1 | head -1)
  IP_ADDRESS=${IP_ADDRESS:-${DEFAULT_IP_ADDRESS}}

  TIMEOUT_FOR_SERVICES=${TIMEOUT_FOR_SERVICES:-20}

  # Constants
  BOOTSTRAP_DOCKER_SOCK="unix:///var/run/docker-bootstrap.sock"
  BOOTSTRAP_DOCKER_PARAM="-H ${BOOTSTRAP_DOCKER_SOCK}"
  ETCD_NET_PARAM="--net host"
  KUBELET_MOUNTS="\
    -v /sys:/sys:rw \
    -v /var/run:/var/run:rw \
    -v /run:/run:rw \
    -v /var/lib/docker:/var/lib/docker:rw \
    -v /var/lib/kubelet:/var/lib/kubelet:shared \
    -v /var/log/containers:/var/log/containers:rw"
}

# Ensure everything is OK, docker is running and we're root
kube::etcd::log_variables() {

  # Output the value of the variables
  kube::log::status "ETCD_VERSION is set to: ${ETCD_VERSION}"
  kube::log::status "RESTART_POLICY is set to: ${RESTART_POLICY}"
  kube::log::status "ARCH is set to: ${ARCH}"
  kube::log::status "NET_INTERFACE is set to: ${NET_INTERFACE}"
  kube::log::status "IP_ADDRESS is set to: ${IP_ADDRESS}"
  kube::log::status "--------------------------------------------"
}

kube::etcd::check_bootstrap_running(){

  # Check if docker bootstrap is running
  if [[ ! -z $(ps aux | grep "${BOOTSTRAP_DOCKER_SOCK}" | grep -v "grep") ]]; then
    kube::log::status " docker bootstrap is running..."
  else
    kube::log::fatal " docker bootstrap is not running..." 
  fi
}

kube::etcd::start() {

  kube::log::status "Launching etcd..."

  docker ${BOOTSTRAP_DOCKER_PARAM} run -d \
    --name kube_etcd_$(kube::helpers::small_sha) \
    --restart=${RESTART_POLICY} \
    ${ETCD_NET_PARAM} \
    -v ${ETCD_DATA_DIR}:${ETCD_DATA_DIR} \
    gcr.io/google_containers/etcd-${ARCH}:${ETCD_VERSION} \
    /usr/local/bin/etcd  ${ETCD_OPTIONS}

  # Wait for etcd to come up
  local SECONDS=0
  while [[ $(curl -fsSL http://localhost:2379/health 2>&1 1>/dev/null; echo $?) != 0 ]]; do
    ((SECONDS++))
    if [[ ${SECONDS} == ${TIMEOUT_FOR_SERVICES} ]]; then
      kube::log::fatal "etcd failed to start. Exiting..."
    else
      kube::log::status "waiting etcd start for success... "
    fi
    sleep 1
  done
}

kube::etcd::stop(){
  kube::log::status " etcd stopped... "

  etcd_uuid=$(docker ${BOOTSTRAP_DOCKER_PARAM}  ps -a |grep kube_etcd | awk '{print $1}')
  #docker ${BOOTSTRAP_DOCKER_PARAM} stop ${etcd_uuid}
  docker ${BOOTSTRAP_DOCKER_PARAM} rm -f  ${etcd_uuid}
  
  kube::log::status " etcd stopping... "
}

case $1 in
   start) 
        kube::etcd::main
 	kube::etcd::log_variables
	kube::bootstrap::check_running
        kube::etcd::start
        ;;
   stop)
        kube::etcd::main 
        kube::etcd::log_variables
        kube::etcd::stop
        ;;
   *)  echo "require start|stop"  ;;
esac
