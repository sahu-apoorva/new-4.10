#!/usr/bin/env bash

# Create an array of unsupported tests
declare -a arr=(
    "TestHelmOCIRegistry"
    "TestGitWithHelmOCIRegistryDependencies"
    "TestHelmOCIRegistryWithDependencies"
    "TestTemplatesGitWithHelmOCIDependencies"
    "TestTemplatesHelmOCIWithDependencies"
    "TestCMPDiscoverWithFileName"
    "TestCMPDiscoverWithFindCommandWithEnv"
    "TestAutomaticallyNamingUnnamedHook" # Issues with Cluster Latency, Refer https://issues.redhat.com/browse/GITOPS-2334
)

for i in "${arr[@]}"
do
    # Get file and line number with test definition of TestTemplatesHelmOCIWithDependencies
    export A=$(grep --exclude-dir=test-results --exclude-dir=.git --exclude=$(basename "$0") -rwn . -e $i)

    # Separate them into two different variables
    export Line=$(echo "$A" | awk -F: '{print $2}' )
    export File=$(echo "$A" | awk -F: '{print $1}' )

    # Add skip statement
    Line=$(expr $Line + 1)
    if sed "$Line q;d" $File | grep -q 'SkipOnEnv(t, "OPENSHIFT")' && break
    then
        break
    else
        sed -i ''$Line' i  \\tSkipOnEnv(t, "OPENSHIFT")' $File
    fi
done
