default: orchestrate
QUAY_USER ?=
IIB_ID ?=
# This step installs necessary CLI dependencies and connects to a cluster with pre-saved credentials
.PHONY: connect-to-cluster
connect-to-cluster:
        echo 'Connecting to the cluster...'
        . ./scripts/connect-to-cluster.sh

.PHONY: prepare-operator
prepare-operator:
        @if [ ! "$(QUAY_USER)" ] || [ ! "$(IIB_ID)" ]; then \
                echo "Missing arguments! Provide appropriate arguments quay namespace and iib id"; \
                exit 1; \
        fi
        echo 'Installing the operator...'
        . ./scripts/iib_install_docker.sh $(QUAY_USER) $(IIB_ID)

.PHONY: operator-upgrade
operator-upgrade:
        . ./scripts/upgrade-operator.sh

.PHONY: cleanup
cleanup:
        . ./scripts/cleanup-cluster.sh

.PHONY: install-operator
install-operator:
        . ./scripts/install-operators.sh

.PHONY: iib-install-operator
iib-install-operator:
        . ./scripts/iib-install-operator.sh

.PHONY: interop-test
interop-test:
        echo 'Preparing for the interop test...'
        . ./scripts/interop-test.sh || continue
        mv applicationset/applicationset-test.xml kam/kam-test.xml reports

.PHONY: kam-e2e-test
kam-e2e-test:
        . ./scripts/kam.sh

.PHONY: setup-test-env
setup-test-env:
        echo "Setting up test environment..."
        . ./scripts/prepare-host.sh

.PHONY: argocd-e2e-tests
argocd-e2e-tests:
        echo "Running argocd E2E tests..."
        . ./scripts/argocd-e2e-test.sh

.PHONY: gitops-e2e-tests
gitops-e2e-tests:
        echo "Running GitOps Operator E2E tests..."
        . ./scripts/gitops-operator-e2e-test.sh

.PHONY: appset-e2e-tests
appset-e2e-tests:
        echo "Running ApplicationSet E2E tests..."
        . ./scripts/appset-e2e-test.sh

.PHONY: export-results
export-results:
        echo 'Publishing test results on slack...'

.PHONY: orchestrate
orchestrate: connect-to-cluster install-operator setup-test-env run-tests export-results
