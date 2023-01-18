#!/usr/bin/env bash


## Be sure to set OPENSHIFT_CLUSTER_API_URL, OPENSHIFT_CLUSTER_USERNAME
## & OPENSHIFT_CLUSTER_PASSWORD in the environment

## login using server credentials from the environment
oc login -u $OPENSHIFT_CLUSTER_USERNAME -p $OPENSHIFT_CLUSTER_PASSWORD --server=$OPENSHIFT_CLUSTER_API_URL --insecure-skip-tls-verify=true
