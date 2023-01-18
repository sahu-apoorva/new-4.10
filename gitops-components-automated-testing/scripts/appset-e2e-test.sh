#!/usr/bin/env bash

set -e

# go one level above in case this script is executed directly (not from the Makefile's ${APPSET_NAMESPACE}-tests target)
if [[ ${PWD##*/} == scripts ]]; then
  cd ..
fi

# Setting repo root dir variable
ROOT_DIR=${PWD}

# Check if APPSET_VERSION env variable is set
if [[ -z ${APPSET_VERSION} ]]; then
  echo "ERROR: APPSET_VERSION env variable not set. It should be in SemVer format e.g. 'export APPSET_VERSION=0.3.0'. \
Check https://github.com/argoproj/applicationset/releases"
  exit 1
fi

# clone AppSet upstream repo
cd "${ROOT_DIR}"
git clone https://github.com/argoproj/applicationset.git || true

# check if APPSET_VERSION exists as tag v${APPSET_VERSION}
cd "${ROOT_DIR}"/applicationset
if ! git rev-parse -q --verify "refs/tags/v${APPSET_VERSION}" >/dev/null ; then
  echo "ERROR: ApplicationSet version ${APPSET_VERSION} doesn't exist, check https://github.com/argoproj/applicationset/releases"
  exit 1
fi

# Checkout to v${APPSET_VERSION} tag
cd "${ROOT_DIR}"/applicationset
git fetch --tags && git checkout -f tags/v"${APPSET_VERSION}" || true

# appset test namespace
APPSET_NAMESPACE='argocd-appset-e2e'

## This script assumes that you are connected to an OpenShift cluster
## where GitOps operator has been installed

# Create a new project and an instance
cd "${ROOT_DIR}"
oc new-project ${APPSET_NAMESPACE} || true
oc apply -f config/YAMLs/appset-test.yaml

until [[ $(oc get argocd appset-test -n "${APPSET_NAMESPACE}" -o jsonpath='{.status.phase}') = "Available" ]];
do
  echo "Argo CD instance is reconciling..."
  sleep 10s
done
echo "Argo CD instance is up and available."

until [[ $(oc get deployment appset-test-applicationset-controller -n "${APPSET_NAMESPACE}" -o jsonpath='{.status.readyReplicas}') = "1" ]];
do
  echo "ApplicationSet controller is reconciling..."
  sleep 10s
done
echo "ApplicationSet controller is up and available."

# change the argocd namespace in tests
sed -i "s/\bargocd-e2e\b/${APPSET_NAMESPACE}/" "${ROOT_DIR}"/applicationset/test/e2e/fixture/applicationsets/utils/fixture.go

# apply the cluster role bindings
oc apply -f "${ROOT_DIR}"/config/YAMLs/appset_cluster_role_bindings.yaml

# Skipping TestSimpleGitFilesPreserveResourcesOnDeletion test on Jan 2022, because according to @jgwest"
# - the upstream test assumes that Argo CD is NOT running in namespaced mode: eg that it has full access to the cluster.
# - the test scripts are setting up ArgoCD in namespace mode.
# - there is no easy way to give ArgoCD permission to access the namespace, without modifying the test (or the operator).
sed -i 's/\bTestSimpleGitFilesPreserveResourcesOnDeletion\b/DontRunMeTestSimpleGitFilesPreserveResourcesOnDeletion/' "${ROOT_DIR}"/applicationset/test/e2e/applicationset/applicationset_test.go

# according to @jgwest "You can basically ignore errors on any tests that contain the word cluster, they are fixed in 0.3.0"
if [ "${APPSET_VERSION}" = "0.2.0" ]; then
  sed -i 's/\bTestClusterMatrixGenerator\b/DontRunMeTestClusterMatrixGenerator/' "${ROOT_DIR}"/applicationset/test/e2e/applicationset/matrix_e2e_test.go
  sed -i 's/\bTestSimpleClusterGenerator\b/DontRunMeTestSimpleClusterGenerator/' "${ROOT_DIR}"/applicationset/test/e2e/applicationset/cluster_e2e_test.go
  sed -i 's/\bTestSimpleClusterResourceListGenerator\b/DontRunMeTestSimpleClusterResourceListGenerator/' "${ROOT_DIR}"/applicationset/test/e2e/applicationset/crl_e2e_test.go
  sed -i 's/\bTestSimpleClusterResourceListGeneratorAddingCluster\b/DontRunMeTestSimpleClusterResourceListGeneratorAddingCluster/' "${ROOT_DIR}"/applicationset/test/e2e/applicationset/crl_e2e_test.go
  sed -i 's/\bTestSimpleClusterResourceListGeneratorDeletingClusterSecret\b/DontRunMeTestSimpleClusterResourceListGeneratorDeletingClusterSecret/' "${ROOT_DIR}"/applicationset/test/e2e/applicationset/crl_e2e_test.go
  sed -i 's/\bTestSimpleClusterResourceListGeneratorDeletingClusterFromResource\b/DontRunMeTestSimpleClusterResourceListGeneratorDeletingClusterFromResource/' "${ROOT_DIR}"/applicationset/test/e2e/applicationset/crl_e2e_test.go
  sed -i 's/\bTestClusterGeneratorWithLocalCluster\b/DontRunMeTestClusterGeneratorWithLocalCluster/' "${ROOT_DIR}"/applicationset/test/e2e/applicationset/cluster_e2e_test.go
  sed -i 's/\bTestSimpleClusterGeneratorAddingCluster\b/DontRunMeTestSimpleClusterGeneratorAddingCluster/' "${ROOT_DIR}"/applicationset/test/e2e/applicationset/cluster_e2e_test.go
  sed -i 's/\bTestSimpleClusterGeneratorDeletingCluster\b/DontRunMeTestSimpleClusterGeneratorDeletingCluster/' "${ROOT_DIR}"/applicationset/test/e2e/applicationset/cluster_e2e_test.go
fi

# Ensure the PlacementDecision CRD is present for the ClusterDecisionManagement tests
oc apply -f https://raw.githubusercontent.com/open-cluster-management/api/a6845f2ebcb186ec26b832f60c988537a58f3859/cluster/v1alpha1/0000_04_clusters.open-cluster-management.io_placementdecisions.crd.yaml

# run the test
cd "${ROOT_DIR}/applicationset"
NAMESPACE=${APPSET_NAMESPACE}
go test -race -count=1 -v -timeout 480s "${ROOT_DIR}"/applicationset/test/e2e/applicationset | tee test.out
go-junit-report < test.out > applicationset-test.xml

# Tear down
oc delete -f "${ROOT_DIR}"/config/YAMLs/appset_cluster_role_bindings.yaml
oc patch argocd.argoproj.io/appset-test -n "${APPSET_NAMESPACE}" --type json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'
oc delete project "${APPSET_NAMESPACE}"
