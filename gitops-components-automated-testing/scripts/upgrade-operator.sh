#!/usr/bin/env bash

set -e

# This script assumes that you are connected to an OpenShift cluster

if [ ! ${IIB_ID} ] || [ ! ${NEW_VER} ];
then
    echo -e "\nPlease set the environment variables IIB_ID and NEW_VER\n"
    exit
fi

NEW_VER_MAJOR=$(echo ${NEW_VER} | cut -d'.' -f -2)
export NEW_VER_MAJOR

# Go one level above in case this script is executed directly and not from the make target: operator-upgrade
if [[ ${PWD##*/} == scripts ]]; then
  cd ..
fi

# Assign default QUAY_USER if not defined already
QUAY_USER=${QUAY_USER:="devtools_gitops"}

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

# Upgrade the operator
echo -e "\nPreparing for the upgrade, connect to VPN if not connected already"
INDEX="registry-proxy.engineering.redhat.com/rh-osbs/iib:$IIB_ID"
MIRROR="quay.io/$QUAY_USER/iib:$IIB_ID"
echo iib index = ${INDEX}
echo mirror index = ${MIRROR}
oc get secrets pull-secret -n openshift-config -o template='{{index .data ".dockerconfigjson"}}' | base64 -d > authfile
mv ~/.docker/config.json ~/.docker/config_tmp.json
mv ./authfile ~/.docker/config.json
docker login  --username "|shared-qe-temp.src5.75b4d5" brew.registry.redhat.io
mv ~/.docker/config.json ./authfile
mv ~/.docker/config_tmp.json ~/.docker/config.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=authfile
#oc image mirror ${INDEX} ${MIRROR}
docker pull ${INDEX}
docker tag ${INDEX} ${MIRROR}
docker push ${MIRROR}
docker rmi -f ${INDEX}
oc patch operatorhub.config.openshift.io/cluster -p='{"spec":{"disableAllDefaultSources":true}}' --type=merge
oc apply -f config/YAMLs/image-content-source-policy.yaml
cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: redhat-operators
  namespace: openshift-marketplace
spec:
  displayName: ''
  image: ${MIRROR}
  publisher: ''
  sourceType: grpc
EOF
rm authfile

# Wait for the Catalog source to be ready
i=0
until [ $(oc get catalogsource -n openshift-marketplace -o jsonpath="{.items[0].status.connectionState.lastObservedState}") = "READY" ]
do
  echo "Waiting for the catalog source to be in READY state"
  i=`expr $i + 1`
  sleep 10s
  if [[ $i -eq 20 ]];
  then
    echo "Catalog source not READY"
    oc patch operatorhub.config.openshift.io/cluster -p='{"spec":{"disableAllDefaultSources":false}}' --type=merge
    exit
  fi
done

# Wait for the operator to upgrade
NEW_BUILD="openshift-gitops-operator.v$NEW_VER"
until [[ $(oc get csv -n openshift-operators -o name) == *"$NEW_BUILD"* ]];
do
  echo "Operator upgrading..."
  sleep 10s
  if [[ $(oc get csv -n openshift-operators -o name) == *"$NEW_BUILD"* ]]; then
     break
  fi
done
echo -e "\nOperator upgraded, Waiting for the pods to come up"

# Establish some time for the pods to refresh
sleep 30s

# Wait for the deployments to be successfully rolled out
deployments=($(echo -n $(oc get deployments -n openshift-gitops --no-headers -o custom-columns=':metadata.name')))
for deployment in "${deployments[@]}"; do
  oc rollout status deployment/"${deployment}" -n openshift-gitops --timeout=60s
done

# Add a check- if we have single instance of GitOps operator pod

# Check the health and sync status of deployed applications
i=0
while [[ $i -lt $len ]];
do
  if [[ $(oc get app ${apps[$i]} -n openshift-gitops -o jsonpath="{.status.sync.status}") = "Synced" ]] && [[ $(oc get app ${apps[$i]} -n openshift-gitops -o jsonpath="{.status.health.status}") = "Healthy" ]]
  then
    echo "${apps[$i]} app in Healthy and Synced state"
    i=`expr $i + 1`
  else
    echo "Waiting for ${apps[$i]} app to be in Healthy and Synced state"
    sleep 10s
  fi
done

echo -e "\nOperator upgrade successful!\n"

# Re-enable the default Catalog Sources after the upgrade testing
oc patch operatorhub.config.openshift.io/cluster -p='{"spec":{"disableAllDefaultSources":false}}' --type=merge

# Clean up cluster
sh scripts/cleanup-cluster.sh
