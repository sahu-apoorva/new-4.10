#!/usr/bin/env bash
set -x

# Go one level above in case this script is executed directly and not from the make target
if [[ ${PWD##*/} == scripts ]]; then
  cd ..
fi

echo "Starting OpenShift GitOps operator installation"
oc create -f config/YAMLs/iib-subscription.yaml

# GitOps operator status check
count=0
while [ "$count" -lt "15" ];
do
    operator_status=`oc get csv -n openshift-operators | grep openshift-gitops-operator`
    if [[ $operator_status == *"Succeeded"* ]]; then
        break
    else
        count=`expr $count + 1`
        sleep 10
    fi
done
echo "Completed OpenShift GitOps operator installation"
