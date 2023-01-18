#!/usr/bin/env bash
## This script assumes that you are connected to an OpenShift cluster
## where GitOps operator has been installed

set -e

# Clean up
cleanup() {
  if [ -n "${PORT_FWD_PID}" ]; then
    sudo kill "${PORT_FWD_PID}"
  fi
  oc patch argocd.argoproj.io/argocd-test -n argocd-e2e --type json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'
  oc delete project argocd-e2e
  oc delete project argocd-e2e-external
}

# go one level above in case this script is executed directly (not from the Makefile's argocd-e2e-tests target)
if [[ ${PWD##*/} == scripts ]]; then
  cd ..
fi

# Setting repo root dir variable
ROOT_DIR=$PWD

# Check if ARGOCD_VERSION env variable is set
if [[ -z ${ARGOCD_VERSION} ]]; then
  echo "ERROR: ARGOCD_VERSION env variable not set. It should be in SemVer format e.g. 'export ARGOCD_VERSION=2.2.5'. \
Check https://github.com/argoproj/argo-cd/releases"
  exit 1
fi

# clone Argo CD upstream repo
cd ${ROOT_DIR}
git clone https://github.com/argoproj/argo-cd.git || true

# check if ARGOCD_VERSION exists as tag v${ARGOCD_VERSION}
cd ${ROOT_DIR}/argo-cd
if ! git rev-parse -q --verify "refs/tags/v${ARGOCD_VERSION}" >/dev/null ; then
  echo "ERROR: ArgoCD version ${ARGOCD_VERSION} doesn't exist, check https://github.com/argoproj/argo-cd/releases"
  exit 1
fi

trap cleanup INT TERM EXIT

# Create a new project and an instance
cd ${ROOT_DIR}
oc new-project argocd-e2e-external || true
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

# Checkout to v${ARGOCD_VERSION} tag
cd ${ROOT_DIR}/argo-cd
git fetch --tags -f && git checkout -f tags/v${ARGOCD_VERSION} || true

# Give the Argo CD the appropriate RBAC permissions
export NAMESPACE=argocd-e2e
export ARGOCD_E2E_NAME_PREFIX=argocd-test
cd ${ROOT_DIR}/argo-cd/test/remote
sh generate-permissions.sh | oc apply -f -

# Install Kustomize and other tools
sudo make -C ${ROOT_DIR}/argo-cd install-test-tools-local || true

# Use an existing repository container image
cd ${ROOT_DIR}/argo-cd/test/remote
export IMAGE_NAMESPACE=quay.io/redhat-developer
make manifests > /tmp/e2e-repositories.yaml

# Deploy the test container and additional permissions
oc -n argocd-e2e adm policy add-scc-to-user privileged -z default
oc -n argocd-e2e apply -f /tmp/e2e-repositories.yaml
sleep 60s

# Port-forward in a separate thread
oc -n argocd-e2e port-forward service/argocd-e2e-server 9081:9081 &
# Get the PID of above process stored in a variable
PORT_FWD_PID=$!

sleep 2s

# Prepare remote OpenShift cluster
oc -n openshift-operators scale deployment --replicas=0 gitops-operator-controller-manager

export ARGOCD_SERVER=$(oc -n argocd-e2e get routes argocd-test-server -o jsonpath='{.spec.host}')
export ARGOCD_E2E_ADMIN_PASSWORD=$(oc -n argocd-e2e get secrets argocd-test-cluster -o jsonpath='{.data.admin\.password}' | base64 -d)
export ARGOCD_OPTS="--grpc-web"

# Remove the namespace restriction from the cluster secret
oc patch secrets argocd-test-default-cluster-config -n argocd-e2e -p '{"data":{"namespaces":""}}'

cd ${ROOT_DIR}/argo-cd
sed -i 's/fixture.DefaultTestUserPassword, \"--plaintext\"/fixture.DefaultTestUserPassword/' test/e2e/fixture/account/actions.go

cd ${ROOT_DIR}/argo-cd/
git apply ../mkdir.patch || true

# Skip unsupported tests
cd ${ROOT_DIR}
sh scripts/skip-unsupported-tests.sh
sleep 5s

# Continue even if one of the tests fail
cd ${ROOT_DIR}/argo-cd/hack/
sed -i 's/-failfast//g' test.sh

### Application Set specific modifications

# apply the cluster role bindings
oc apply -f "${ROOT_DIR}"/config/YAMLs/appset_cluster_role_bindings.yaml

# Skipping TestSimpleGitFilesPreserveResourcesOnDeletion test on Jan 2022, because according to @jgwest"
# - the upstream test assumes that Argo CD is NOT running in namespaced mode: eg that it has full access to the cluster.
# - the test scripts are setting up ArgoCD in namespace mode.
# - there is no easy way to give ArgoCD permission to access the namespace, without modifying the test (or the operator).
sed -i 's/\bTestSimpleGitFilesPreserveResourcesOnDeletion\b/DontRunMeTestSimpleGitFilesPreserveResourcesOnDeletion/' "${ROOT_DIR}"/argo-cd/test/e2e/applicationset_test.go

# Ensure the PlacementDecision CRD is present for the ClusterDecisionManagement tests
oc apply -f https://raw.githubusercontent.com/open-cluster-management/api/a6845f2ebcb186ec26b832f60c988537a58f3859/cluster/v1alpha1/0000_04_clusters.open-cluster-management.io_placementdecisions.crd.yaml

# Run the E2E test
cd ${ROOT_DIR}/argo-cd/test/remote
sh run-e2e-remote.sh \
make -C ${ROOT_DIR}/argo-cd test-e2e-local \
ARGOCD_E2E_SKIP_GPG=true \
ARGOCD_E2E_SKIP_HELM2=true \
ARGOCD_E2E_SKIP_OPENSHIFT=true \
ARGOCD_E2E_SKIP_KSONNET=true
