#!/usr/bin/env bash
set -Eeuo pipefail

# Deploys the Intelog cloud-runner role into the currently authenticated AWS account.
# Requirements: AWS CLI v2 and credentials that can create CloudFormation/IAM resources.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly TEMPLATE="$SCRIPT_DIR/intelog-cloud-runner-role.yaml"
readonly CONFIG_FILE="${1:-$SCRIPT_DIR/onboarding.env}"

fail() { echo "ERROR: $*" >&2; exit 1; }
[[ -r "$TEMPLATE" ]] || fail "CloudFormation template is missing: $TEMPLATE"
[[ -r "$CONFIG_FILE" ]] || fail "Configuration file is missing: $CONFIG_FILE"
command -v aws >/dev/null || fail "AWS CLI v2 is required"

# shellcheck disable=SC1090
source "$CONFIG_FILE"
: "${STACK_NAME:=intelog-cloud-runner}"
: "${ROLE_NAME:=IntelogCloudRunner}"
: "${CONTROL_REGION:=us-east-1}"
: "${EXPECTED_AWS_ACCOUNT_ID:?Set EXPECTED_AWS_ACCOUNT_ID to the target 12-digit AWS account ID}"
: "${GOOGLE_SERVICE_ACCOUNT_SUBJECT:?Set GOOGLE_SERVICE_ACCOUNT_SUBJECT}"
: "${GOOGLE_AUTHORIZED_PARTY:?Set GOOGLE_AUTHORIZED_PARTY}"
: "${TOKEN_AUDIENCE:?Set TOKEN_AUDIENCE}"
: "${ALLOWED_REGION:?Set ALLOWED_REGION}"

[[ "$EXPECTED_AWS_ACCOUNT_ID" =~ ^[0-9]{12}$ ]] || fail "EXPECTED_AWS_ACCOUNT_ID must contain exactly 12 digits"
[[ "$ALLOWED_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]$ ]] || fail "ALLOWED_REGION is not a valid AWS region name"
[[ "$TOKEN_AUDIENCE" != "REQUEST_FROM_INTELOG" ]] || fail "Replace TOKEN_AUDIENCE with the value supplied by Intelog"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text)"
[[ "$ACCOUNT_ID" == "$EXPECTED_AWS_ACCOUNT_ID" ]] || fail "Authenticated account $ACCOUNT_ID does not match EXPECTED_AWS_ACCOUNT_ID"
echo "Deploying to AWS account: $ACCOUNT_ID"
echo "Authenticated principal: $CALLER_ARN"
echo "CloudFormation control region: $CONTROL_REGION"
echo "Allowed resource region: $ALLOWED_REGION"

aws cloudformation validate-template --region "$CONTROL_REGION" --template-body "file://$TEMPLATE" >/dev/null
aws cloudformation deploy \
  --region "$CONTROL_REGION" \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    "GoogleServiceAccountSubject=$GOOGLE_SERVICE_ACCOUNT_SUBJECT" \
    "GoogleAuthorizedParty=$GOOGLE_AUTHORIZED_PARTY" \
    "TokenAudience=$TOKEN_AUDIENCE" \
    "AllowedRegion=$ALLOWED_REGION" \
    "RoleName=$ROLE_NAME" \
  --tags Key=managed-by,Value=intelog Key=system,Value=cloud-runner

aws cloudformation describe-stacks --region "$CONTROL_REGION" --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output table

printf '\nSend Intelog the RoleArn, AwsAccountId, AllowedRegion, and TokenAudience shown above.\n'
