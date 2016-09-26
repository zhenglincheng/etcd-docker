#!/bin/bash

# Constants
BOOTSTRAP_DOCKER_SOCK="unix:///var/run/docker-bootstrap.sock"
BOOTSTRAP_DOCKER_PARAM="-H ${BOOTSTRAP_DOCKER_SOCK}"

# Returns five "random" chars
kube::helpers::small_sha(){
  date | md5sum | cut -c-5
}

# This figures out the host platform without relying on golang. We need this as
# we don't want a golang install to be a prerequisite to building yet we need
# this info to figure out where the final binaries are placed.
kube::helpers::host_platform() {
  local host_os
  local host_arch
  case "$(uname -s)" in
    Linux)
      host_os=linux;;
    *)
      kube::log::fatal "Unsupported host OS. Must be linux.";;
  esac

  case "$(uname -m)" in
    x86_64*)
      host_arch=amd64;;
    i?86_64*)
      host_arch=amd64;;
    amd64*)
      host_arch=amd64;;
    aarch64*)
      host_arch=arm64;;
    arm64*)
      host_arch=arm64;;
    arm*)
      host_arch=arm;;
    ppc64le*)
      host_arch=ppc64le;;
    *)
      kube::log::fatal "Unsupported host arch. Must be x86_64, arm, arm64 or ppc64le.";;
  esac
  echo "${host_os}/${host_arch}"
}

kube::helpers::parse_version() {
  local -r version_regex="^v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-(beta|alpha)\\.(0|[1-9][0-9]*))?$"
  local -r version="${1-}"
  [[ "${version}" =~ ${version_regex} ]] || {
    kube::log::fatal "Invalid release version: '${version}', must match regex ${version_regex}"
    return 1
  }
  VERSION_MAJOR="${BASH_REMATCH[1]}"
  VERSION_MINOR="${BASH_REMATCH[2]}"
  VERSION_PATCH="${BASH_REMATCH[3]}"
  VERSION_EXTRA="${BASH_REMATCH[4]}"
  VERSION_PRERELEASE="${BASH_REMATCH[5]}"
  VERSION_PRERELEASE_REV="${BASH_REMATCH[6]}"
}

# Print a status line. Formatted to show up in a stream of output.
kube::log::status() {
  timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
  echo "+++ $timestamp $1"
  shift
  for message; do
    echo "    $message"
  done
}

# Log an error and exit
kube::log::fatal() {
  timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
  FONT_FG="\033[31m"
  FONT_BG="\033[0m"
  echo -e "${FONT_FG}!!! $timestamp ${1-} ${FONT_BG}" >&2
  #echo -e "!!! $timestamp ${1-} " >&2
  shift
  for message; do
    echo -e "   $message " >&2
  done
  exit 1
}

