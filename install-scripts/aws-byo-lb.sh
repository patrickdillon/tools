#!/bin/bash

./lbs.sh

INT_LB_NAME="$(jq -r '.Stacks[].Outputs[] | select(.OutputKey=="InternalApiLoadBalancerName") | .OutputValue' stack_output)"
EXT_LB_NAME="$(jq -r '.Stacks[].Outputs[] | select(.OutputKey=="ExternalApiLoadBalancerName") | .OutputValue' stack_output)"
PRIV_SUBNETS="$(jq -r '.Stacks[].Outputs[] | select(.OutputKey == "PrivateSubnetIds").OutputValue' stack_output)"
PUB_SUBNETS="$(jq -r '.Stacks[].Outputs[] | select(.OutputKey == "PublicSubnetIds").OutputValue' stack_output)"

yq -i ".platform.aws.intLBName = \"$INT_LB_NAME\"" c/install-config.yaml
yq -i ".platform.aws.extLBName = \"$EXT_LB_NAME\"" c/install-config.yaml
yq -i '.platform.aws.loadBalancer = "UserManaged"' c/install-config.yaml

yq -i ".platform.aws.subnets +=  []" c/install-config.yaml
export IFS=","
for SUBNET in $PRIV_SUBNETS $PUB_SUBNETS; do
  yq -i ".platform.aws.subnets +=  \"$SUBNET\"" c/install-config.yaml
done

# TODO: add LB DNS name to outputs (in aws-provision-lbs.sh) and echo output here (or, automate if that is worth the trouble!)
# At this point, create DNS records in some other DNS registrar, like GCP. This could be automated. 

#./openshift-install create cluster --dir c --log-level debug