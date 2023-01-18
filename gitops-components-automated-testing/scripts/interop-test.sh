#!/usr/bin/env bash

set -e

# go one level above in case this script is executed directly
if [[ ${PWD##*/} == scripts ]]; then
  cd ..
fi

# Setting repo root dir variable
ROOT_DIR=$PWD

# Create a directory for storing results
mkdir reports

# Set INTEROP env variable
export INTEROP=true

# Check for env variables
if [[ -z $SERVICE_REPO_URL || -z $GITOPS_REPO_URL || -z $IMAGE_REPO || -z $DOCKERCONFIGJSON_PATH || -z $GIT_ACCESS_TOKEN || -z $APPSET_VERSION ]]; then
  echo "ERROR: Env variables not set. Please refer to README.md"
  exit 1
fi

# Install the latest released version of GitOps Operator
sh scripts/install-operators.sh

# Create some sample applications
echo -e "\nCreating some sample applications"
oc apply -f config/YAMLs/sample-applications.yaml

# Check the health and sync status of deployed applications
declare -a apps=("builds-config" "console-config" "image-config")
len=${#apps[@]}
i=0
while [[ $i -lt $len ]]
do
  if [[ $(oc get app ${apps[$i]} -n openshift-gitops -o jsonpath="{.status.sync.status}") = "Synced" ]] && [[ $(oc get app ${apps[$i]} -n openshift-gitops -o jsonpath="{.status.health.status}") = "Healthy" ]]; then
    echo "${apps[$i]} app in Healthy and Synced state"
    i=`expr $i + 1`
  else
    echo "Waiting for ${apps[$i]} app to be in Healthy and Synced state"
    sleep 10s
  fi
done

# Create a new project and an instance
oc new-project argocd-e2e || true
oc apply -f config/YAMLs/argocd-test.yaml

until [ $(oc get argocd argocd-test -n argocd-e2e -o jsonpath='{.status.phase}') = "Available" ];
do
  echo "Argo CD instance is reconcilling..."
  sleep 10s
  if [ $(oc get argocd argocd-test -n argocd-e2e -o jsonpath='{.status.phase}') = "Available" ]; then
     echo "Reconcilation Finished"
     break
  fi
done

echo "Argo CD instance is up and available."

# Execute kuttl test suite
cd ${ROOT_DIR}
git clone git@gitlab.cee.redhat.com:gitops/operator-e2e.git || true
cd ${ROOT_DIR}/operator-e2e/gitops-operator
kubectl kuttl test tests/sequential --config tests/sequential/kuttl-test.yaml --report xml
mv kuttl-test.xml ${ROOT_DIR}/reports/kuttl-sequential.xml
kubectl kuttl test tests/parallel --config tests/parallel/kuttl-test.yaml --report xml
mv kuttl-test.xml ${ROOT_DIR}/reports/kuttl-parallel.xml

# Execute ApplicationSet test
cd ${ROOT_DIR}
sh scripts/appset-e2e-test.sh

# Execute KAM tests
cd ${ROOT_DIR}
git clone https://github.com/redhat-developer/kam || true
cd ${ROOT_DIR}/kam
git checkout interop
make e2e

# Clean up
cd ${ROOT_DIR}
sh scripts/cleanup-cluster.sh
unset $INTEROP
