#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

export AWS_SHARED_CREDENTIALS_FILE="/root/.aws/credentials"

REGION="us-east-2"
EXPIRATION_DATE=$(date -d '4 hours' --iso=minutes --utc)
TAGS="Key=expirationDate,Value=${EXPIRATION_DATE}"
CLUSTER_NAME=$(yq e .metadata.name c/install-config.yaml)
VPC_STACK="${CLUSTER_NAME}-vpc"

rm -f params.json

cat >> params.json << EOF
[
    {
        "ParameterKey": "AvailabilityZoneCount",
        "ParameterValue": "3"
    }
]
EOF

aws --region "${REGION}" cloudformation create-stack \
  --stack-name "${VPC_STACK}" \
  --template-body "$(cat upi/aws-shared-vpc-zone.yaml)" \
  --tags "${TAGS}" \
  --parameters file://params.json &
wait "$!"

aws --region "${REGION}" cloudformation wait stack-create-complete --stack-name "${VPC_STACK}" &
wait "$!"

aws --region "${REGION}" cloudformation describe-stacks --stack-name "${VPC_STACK}" > stack_output
