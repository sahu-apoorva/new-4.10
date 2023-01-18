#!/usr/bin/env bash

# Install necessary dependencies
./scripts/dep-install.sh packr-linux
./scripts/dep-install.sh kustomize-linux
./scripts/dep-install.sh ksonnet-linux
./scripts/dep-install.sh helm2-linux
./scripts/dep-install.sh helm-linux

# Use this variable to get more control over downloading client binary. Currently using Linux only for CI
OPENSHIFT_CLIENT_BINARY_URL=${OPENSHIFT_CLIENT_BINARY_URL:-'https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz'}

# download oc binaries
sudo wget $OPENSHIFT_CLIENT_BINARY_URL -O oc.tar

# Extract the binary and add to path
sudo tar -zcvf oc.tar /usr/local/bin

# change permission for the binary to execute
sudo chmod u+x /usr/local/bin/oc

# Get oc version
oc version

