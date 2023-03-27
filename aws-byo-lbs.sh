#!/bin/bash

set -eux

installer_dir=/home/padillon/go/src/github.com/openshift/installer
installer=$installer_dir/bin/openshift-install
upi_templates=$installer_dir/upi/
dir_suffix=aws
cluster_dir=${PWD}/test-clusters/"$(date +%Y%m%d%H%M)"-$dir_suffix
cluster_name=padillonbyodns$(date +%m%d%H%M)
pull_secret=$(cat /home/padillon/.docker/config.json)
ssh_key=$(cat /home/padillon/.ssh/openshift-dev.pub)
credential_path=/home/padillon/work/secrets/aws-creds
release_image_override=quay.io/openshift-release-dev/ocp-release:4.13.0-ec.4-x86_64
install_script=/home/padillon/ct/install-scripts/aws-byo-lb.sh
lbs_script=/home/padillon/ct/install-scripts/aws-provision-lbs.sh

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
  aws:
    region: us-east-2
pullSecret: '$pull_secret'
sshKey: |
  $ssh_key
EOF

podman run --rm -it                                  \
    -v "${cluster_dir}":/c/:z                        \
    -v "${installer}":/openshift-install:z           \
    -v "${credential_path}":/root/.aws/credentials:z \
    -v "${install_script}":/install.sh:z             \
    -v "${lbs_script}":/lbs.sh:z                     \
    -v "${upi_templates}":/upi/:z                    \
    -e OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="${release_image_override}" \
    -e KUBECONFIG="/c/auth/kubeconfig" \
    install-tools:latest /bin/bash
