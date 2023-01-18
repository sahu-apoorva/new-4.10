#!/usr/bin/env bash
if [ $# -ne 2 ];
then
    echo -e "\nUsage: $0 [iib-tag] [quay.io org]\n"
    exit
fi
INDEX="registry-proxy.engineering.redhat.com/rh-osbs/iib:$2"
MIRROR="quay.io/$1/iib:$2"
echo iib index = ${INDEX}
echo mirror index = ${MIRROR}
oc get secrets pull-secret -n openshift-config -o template='{{index .data ".dockerconfigjson"}}' | base64 -d > authfile
podman login --authfile authfile --username "|shared-qe-temp.src5.75b4d5" brew.registry.redhat.io
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=authfile
oc image mirror ${INDEX} ${MIRROR}
cat << EOF | kubectl apply -f -
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: brew-registry
spec:
  repositoryDigestMirrors:
  - mirrors:
    - brew.registry.redhat.io
    source: registry.redhat.io
  - mirrors:
    - brew.registry.redhat.io
    source: registry.stage.redhat.io
  - mirrors:
    - brew.registry.redhat.io
    source: registry-proxy.engineering.redhat.com
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: iib-$1
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: ${MIRROR}
  displayName: iib-$1
  publisher: GitOps Team
EOF
rm authfile
