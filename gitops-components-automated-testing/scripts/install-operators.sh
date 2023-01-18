#!/usr/bin/env bash

set -e

# go one level above in case this script is executed directly
if [[ ${PWD##*/} == scripts ]]; then
  cd ..
fi

# Install the latest released version of GitOps Operator
echo "Installing OpenShift GitOps operator"
echo -e "Ensure gitops subscription exists"
oc get subscription openshift-gitops-operator-rh -n openshift-operators 2>/dev/null || \
envsubst < config/YAMLs/gitops-subscription.yaml | oc apply -f -

# GitOps operator status check
sleep 30s
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

# wait for the deployments to be successfully rolled out
deployments=($(echo -n $(oc get deployments -n openshift-gitops --no-headers -o custom-columns=':metadata.name')))
for deployment in "${deployments[@]}"; do
  oc rollout status deployment/"${deployment}" -n openshift-gitops --timeout=60s
done

echo -e "\nProvide cluster-admin access to argocd-application-controller service account"
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller

# Install the latest released version of Pipelines Operator for interop scenario

if [[ ${INTEROP} == true ]]; then
  echo "Installing OpenShift Pipelines operator"
  echo -e "Ensure pipelines subscription exists"
  oc get subscription openshift-pipelines-operator-rh -n openshift-operators 2>/dev/null || \
  oc apply -f config/YAMLs/pipelines-subscription.yaml

  for i in {1..150}; do  # timeout after 5 minutes
    pods="$(oc get pods -n openshift-operators --no-headers 2>/dev/null | wc -l)"
    if [[ "${pods}" -ge 1 ]]; then
      echo -e "\nWaiting for Pipelines operator pod"
      oc wait --for=condition=Ready -n openshift-operators -l name=openshift-pipelines-operator pod --timeout=5m
      retval=$?
      if [[ "${retval}" -gt 0 ]]; then exit "${retval}"; else break; fi
    fi
    if [[ "${i}" -eq 150 ]]; then
      echo "Timeout: pod was not created."
      exit 2
    fi
    echo -n "."
    sleep 2
  done

  for i in {1..150}; do  # timeout after 5 minutes
    pods="$(oc get pods -n openshift-pipelines --no-headers 2>/dev/null | wc -l)"
    if [[ "${pods}" -ge 4 ]]; then
      echo -e "\nWaiting for Pipelines and Triggers pods"
      oc wait --for=condition=Ready -n openshift-pipelines pod --timeout=5m \
        -l 'app in (tekton-pipelines-controller,tekton-pipelines-webhook,tekton-triggers-controller,
        tekton-triggers-webhook)'
      retval=$?
      if [[ "${retval}" -gt 0 ]]; then exit "${retval}"; else break; fi
    fi
    if [[ "${i}" -eq 150 ]]; then
      echo "Timeout: pod was not created."
      exit 2
    fi
    echo -n "."
    sleep 2
  done
fi
