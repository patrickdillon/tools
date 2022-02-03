#!/bin/bash

set -eux

release_image=$OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE
credential_path=/root/.azure/osServicePrincipal.json
subscription_id="$(jq -r .subscriptionId $credential_path)"
aad_client_id="$(jq -r .clientId $credential_path)"
aad_client_secret="$(jq -r .clientSecret $credential_path)"
tenant_id="$(jq -r .tenantId $credential_path)"
cluster_name=$(yq e .metadata.name c/install-config.yaml)

./openshift-install create manifests --dir c --log-level debug

yq e -i 'with(.spec.trustedCA.name ; . = "user-ca-bundle" | . style="")' c/manifests/cluster-proxy-01-config.yaml

resource_group=$(yq e .status.platformStatus.azure.resourceGroupName c/manifests/cluster-infrastructure-02-config.yml)

oc adm release extract "$release_image" --credentials-requests --cloud=azure --to=credentials-request
ls credentials-request
files=$(ls credentials-request)
for f in $files
do
  secret_name=$(yq e .spec.secretRef.name "credentials-request/${f}")
  secret_namespace=$(yq e .spec.secretRef.namespace "credentials-request/${f}")
  filename=${f/request/secret}
  cat >> "c/manifests/$filename" << EOF
apiVersion: v1
kind: Secret
metadata:
    name: ${secret_name}
    namespace: ${secret_namespace}
stringData:
  azure_subscription_id: ${subscription_id}
  azure_client_id: ${aad_client_id}
  azure_client_secret: ${aad_client_secret}
  azure_tenant_id: ${tenant_id}
  azure_resource_prefix: ${cluster_name}
  azure_resourcegroup: ${resource_group}
  azure_region: mtcazs
EOF
done

# full credit to Kenny Woodson & Marco Braga for this
cat << EOF > c/openshift/99_openshift-machineconfig_00-master-etcd.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: 00-master-etcd
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      disks:
      - device: /dev/sdc
        wipe_table: true
        partitions:
        - size_mib: 0
          label: etcd
      filesystems:
        - path: /var/lib/etcd
          device: /dev/disk/by-partlabel/etcd
          format: xfs
          wipe_filesystem: true
    systemd:
      units:
        - name: var-lib-etcd.mount
          enabled: true
          contents: |
            [Unit]
            Before=local-fs.target
            [Mount]
            Where=/var/lib/etcd
            What=/dev/disk/by-partlabel/etcd
            [Install]
            WantedBy=local-fs.target
EOF

./openshift-install create cluster --dir c --log-level debug