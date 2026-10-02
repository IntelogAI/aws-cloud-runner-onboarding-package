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
: "${PROVISIONING_PROFILE:=VpcSmoke}"
: "${POLICY_VERSION:=2026-10-02}"
: "${EXECUTE_CHANGE_SET:=false}"

[[ "$EXPECTED_AWS_ACCOUNT_ID" =~ ^[0-9]{12}$ ]] || fail "EXPECTED_AWS_ACCOUNT_ID must contain exactly 12 digits"
[[ "$ALLOWED_REGION" != "REQUEST_FROM_INTELOG" ]] || fail "Replace ALLOWED_REGION with the region approved by Intelog"
[[ "$ALLOWED_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]$ ]] || fail "ALLOWED_REGION is not a valid AWS region name"
[[ "$TOKEN_AUDIENCE" != "REQUEST_FROM_INTELOG" ]] || fail "Replace TOKEN_AUDIENCE with the value supplied by Intelog"
[[ "$PROVISIONING_PROFILE" == "VpcSmoke" || "$PROVISIONING_PROFILE" == "EksPlatform" ]] || fail "PROVISIONING_PROFILE must be VpcSmoke or EksPlatform"
[[ "$POLICY_VERSION" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail "POLICY_VERSION must use YYYY-MM-DD"
[[ "$EXECUTE_CHANGE_SET" == "true" || "$EXECUTE_CHANGE_SET" == "false" ]] || fail "EXECUTE_CHANGE_SET must be true or false"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text)"
[[ "$ACCOUNT_ID" == "$EXPECTED_AWS_ACCOUNT_ID" ]] || fail "Authenticated account $ACCOUNT_ID does not match EXPECTED_AWS_ACCOUNT_ID"
echo "Deploying to AWS account: $ACCOUNT_ID"
echo "Authenticated principal: $CALLER_ARN"
echo "CloudFormation control region: $CONTROL_REGION"
echo "Allowed resource region: $ALLOWED_REGION"
echo "Provisioning profile: $PROVISIONING_PROFILE"
echo "Policy version: $POLICY_VERSION"

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
    "ProvisioningProfile=$PROVISIONING_PROFILE" \
    "PolicyVersion=$POLICY_VERSION" \
  --tags Key=managed-by,Value=intelog Key=system,Value=cloud-runner \
  --no-execute-changeset

CHANGE_SET_ID="$(aws cloudformation list-change-sets \
  --region "$CONTROL_REGION" \
  --stack-name "$STACK_NAME" \
  --query 'reverse(sort_by(Summaries,&CreationTime))[?Status==`CREATE_COMPLETE` && ExecutionStatus==`AVAILABLE`]|[0].ChangeSetId' \
  --output text)"
[[ -n "$CHANGE_SET_ID" && "$CHANGE_SET_ID" != "None" ]] || fail "CloudFormation did not return a reviewable change set"

echo "Reviewing change set: $CHANGE_SET_ID"
aws cloudformation describe-change-set \
  --region "$CONTROL_REGION" \
  --change-set-name "$CHANGE_SET_ID" \
  --query 'Changes[].[ResourceChange.Action,ResourceChange.LogicalResourceId,ResourceChange.ResourceType,ResourceChange.Replacement]' \
  --output table

if [[ "$EXECUTE_CHANGE_SET" == "true" ]]; then
  aws cloudformation execute-change-set --region "$CONTROL_REGION" --change-set-name "$CHANGE_SET_ID"
  aws cloudformation wait stack-create-complete --region "$CONTROL_REGION" --stack-name "$STACK_NAME" 2>/dev/null \
    || aws cloudformation wait stack-update-complete --region "$CONTROL_REGION" --stack-name "$STACK_NAME"
else
  printf '\nChange set created but not executed. Review it in AWS CloudFormation.\n'
  printf 'When approved, run:\n  aws cloudformation execute-change-set --region %q --change-set-name %q\n' "$CONTROL_REGION" "$CHANGE_SET_ID"
  exit 0
fi

aws cloudformation describe-stacks --region "$CONTROL_REGION" --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output table

printf '\nSend Intelog the RoleArn, AwsAccountId, AllowedRegion, TokenAudience, ProvisioningProfile, PolicyVersion, and AllowedTemplates shown above.\n'
