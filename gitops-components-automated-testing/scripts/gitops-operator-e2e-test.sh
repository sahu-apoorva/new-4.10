#!/usr/bin/env bash
set -x

# Get a clean env
rm -rf gitops-operator
git clone https://github.com/redhat-developer/gitops-operator

# Execute the e2e test
cd gitops-operator && make test-e2e
