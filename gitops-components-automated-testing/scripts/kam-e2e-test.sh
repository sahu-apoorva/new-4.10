#!/usr/bin/env bash
set -x
git clone https://github.com/redhat-developer/kam

# Add downstream configuration for e2e test prerequisite
# reference - https://github.com/redhat-developer/kam/blob/master/docs/test/test-guide.md#run-e2e-test-locally

# Adding unit test step is for reference. Later it will be replaced with kam e2e test step
cd kam && make test

# Clean up
cd .. && rm -rf kam
