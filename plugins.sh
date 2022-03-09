#!/bin/bash

set -eux

installer_dir=/home/padillon/go/src/github.com/openshift/installer
installer=$installer_dir/bin/openshift-install
plugin_path=/home/padillon/go/src/github.com/patrickdillon/openshift-installer-acme-plugin/openshift-installer-acme-plugin.so
dir_suffix=ash
cluster_dir=${PWD}/test-clusters/"$(date +%Y%m%d%H%M)"-$dir_suffix
cluster_name=padillon$(date +%m%d%H%M)
pull_secret_path=/home/padillon/.docker/config.json
pull_secret=$(cat $pull_secret_path)
ssh_key=$(cat /home/padillon/.ssh/openshift-dev.pub)
credential_path=/home/padillon/work/secrets/ash-ppe-service-principal.json
release_image_override=quay.io/openshift-release-dev/ocp-release:4.10.0-fc.4-x86_64
install_script=/home/padillon/ct/install-scripts/plugins.sh

#TODO Allow release image to be set, with default
#TODO Check pull secret can pull release image
#TODO Script in container for create/destroy cluster

pushd "${installer_dir}" && ./hack/build.sh && popd

mkdir -p "${cluster_dir}"

cat >> "${cluster_dir}"/install-config.yaml << EOF
apiVersion: v1
baseDomain: installer.gcp.devcluster.openshift.com
metadata:
  name: ${cluster_name}
platform:
  plugin:
    acme:
      projectID: openshift-dev-installer
      region: us-east4
pullSecret: '$pull_secret'
sshKey: |
  $ssh_key
EOF

podman run --rm -it                                                         \
    -v "${cluster_dir}":/c/:z                                               \
    -v "${installer}":/openshift-install:z                                  \
    -v "${plugin_path}":/openshift-installer-acme-plugin.so:z               \
    -v "${credential_path}":/root/.azure/osServicePrincipal.json:z          \
    -v "${pull_secret_path}":/root/.docker/config.json:z                    \
    -v "${install_script}":/create.sh                                       \
    -e OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="${release_image_override}" \
    -e KUBECONFIG="/c/auth/kubeconfig"                                      \
    -e OPENSHIFT_INSTALL_PLUGIN_PATH="openshift-installer-acme-plugin.so"   \
    install-tools:latest /bin/bash
