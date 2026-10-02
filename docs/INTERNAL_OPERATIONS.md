# Internal AWS customer onboarding procedure

This document is for Intelog operations and customer-success users. It contains no customer credentials and is safe to keep with the shareable onboarding package.

## One integration per boundary

Create a separate integration for each combination of:

- Intelog tenant;
- AWS account;
- environment (`development`, `staging`, or `production`);
- allowed AWS region.

Never reuse a token audience between customer AWS accounts. A suggested format is:

```text
intelog-aws:<tenant-slug>:<aws-account-id>:<random-integration-id>
```

Keep the audience under 255 characters and treat it as an identifier, not a secret.

## Information to send the customer

Provide the repository or release archive and confirm:

- expected 12-digit AWS account ID;
- unique token audience;
- approved resource region;
- expected role name, normally `IntelogCloudRunner`.
- required provisioning profile and policy version.

The Google service-account subject and authorized-party values are maintained in `onboarding.env.example`. They identify the Intelog runner; they are not AWS credentials.

## Information returned by the customer

Ask the customer to return only the wrapper outputs:

- `RoleArn`;
- `AwsAccountId`;
- `AllowedRegion`;
- `TokenAudience`.
- `ProvisioningProfile`;
- `PolicyVersion`;
- `AllowedTemplates`.

Reject the response if the account ID, audience, region, or role name differs from the values issued for the integration.

## Backend registration

Create an `external_cloud_accounts` record scoped to the correct tenant and environment:

```json
{
  "tenantId": "<tenant ObjectId>",
  "awsAccountId": "<12-digit account ID>",
  "environment": "staging",
  "roleArn": "arn:aws:iam::<account-id>:role/IntelogCloudRunner",
  "webIdentityAudience": "<unique audience>",
  "allowedRegions": ["<approved region>"],
  "provisioningProfile": "VpcSmoke",
  "policyVersion": "2026-10-02",
  "allowedTemplates": ["aws-vpc"],
  "enabled": false
}
```

Keep the record disabled until an Intelog runner validation job successfully calls `sts:GetCallerIdentity` using the returned role. Enable the record only after the returned account and role match the registration request.

If a design requires a template outside `allowedTemplates`, mark the integration as requiring a permission update. Provide the customer with the immutable onboarding release, expected profile, policy version, and a CloudFormation change-set link. Enable the new templates only after the customer returns matching stack outputs and verification succeeds.

Each production onboarding version is an immutable Git tag in the repository. Pushing a `v*` tag publishes both customer archive formats and checksums. Run the **Promote CloudFormation template** workflow for that tag to copy the validated template to Intelog's public onboarding S3 bucket under the same immutable version. The repository must have `ONBOARDING_PUBLISH_ROLE_ARN` configured as an Actions variable, and that AWS role should only be able to write under the onboarding artifact prefix. Configure the SaaS backend with the exact object URL, for example:

```text
https://intelog-public-artifacts.s3.us-east-1.amazonaws.com/aws-onboarding/v1.1.0/intelog-cloud-runner-role.yaml
```

CloudFormation quick-create accepts an S3-hosted template URL. For first-time onboarding, the backend combines that URL with the tenant integration's audience, region, and required profile to produce a prefilled Quick Create link. For upgrades, it links the customer to the existing stack and supplies the immutable template URL and expected parameters. The customer remains the actor that reviews and executes the change set in its AWS account.

## Runtime behavior

After onboarding, the customer does not run this package for each deployment. The Intelog backend selects the tenant-scoped account record, creates a short-lived Kubernetes runner Job, and requests a Google identity token with that integration's audience. AWS STS exchanges the token for a temporary role session.

## Revocation

If either party requests revocation:

1. Disable the `external_cloud_accounts` record immediately.
2. Ask the customer to delete the CloudFormation stack.
3. Confirm the IAM role no longer exists.
4. Retain the audit event without retaining identity tokens or credentials.
