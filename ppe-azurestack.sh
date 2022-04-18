#!/bin/bash

set -eux

installer_dir=/home/padillon/go/src/github.com/openshift/installer
installer=$installer_dir/bin/openshift-install
dir_suffix=ash
cluster_dir=${PWD}/test-clusters/"$(date +%Y%m%d%H%M)"-$dir_suffix
cluster_name=padillon$(date +%m%d%H%M)
pull_secret_path=/home/padillon/.docker/config.json
pull_secret=$(cat $pull_secret_path)
ssh_key=$(cat /home/padillon/.ssh/openshift-dev.pub)
credential_path=/home/padillon/work/secrets/ash-ppe-service-principal.json
install_script=/home/padillon/ct/install-scripts/azurestack-ipi.sh
release_image_override=registry.build01.ci.openshift.org/ci-ln-6pqblrk/release:latest

#TODO Allow release image to be set, with default
#TODO Check pull secret can pull release image
#TODO Script in container for create/destroy cluster

pushd "${installer_dir}" && ./hack/build.sh && popd

mkdir -p "${cluster_dir}"

cat >> "${cluster_dir}"/install-config.yaml << EOF
apiVersion: v1
baseDomain: ppe.devcluster.openshift.com
metadata:
  name: ${cluster_name}
platform:
  azure:
    armEndpoint: https://management.ppe3.stackpoc.com
    baseDomainResourceGroupName: os4-common
    cloudName: AzureStackCloud
    region: ppe3
    ClusterOSImage: https://rhcosvhdsa.blob.ppe3.stackpoc.com/vhd/rhcos-410.84.202112040202-0-azurestack.x86_64.vhd
pullSecret: '$pull_secret'
sshKey: |
  $ssh_key
EOF

podman run --rm -it                                              \
    -v "${cluster_dir}":/c/:z                                    \
    -v "${installer}":/openshift-install:z                         \
    -v "${credential_path}":/root/.azure/osServicePrincipal.json:z \
    -v "${pull_secret_path}":/root/.docker/config.json:z \
    -v "${install_script}":/install.sh:z \
    -e OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="${release_image_override}" \
    -e KUBECONFIG="/c/auth/kubeconfig" \
    install-tools:latest /bin/bash
