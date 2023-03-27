#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

export AWS_SHARED_CREDENTIALS_FILE="/root/.aws/credentials"

REGION="us-east-2"
EXPIRATION_DATE=$(date -d '4 hours' --iso=minutes --utc)
TAGS="Key=expirationDate,Value=${EXPIRATION_DATE}"
CLUSTER_NAME=$(yq e .metadata.name c/install-config.yaml)

rm -f params.json

cat >> params.json << EOF
[
    {
        "ParameterKey": "AvailabilityZoneCount",
        "ParameterValue": "3"
    },
    {
        "ParameterKey": "ClusterName",
        "ParameterValue": "${CLUSTER_NAME}"
    },
    {
        "ParameterKey": "ClusterName",
        "ParameterValue": "${CLUSTER_NAME}"
    },
    {
        "ParameterKey": "InfrastructureName",
        "ParameterValue": "${CLUSTER_NAME}"
    }
]
EOF

aws --region "${REGION}" cloudformation create-stack \
  --stack-name "${CLUSTER_NAME}-lbs" \
  --template-body "$(cat upi/aws/cloudformation/02.99_VPC_and_LB.yaml)" \
  --tags "${TAGS}" \
  --parameters file://params.json &
wait "$!"

aws --region "${REGION}" cloudformation wait stack-create-complete --stack-name "${CLUSTER_NAME}-lbs" &
wait "$!"

aws --region "${REGION}" cloudformation describe-stacks --stack-name "${CLUSTER_NAME}-lbs" > stack_output
