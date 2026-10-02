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
3. Set `EXPECTED_AWS_ACCOUNT_ID`, `TOKEN_AUDIENCE`, `ALLOWED_REGION`, `PROVISIONING_PROFILE`, and `POLICY_VERSION` using the values shown by Intelog.
4. Run:

   ```bash
   chmod +x onboard.sh
   ./onboard.sh
   ```

5. Review the account, principal, and CloudFormation change set printed by the wrapper. The first run does **not** execute it.
6. Execute the exact change set using the command printed by the wrapper. After CloudFormation completes, run `aws cloudformation describe-stacks --stack-name intelog-cloud-runner --query 'Stacks[0].Outputs'` (add `--region` if you changed `CONTROL_REGION`).
7. Send Intelog only these outputs: `RoleArn`, `AwsAccountId`, `AllowedRegion`, `TokenAudience`, `ProvisioningProfile`, `PolicyVersion`, and `AllowedTemplates`.

## What Intelog can do

The role is restricted to the configured AWS region and the customer-selected permission profile. `VpcSmoke` permits the approved VPC smoke template. `EksPlatform` adds the regional EKS platform permissions and Intelog-scoped IAM role management required by the approved EKS template. It cannot sign in to the AWS console and has no long-lived credentials.

## Permission updates

When an approved Intelog design requires capabilities outside the current profile, Intelog supplies the new profile and policy version. Update `onboarding.env` and run `./onboard.sh` again. The wrapper creates a change set without executing it; review it, then run the printed `execute-change-set` command. This updates the existing stack and role; it does not create a second integration or change the token audience.

For first-time onboarding, Intelog may provide a prefilled AWS Quick Create link. For an existing integration, Intelog links to the CloudFormation stacks page and supplies the immutable template URL plus the expected profile/version; select the existing stack, create the change set, review it, and execute it. Do not substitute a template from an unversioned release.

Do not select a broader profile unless the corresponding architecture has been approved. Intelog will re-verify the role and enable the newly returned `AllowedTemplates` only after the stack update completes.

The trust policy verifies all of the following Google token claims:

- the dedicated Intelog runner service-account subject;
- the service account's authorized-party claim;
- the integration-specific audience supplied to you by Intelog.

## Change or remove access

To change the region, permission profile, policy version, or role parameters, update `onboarding.env` and run `./onboard.sh` again.

To revoke Intelog access, delete the `intelog-cloud-runner` CloudFormation stack. Deleting the stack removes the IAM role. Notify Intelog so the corresponding SaaS integration can also be disabled.

## Files

- `intelog-cloud-runner-role.yaml` — CloudFormation template deployed in the customer AWS account.
- `onboard.sh` — validation and deployment wrapper.
- `onboarding.env.example` — configuration template; never add credentials.
- `docs/INTERNAL_OPERATIONS.md` — Intelog team onboarding and registration procedure.

Tagged releases contain `.tar.gz` and `.zip` customer packages plus `SHA256SUMS`. Use a tagged archive or the exact versioned S3 CloudFormation URL for onboarding and upgrades; never send a moving `main`-branch template to a customer.

## Support

Contact your Intelog representative or email `arjun.kr@intelog.ai` before changing the role policy or token claims.
