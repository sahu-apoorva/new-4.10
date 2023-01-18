Run argocd E2E test on installed operators

Steps - https://github.com/argoproj/argo-cd/blob/master/test/remote/README.md

NOTE: Steps from the gist will be implemented in the test script and steps for how to use this repo will be added here.
      Before proceding with [environment setup](#Environment-for-make-targets), follow the steps in the above link to
      [build the image](https://github.com/argoproj/argo-cd/blob/master/test/remote/README.md#build-the-repository-container-image).
      As an alternative, you can use [this one](https://quay.io/jfischer-redhat/argocd-e2e-cluster)



# Prequsite for host

## Ubuntu:

Install Make

$ sudo apt-get install build-essential

Install Docker

$ sudo apt install docker.io -y

# Environment for make targets

##### $ make connect-to-cluster

This target helps to connect to the openshift api server. Before running this command user needs to set these environment variables: OPENSHIFT_CLUSTER_USERNAME, OPENSHIFT_CLUSTER_PASSWORD and OPENSHIFT_CLUSTER_API_URL.

###### For example:

export OPENSHIFT_CLUSTER_USERNAME=<login_username>

export OPENSHIFT_CLUSTER_PASSWORD=<login_password>

export OPENSHIFT_CLUSTER_API_URL=<api_server_url>

Then run make connect-to-cluster

###### $ make prepare-operator

This target helps to catalog source the operator when registry namespace and IIB image is passed as input. Before running this command user needs to set these environment variables: QUAY_USER and IIB_ID.

###### For example:

$ export QUAY_USER=<quay_registry_namespace>

$ export IIB_ID=<iib_image_id>

Then run make prepare-operator

###### $ make interop-test

This target helps to test the latest released version of operator against a new unreleased version of OCP. Connect to VPN beforehand as there will be cloning of downstream repositories.
To run the e2e tests as part of interop test, user needs to set SERVICE_REPO_URL, GITOPS_REPO_URL, IMAGE_REPO, DOCKERCONFIGJSON_PATH and GIT_ACCESS_TOKEN environment variables for KAM tests, APPSET_VERSION for ApplicationSet test

###### For example:

$ export SERVICE_REPO_URL=<Provide the URL for your Service repository>

$ export GITOPS_REPO_URL=<Provide the URL for your GitOps repository>

$ export IMAGE_REPO=<Image repository which is used to push newly built images>

$ export DOCKERCONFIGJSON_PATH=<Filepath to config.json which authenticates the image push to the desired image registry>

$ export GIT_ACCESS_TOKEN=<Used to authenticate repository clones, and commit-status notifications (if enabled)>

$ export APPSET_VERSION=<Version of the applicationset consumed>
e.g. `$ export APPSET_VERSION='0.2.0'`

###### $ make install-operator

This target helps to install the latest released version of GitOps operator.

###### $ make operator-upgrade

This target helps to test the operator after upgrading it from latest released version to a newer version when IIB image and the version(unreleased) is passed as input. Before running this command user needs to set these environment variables: IIB_ID and NEW_VER

###### For example:

$ export IIB_ID=<iib_image_id>

$ export NEW_VER=<unreleased_version_of_operator>
e.g. `$ export NEW_VER='1.4.4'`

Then run make operator-upgrade

###### Note:

Setting registry namespace will override the default quay account.

$ export QUAY_USER=<quay_registry_namespace>

###### $ make iib-install-operator

This target helps to install the operator prepared and catalog sourced by the make target prepare-cluster.

###### $ make cleanup

This target helps to remove the GitOps operator and cleanup the cluster

###### $ make setup-test-env

This target helps to setup the test dependency for argocd e2e test

###### $ make argocd-e2e-tests

This target helps to run argocd e2e tests

You need to set env variable ARGOCD_VERSION before running argocd-e2e-tests

e.g. `$ export ARGOCD_VERSION='2.2.5'`

###### $ make gitops-e2e-tests

This target helps to run GitOps Operator e2e tests

###### $ make appset-e2e-tests

This target helps to run upstream applicationset e2e tests

You need to set env variable APPSET_VERSION before running appset-e2e-tests

e.g. `$ export APPSET_VERSION='0.2.0'`
