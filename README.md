# Connect an AWS account to Intelog

This repository contains the customer-run onboarding package for Intelog's AWS cloud runner. It creates an IAM role in **your AWS account** that Intelog can assume using short-lived Google OIDC tokens.

Intelog does not ask for AWS access keys, IAM-user credentials, or console access.

## Before you begin

- Obtain these values from Intelog: the unique `TOKEN_AUDIENCE` for this integration and the approved AWS region.
- Use an AWS administrator or a role permitted to create CloudFormation stacks and named IAM roles.
- Install AWS CLI v2 and authenticate to the AWS account that you intend to connect.
- Know the 12-digit AWS account ID you intend to connect. The wrapper refuses to deploy to a different account.

## Deploy

1. Download or clone this repository.
2. Copy `onboarding.env.example` to `onboarding.env`.
3. Set `EXPECTED_AWS_ACCOUNT_ID`, `TOKEN_AUDIENCE`, and `ALLOWED_REGION` using the values agreed with Intelog.
4. Run:

   ```bash
   chmod +x onboard.sh
   ./onboard.sh
   ```

5. Review the account and principal printed by the wrapper. The stack creates `IntelogCloudRunner` and prints its outputs.
6. Send Intelog only these outputs: `RoleArn`, `AwsAccountId`, `AllowedRegion`, and `TokenAudience`.

## What Intelog can do

The role is restricted to the configured AWS region and permits lifecycle actions for the approved VPC template. It cannot sign in to the AWS console and has no long-lived credentials.

The trust policy verifies all of the following Google token claims:

- the dedicated Intelog runner service-account subject;
- the service account's authorized-party claim;
- the integration-specific audience supplied to you by Intelog.

## Change or remove access

To change the region or role parameters, update `onboarding.env` and run `./onboard.sh` again.

To revoke Intelog access, delete the `intelog-cloud-runner` CloudFormation stack. Deleting the stack removes the IAM role. Notify Intelog so the corresponding SaaS integration can also be disabled.

## Files

- `intelog-cloud-runner-role.yaml` — CloudFormation template deployed in the customer AWS account.
- `onboard.sh` — validation and deployment wrapper.
- `onboarding.env.example` — configuration template; never add credentials.
- `docs/INTERNAL_OPERATIONS.md` — Intelog team onboarding and registration procedure.

## Support

Contact your Intelog representative or email `arjun.kr@intelog.ai` before changing the role policy or token claims.
