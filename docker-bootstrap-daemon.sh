#!/bin/bash

# Source common.sh
source $(dirname "${BASH_SOURCE}")/docker-bootstrap.sh

case $1 in
   start)
 	#kube::bootstrap::bootstrap_daemon
	kube::bootstrap::check_running
        ;;
   stop)
	kube::bootstrap::turndown
        ;;
   *)  echo "require start|stop"  ;;
esac
