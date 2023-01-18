#!/usr/bin/env bash

set -e

# Deleting openshift-gitops-operator subscription
oc delete subscription openshift-gitops-operator -n openshift-operators

# Deleting the csv
if [[ -z $INTEROP ]]; then
    oc delete csv $(oc get csv -n openshift-operators -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep openshift-gitops) -n openshift-operators
else
    oc delete csv $(oc get csv -n openshift-operators -o jsonpath='{.items[*].metadata.name}') -n openshift-operators
    oc delete ns openshift-pipelines
fi

# Deleting the argocd finalizer
oc patch argocd.argoproj.io/openshift-gitops -n openshift-gitops --type json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'

# Deleting the openshift-gitops namespace
oc delete ns openshift-gitops
