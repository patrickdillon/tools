#!/bin/bash

set -eux

release_image=$OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE
credential_path=/root/.azure/osServicePrincipal.json
subscription_id="$(jq -r .subscriptionId $credential_path)"
aad_client_id="$(jq -r .clientId $credential_path)"
aad_client_secret="$(jq -r .clientSecret $credential_path)"
tenant_id="$(jq -r .tenantId $credential_path)"
cluster_name=$(yq e .metadata.name c/install-config.yaml)
region=$(yq e .platform.azure.region c/install-config.yaml)

./openshift-install create manifests --dir c --log-level debug

resource_group=$(yq e .status.platformStatus.azure.resourceGroupName c/manifests/cluster-infrastructure-02-config.yml)

oc adm release extract "$release_image" --credentials-requests --cloud=azure --to=credentials-request
exit
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
  azure_region: ${region}
EOF
done

rm credentials-request/0000_30_capi-operator_00_credentials-request.yaml
rm c/manifests/0000_30_capi-operator_00_credentials-secret.yaml

./openshift-install create cluster --dir c --log-level debug