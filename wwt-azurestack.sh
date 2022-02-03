#!/bin/bash

set -eux

installer_dir=/home/padillon/go/src/github.com/openshift/installer
installer=$installer_dir/bin/openshift-install
dir_suffix=wwt
cluster_dir=${PWD}/test-clusters/"$(date +%Y%m%d%H%M)"-$dir_suffix
cluster_name=padillon$(date +%m%d%H%M)
pull_secret_path=/home/padillon/.docker/config.json
pull_secret=$(cat $pull_secret_path)
ssh_key=$(cat /home/padillon/.ssh/openshift-dev.pub)
credential_path=/home/padillon/work/secrets/wwt-ash-service-principal.json
release_image_override=quay.io/openshift-release-dev/ocp-release:4.10.0-fc.4-x86_64

#TODO this is not the best way to handle this
install_script=/home/padillon/ct/install-scripts/azurestack-ipi-ca-proxy-workaround.sh

#TODO Allow release image to be set, with default
#TODO Check pull secret can pull release image
#TODO Script in container for create/destroy cluster

pushd "${installer_dir}" && ./hack/build.sh && popd

mkdir -p "${cluster_dir}"

cat >> "${cluster_dir}"/install-config.yaml << EOF
apiVersion: v1
additionalTrustBundle: |
  -----BEGIN CERTIFICATE-----
  MIIDgjCCAmqgAwIBAgIQdrn6bdq60qRPxujNuJEL0DANBgkqhkiG9w0BAQsFADBA
  MRUwEwYKCZImiZPyLGQBGRYFbG9jYWwxFjAUBgoJkiaJk/IsZAEZFgZ3d3RhdGMx
  DzANBgNVBAMTBkFUQy1DQTAeFw0xNTA5MDgxNTM2NThaFw0yNTA5MDgxNTQ2NTda
  MEAxFTATBgoJkiaJk/IsZAEZFgVsb2NhbDEWMBQGCgmSJomT8ixkARkWBnd3dGF0
  YzEPMA0GA1UEAxMGQVRDLUNBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
  AQEAxyGyv2thsIXb5sn3FucF1NnCLMSMPGCpGr8i6QOoCi1Ct22ooFpofLgf05w0
  ioeIE8oAbGVIsTd4LfBgkl/gqVpe0VDgN0m0rMQtKxuN4hZ+uxXBCX1WNMQl7Uw+
  KP0KMx8qtBGdckN7URcJYE84p9uAm6jdyfGVll401/N9qZanI6qd4N6KlS/pJ/g4
  gBY3sjS7V/ayEW3097b2/hdjk0HUqxGs0msQj5yHjRH+0sTDVJ3H9ru4nDPbK4cs
  mPQ2cS8y0xX33iC6i12LjPbWDM/zzgvLO5iqBoisliWlg7xv6JMztc4DM8NhhhNM
  rk9NqjqLgFLX7h9j9s+1R2siQQIDAQABo3gwdjALBgNVHQ8EBAMCAYYwDwYDVR0T
  AQH/BAUwAwEB/zAdBgNVHQ4EFgQUZ2zDlWjSZWQtV+E1nVWmE5GPnDwwEgYJKwYB
  BAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUSIpPV+HSrQ4UJz4rdB6bKh6e
  vgswDQYJKoZIhvcNAQELBQADggEBAJwSCHnuceCJgsW19OgkPphcVAg/OFodf3cy
  Oqq8g52Ka5n47zhSAW8HLt/7Hy/p5Ty9t5676ThaP7y2ZQEgLaAxFM5v/4Y53lkT
  IYpz2XWrN/4TZZgs5cRcFUM8HQ8N1d8O/qeSLhzz7UYgh5bnIRrGkkvuiIc34Ddo
  w4DPDP9zaYTvcQgS/3aftqb71ucLIX5nP58wG4bB8FafRxVqKkSMErroBdcF3dCF
  Mhi7D2Gd6PnOCCEaMMg7gskIqubHW5bCX9NVtcTUiRaQ2mNMx1hoyydh0YJdDTwL
  wCoBFSlJS0EMTowyoWSto1Ym1IFwCHR03MHbHUguJO3ObBAmDKI=
  -----END CERTIFICATE-----
baseDomain: installer.redhat.wwtatc.com
metadata:
  name: ${cluster_name}
platform:
  azure:
    armEndpoint: https://management.mtcazs.wwtatc.com
    baseDomainResourceGroupName: openshiftInstallerRG
    cloudName: AzureStackCloud
    region: mtcazs
    clusterOSImage: https://vhdsa.blob.mtcazs.wwtatc.com/vhd/rhcos-410.84.202112040202-0-azurestack.x86_64.vhd
pullSecret: '$pull_secret'
sshKey: |
  $ssh_key
EOF

podman run --rm -it                                              \
    -v "${cluster_dir}":/c/:z                                    \
    -v "${installer}":/openshift-install                         \
    -v "${credential_path}":/root/.azure/osServicePrincipal.json \
    -v "${pull_secret_path}":/root/.docker/config.json \
    -v "${install_script}":/install.sh \
    -e OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="${release_image_override}" \
    -e KUBECONFIG="/c/auth/kubeconfig" \
    install-tools:latest /bin/bash
