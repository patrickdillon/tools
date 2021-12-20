#!/bin/bash

set -eux

installer_dir=/home/padillon/go/src/github.com/openshift/installer
installer=$installer_dir/bin/openshift-install
dir_suffix=azpub
cluster_dir=${PWD}/test-clusters/"$(date +%Y%m%d%H%M)"-$dir_suffix
cluster_name=padillon$(date +%m%d%H%M)
pull_secret=$(cat /home/padillon/.docker/config.json)
ssh_key=$(cat /home/padillon/.ssh/openshift-dev.pub)
credential_path=/home/padillon/work/backup/public-azure.service-principal.json
release_image_override=quay.io/openshift-release-dev/ocp-release:4.9.11-x86_64
install_script=/home/padillon/ct/install-scripts/azure-mkt.sh

#TODO Allow release image to be set, with default
#TODO Check pull secret can pull release image
#TODO Script in container for create/destroy cluster

pushd "${installer_dir}" && ./hack/build.sh && popd

mkdir -p "${cluster_dir}"

cat >> "${cluster_dir}"/install-config.yaml << EOF
apiVersion: v1
baseDomain: installer.azure.devcluster.openshift.com
metadata:
  name: ${cluster_name}
platform:
  azure:
    baseDomainResourceGroupName: os4-common
    cloudName: AzurePublicCloud
    region: centralus
pullSecret: '$pull_secret'
sshKey: |
  $ssh_key
EOF

podman run --rm -it                                              \
    -v "${cluster_dir}":/c/:z                                    \
    -v "${installer}":/openshift-install                         \
    -v "${credential_path}":/root/.azure/osServicePrincipal.json \
    -v "${install_script}":/install.sh \
    -e OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="${release_image_override}" \
    -e KUBECONFIG="/c/auth/kubeconfig" \
    installer-wwt:latest /bin/bash
